import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

PI = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PI))
import auto_reconnect
import prepare_autoflash
import refresh_tuya


def credentials():
    values = {}
    for role in ('FAN', 'LED'):
        prefix = 'TUYA_' + role + '_'
        values.update({prefix + 'DEVICE_ID': role.lower() + '-id',
                       prefix + 'LOCAL_KEY': '0123456789abcdef',
                       prefix + 'VERSION': '3.4', prefix + 'SWITCH_DP': '1',
                       prefix + 'IP': '192.168.0.10'})
    return values


class SeedTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'pi').mkdir()
        for name in ('user-data', 'bootstrap_first_boot.sh', 'refresh_tuya.py',
                     'fnb48p_power_api.py', 'kcd-bootstrap.service', 'kcd-tuya.service'):
            shutil.copyfile(PI / name, self.root / 'pi' / name)
        (self.root / 'pi' / 'network-config').write_text(yaml.safe_dump({
            'version': 2, 'wifis': {'wlan0': {'dhcp4': True, 'access-points': {
                'test-network': {'password': 'test-password'}}}}}))
        (self.root / '.local' / 'tuya').mkdir(parents=True)
        self.config = self.root / '.local' / 'tuya' / 'devices.env'
        self.config.write_text('\n'.join(k + '=' + json.dumps(v)
                                       for k, v in credentials().items()) + '\n')

    def test_seed_restores_local_keys_without_cloud_credentials(self):
        original = self.config.read_bytes()
        seed, manifest = prepare_autoflash.build(self.root)
        cloud = yaml.safe_load((seed / 'user-data').read_text())
        files = {item['path']: item for item in cloud['write_files']}
        self.assertEqual(files['/opt/kcd-tuya/devices.env']['content'].encode(), original)
        self.assertEqual(files['/opt/kcd-tuya/devices.env']['permissions'], '0600')
        self.assertNotIn('/opt/kcd-tuya/tinytuya.json', files)
        self.assertNotIn('/var/lib/kcd-demo/ready', files)
        self.assertFalse(cloud['package_update'])
        self.assertNotIn('packages', cloud)
        self.assertIn('--no-block', cloud['runcmd'][-1])
        self.assertIn('/usr/local/sbin/kcd-bootstrap', files)
        self.assertEqual(yaml.safe_load((seed / 'meta-data').read_text())['instance-id'],
                         manifest['instance_id'])
        self.assertEqual(self.config.read_bytes(), original)
        self.assertFalse((self.root / '.local/pi/pending.json').exists())
        self.assertEqual((seed / 'user-data').stat().st_mode & 0o777, 0o600)

    def test_repeated_flash_keeps_ssh_identity_but_changes_instance(self):
        seed, first = prepare_autoflash.build(self.root)
        key = (self.root / '.local/pi/ssh_host_ed25519_key').read_bytes()
        client = (self.root / '.local/pi/id_ed25519').read_bytes()
        _, second = prepare_autoflash.build(self.root)
        self.assertEqual(first['host_public_key'], second['host_public_key'])
        self.assertNotEqual(first['instance_id'], second['instance_id'])
        self.assertEqual(key, (self.root / '.local/pi/ssh_host_ed25519_key').read_bytes())
        self.assertEqual(client, (self.root / '.local/pi/id_ed25519').read_bytes())
        prepare_autoflash.arm(seed / 'manifest.json', self.root)
        pending = json.loads((self.root / '.local/pi/pending.json').read_text())
        self.assertEqual(pending['instance_id'], second['instance_id'])

    def test_modified_seed_cannot_arm_automation(self):
        seed, _ = prepare_autoflash.build(self.root)
        with (seed / 'user-data').open('a') as stream:
            stream.write('\n# changed\n')
        with self.assertRaises(ValueError):
            prepare_autoflash.arm(seed / 'manifest.json', self.root)
        self.assertFalse((self.root / '.local/pi/pending.json').exists())

    def test_missing_backup_is_rejected(self):
        self.config.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing private backup'):
            prepare_autoflash.build(self.root)


class FakeDevice:
    def __init__(self, device_id, ip, key, version):
        self.device_id = device_id
    def set_socketTimeout(self, timeout):
        pass
    def set_socketRetryLimit(self, count):
        pass
    def status(self):
        return {'dps': {'1': False}}
    def close(self):
        pass


class TuyaRefreshTests(unittest.TestCase):
    def test_new_lan_addresses_keep_keys_and_dp(self):
        before = credentials()
        devices = {'10.42.0.19': {'gwId': 'fan-id', 'version': '3.4'},
                   '10.42.0.20': {'gwId': 'led-id', 'version': '3.5'}}
        result = refresh_tuya.refresh(before, devices, FakeDevice)
        self.assertEqual(result['TUYA_FAN_IP'], '10.42.0.19')
        self.assertEqual(result['TUYA_LED_VERSION'], '3.5')
        self.assertEqual(result['TUYA_LED_LOCAL_KEY'], before['TUYA_LED_LOCAL_KEY'])
        self.assertEqual(before['TUYA_LED_IP'], '192.168.0.10')

    def test_missing_device_does_not_change_configuration(self):
        before = credentials()
        with self.assertRaisesRegex(ValueError, 'device not found'):
            refresh_tuya.refresh(before, {}, FakeDevice)
        self.assertEqual(before, credentials())

    def test_invalid_local_key_or_dp_is_rejected(self):
        values = credentials()
        values['TUYA_LED_LOCAL_KEY'] = 'short'
        with self.assertRaises(ValueError):
            refresh_tuya.validate(values)
        values = credentials()
        values['TUYA_FAN_SWITCH_DP'] = '0'
        with self.assertRaises(ValueError):
            refresh_tuya.validate(values)

    def test_quoted_punctuation_survives_environment_roundtrip(self):
        value = 'a"b\\c$d\'e!f#ghi?'
        parsed = refresh_tuya.read_env('TEST=' + json.dumps(value))
        self.assertEqual(parsed['TEST'], value)


class ReconnectTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.local = self.root / '.local/pi'
        self.local.mkdir(parents=True)
        self.manifest = {'instance_id': 'new-instance', 'host_public_key': 'ssh-ed25519 TEST'}

    def arm(self):
        (self.local / 'pending.json').write_text(json.dumps(self.manifest))
        (self.local / 'known_hosts').write_text('factory-pi.local ssh-ed25519 TEST\n')

    @patch('auto_reconnect.resolve_ip')
    @patch('auto_reconnect.command')
    def test_unarmed_watch_does_not_contact_anything(self, command, resolve):
        self.assertFalse(auto_reconnect.reconnect(self.root))
        command.assert_not_called()
        resolve.assert_not_called()

    def test_old_instance_or_stale_boot_is_not_accepted(self):
        for data in ({'instance_id': 'old-instance', 'boot_id': 'new-boot'},
                     {'instance_id': 'new-instance', 'boot_id': 'old-boot'}):
            with self.assertRaises(auto_reconnect.Retry):
                auto_reconnect.validate_ready(json.dumps(data) + '\nnew-boot', 'new-instance')

    @patch('auto_reconnect.resolve_ip', return_value='192.0.2.18')
    @patch('auto_reconnect.ensure_ui_services')
    @patch('auto_reconnect.update_interactive_known_hosts')
    @patch('auto_reconnect.http_json')
    @patch('auto_reconnect.command')
    def test_registration_is_pinned_and_idempotent(self, command, http, known, ui, resolve):
        self.arm()
        registered = ['']
        def run(args, **kwargs):
            if args[0] == 'ssh':
                self.assertIn('StrictHostKeyChecking=yes', args)
                self.assertIn('IdentitiesOnly=yes', args)
                return json.dumps({'instance_id': 'new-instance', 'boot_id': 'boot'}) + '\nboot'
            if args[0] == 'kubectl':
                if 'namespace' in args:
                    return 'hq-uid'
                if 'get' in args and 'secret' in args:
                    return registered[0]
                if 'annotate' in args:
                    registered[0] = 'new-instance'
                return 'ok'
            self.assertEqual(args[0], str(self.root / 'pi/up_linux.sh'))
            self.assertEqual(kwargs['env']['PI_SSH_HOST_KEY_ALIAS'], 'factory-pi.local')
            return 'configured'
        command.side_effect = run
        def response(ip, route):
            if route == '/healthz':
                return {'status': 'ok'}
            if route == '/state':
                return {'fan_controller_enabled': True, 'solar_generation_watts': 0,
                        'sun_threshold_w': 0.2}
            return {'ok': True}
        http.side_effect = response
        self.assertTrue(auto_reconnect.reconnect(self.root))
        count = command.call_count
        self.assertFalse(auto_reconnect.reconnect(self.root))
        self.assertFalse(any(call.args[0][0].endswith('up_linux.sh')
                             for call in command.call_args_list[count:]))
        known.assert_called_once_with('192.0.2.18', 'ssh-ed25519 TEST')
        self.assertEqual((self.local / 'connected.json').stat().st_mode & 0o777, 0o600)

    @patch('auto_reconnect.resolve_ip', return_value='192.0.2.18')
    @patch('auto_reconnect.ensure_ui_services')
    @patch('auto_reconnect.http_json', return_value={'status': 'ok'})
    @patch('auto_reconnect.command')
    def test_unavailable_hq_cannot_complete_registration(self, command, http, ui, resolve):
        self.arm()
        for unavailable, after_refresh in (
            ('nodes', False), ('statefulset/argocd-application-controller', False),
            ('statefulset/prometheus-kube-prometheus-stack-prometheus', False),
            ('statefulset/prometheus-kube-prometheus-stack-prometheus', True),
            ('scaledobject/led-autoscaler', True),
        ):
            with self.subTest(unavailable=unavailable, after_refresh=after_refresh):
                command.reset_mock()
                ui.reset_mock()
                refreshed = []
                def run(args, **kwargs):
                    if args[0] == 'ssh':
                        return json.dumps({'instance_id': 'new-instance', 'boot_id': 'boot'}) + '\nboot'
                    if args[0] == str(self.root / 'pi/up_linux.sh'):
                        refreshed.append(True)
                    if (unavailable in args and ('wait' in args or 'rollout' in args)
                            and (not after_refresh or refreshed)):
                        raise auto_reconnect.Retry('HQ workload unavailable')
                    return 'hq-uid'
                command.side_effect = run
                with self.assertRaises(auto_reconnect.Retry):
                    auto_reconnect.reconnect(self.root)
                self.assertFalse((self.local / 'connected.json').exists())
                self.assertEqual(bool(refreshed), after_refresh)
                self.assertFalse(any('annotate' in call.args[0]
                                     for call in command.call_args_list))
                if not after_refresh:
                    ui.assert_not_called()


if __name__ == '__main__':
    unittest.main()
