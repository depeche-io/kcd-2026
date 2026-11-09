"""Safety ordering for the operator's real start/stop workflow."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('demo_linux', Path(__file__).resolve().parents[2] / 'demo_linux.py')
demo_linux = importlib.util.module_from_spec(spec)
spec.loader.exec_module(demo_linux)


class StopTests(unittest.TestCase):
    def demo(self):
        demo = demo_linux.Demo.__new__(demo_linux.Demo)
        demo.ssh = ['ssh', 'ubuntu@192.0.2.18']
        events = []
        for name in ('connect', 'suspend_services', 'pause_controllers',
                     'wait_controllers_stopped', 'runtime', 'run', 'wait_poweroff', 'record'):
            setattr(demo, name, Mock(side_effect=lambda *a, _name=name, **kw: events.append((_name, a, kw))))
        def blackout(route):
            events.append(('api', (route,), {}))
            return {'fan': {'ok': True}, 'led': {'ok': True}}
        demo.api = Mock(side_effect=blackout)
        return demo, events

    def test_poweroff_requires_devices_and_controllers_then_hq_stopped(self):
        demo, events = self.demo()
        demo.stop()
        order = [name for name, _, _ in events]
        self.assertLess(order.index('suspend_services'), order.index('api'))
        self.assertLess(order.index('api'), order.index('wait_controllers_stopped'))
        self.assertLess(order.index('wait_controllers_stopped'), order.index('runtime'))
        self.assertLess(order.index('runtime'), order.index('run'))
        self.assertLess(order.index('wait_poweroff'), order.index('record'))
        self.assertIn('poweroff --no-block', demo.run.call_args.args[0][-1])
        demo.runtime.assert_called_once_with('stop')
        demo.record.assert_called_once_with('stopped')

    def test_device_refusal_keeps_pi_and_hq_powered(self):
        demo, _ = self.demo()
        demo.api.side_effect = None
        demo.api.return_value = {'fan': {'ok': True}, 'led': {'ok': False}}
        with self.assertRaises(RuntimeError):
            demo.stop()
        demo.runtime.assert_not_called()
        demo.run.assert_not_called()
        demo.record.assert_not_called()

    def test_hq_failure_keeps_pi_available_for_repair(self):
        demo, _ = self.demo()
        demo.runtime.side_effect = RuntimeError('Docker authentication failed')
        with self.assertRaises(RuntimeError):
            demo.stop()
        demo.run.assert_not_called()
        demo.record.assert_not_called()

    def test_lingering_controller_prevents_hq_stop_and_pi_poweroff(self):
        demo, _ = self.demo()
        demo.wait_controllers_stopped.side_effect = RuntimeError('old lifecycle hook still running')
        with self.assertRaises(RuntimeError):
            demo.stop()
        demo.runtime.assert_not_called()
        demo.run.assert_not_called()


class StartTests(unittest.TestCase):
    def test_manual_start_records_verified_flash_before_timer_is_enabled(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            local = root / '.local/pi'
            local.mkdir(parents=True)
            (local / 'pending.json').write_text(json.dumps({
                'instance_id': 'new-instance', 'host_public_key': 'ssh-ed25519 TEST'}))
            (local / 'known_hosts').write_text('factory-pi.local ssh-ed25519 TEST\n')
            demo = demo_linux.Demo.__new__(demo_linux.Demo)
            demo.owner = (root.stat().st_uid, root.stat().st_gid)
            demo.ip = '192.0.2.18'
            demo.ssh = ['ssh', 'ubuntu@192.0.2.18']
            demo.run = Mock(return_value=json.dumps({'instance_id': 'new-instance', 'boot_id': 'boot'}) + '\nboot')
            demo.kube = Mock(return_value='hq-uid')
            with patch.object(demo_linux, 'ROOT', root), patch.object(demo_linux, 'update_interactive_known_hosts') as trust:
                demo.adopt_autoflash()
                trust.assert_called_once_with('192.0.2.18', 'ssh-ed25519 TEST')
            saved = json.loads((local / 'connected.json').read_text())
            self.assertEqual(saved, dict(instance_id='new-instance', ip='192.0.2.18', boot_id='boot', hq_id='hq-uid'))
            self.assertEqual((local / 'connected.json').stat().st_mode & 0o777, 0o600)

    def test_missing_context_never_starts_or_creates_cluster(self):
        demo = demo_linux.Demo.__new__(demo_linux.Demo)
        demo.suspend_services = Mock()
        demo.run = Mock(return_value='')
        demo.runtime = Mock()
        with self.assertRaises(RuntimeError):
            demo.start()
        demo.runtime.assert_not_called()

    def test_new_network_discovery_sends_only_public_code(self):
        demo = demo_linux.Demo.__new__(demo_linux.Demo)
        demo.ssh = ['ssh', 'ubuntu@192.0.2.18']
        demo.run = Mock()
        demo.api = Mock(return_value={'status': 'ok'})
        demo.refresh_devices()
        payload = demo.run.call_args_list[0].kwargs['input']
        self.assertIn('/opt/kcd-tuya/devices.env', payload)
        self.assertIn('deviceScan', payload)
        self.assertNotIn('.local/tuya', payload)
        # The exact public source is the payload; no local credential file is read.
        self.assertTrue(payload.endswith((demo_linux.ROOT / 'pi/refresh_tuya.py').read_text()))


if __name__ == '__main__':
    unittest.main()
