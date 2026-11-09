#!/usr/bin/env python3
"""Build a private cloud-init seed; never print its credential contents."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

import yaml

from refresh_tuya import read_env, validate

ROOT = Path(__file__).resolve().parent.parent


def private_dir(path, owner):
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)
    if os.geteuid() == 0:
        os.chown(path, *owner)


def private_write(path, contents, owner):
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        if os.geteuid() == 0:
            os.chown(temporary, *owner)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def identity(path, comment, owner):
    if not path.exists():
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '',
                        '-C', comment, '-f', str(path)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    derived = subprocess.check_output(['ssh-keygen', '-y', '-f', str(path)], text=True)
    public = ' '.join(derived.split()[:2])
    if path.with_suffix('.pub').exists():
        existing = ' '.join(path.with_suffix('.pub').read_text().split()[:2])
        if existing != public:
            raise ValueError('Public/private identity mismatch: ' + path.name)
    path.chmod(0o600)
    if os.geteuid() == 0:
        os.chown(path, *owner)
    private_write(path.with_suffix('.pub'), public + ' ' + comment + '\n', owner)
    return public


def build(root=ROOT, output=None):
    owner = (root.stat().st_uid, root.stat().st_gid)
    local = root / '.local' / 'pi'
    private_dir(root / '.local', owner)
    private_dir(local, owner)
    seed = output or local / 'seed'
    private_dir(seed, owner)
    config_path = root / '.local' / 'tuya' / 'devices.env'
    if not config_path.is_file():
        raise ValueError('Missing private backup: .local/tuya/devices.env')
    device_config = config_path.read_text()
    validate(read_env(device_config))
    network = yaml.safe_load((root / 'pi' / 'network-config').read_text())
    if not isinstance(network, dict) or network.get('version') != 2:
        raise ValueError('Invalid network-config')
    for interface in network.get('wifis', {}).values():
        for ssid, access in interface.get('access-points', {}).items():
            password = access.get('password')
            if not isinstance(ssid, str) or not 1 <= len(ssid.encode()) <= 32:
                raise ValueError('Invalid Wi-Fi SSID')
            if not isinstance(password, str) or not (8 <= len(password) <= 63 or
                    len(password) == 64 and all(c in '0123456789abcdefABCDEF' for c in password)):
                raise ValueError('Invalid Wi-Fi password format')
    host_key = local / 'ssh_host_ed25519_key'
    host_public = identity(host_key, 'factory-pi-host', owner)
    client_public = identity(local / 'id_ed25519', 'factory-pi-automation', owner)
    private_write(local / 'known_hosts', 'factory-pi.local ' + host_public + '\n', owner)

    instance_id = 'kcd-' + str(uuid.uuid4())
    config = yaml.safe_load((root / 'pi' / 'user-data').read_text())
    config['package_update'] = False
    config['package_upgrade'] = False
    config.pop('packages', None)
    config['runcmd'] = [
        ['systemctl', 'daemon-reload'],
        ['systemctl', 'enable', '--now', '--no-block', 'kcd-bootstrap.service'],
    ]
    ubuntu = next(user for user in config['users']
                  if isinstance(user, dict) and user.get('name') == 'ubuntu')
    keys = ubuntu.setdefault('ssh_authorized_keys', [])
    if client_public not in keys:
        keys.append(client_public)
    config['ssh_deletekeys'] = True
    config['ssh_genkeytypes'] = ['ed25519']
    config['ssh_keys'] = {'ed25519_private': host_key.read_text(),
                          'ed25519_public': host_public}
    files = config.setdefault('write_files', [])
    for source, destination, permissions in (
        ('bootstrap_first_boot.sh', '/usr/local/sbin/kcd-bootstrap', '0755'),
        ('refresh_tuya.py', '/opt/kcd-tuya/refresh_tuya.py', '0755'),
        ('fnb48p_power_api.py', '/opt/kcd-tuya/simulation.py', '0644'),
        ('kcd-bootstrap.service', '/etc/systemd/system/kcd-bootstrap.service', '0644'),
        ('kcd-tuya.service', '/etc/systemd/system/kcd-tuya.service', '0644'),
    ):
        files.append({'path': destination, 'owner': 'root:root', 'permissions': permissions,
                      'content': (root / 'pi' / source).read_text()})
    files.extend([
        {'path': '/opt/kcd-tuya/devices.env', 'owner': 'root:root',
         'permissions': '0600', 'content': device_config},
        {'path': '/etc/kcd-demo/instance-id', 'owner': 'root:root',
         'permissions': '0644', 'content': instance_id + '\n'},
    ])
    rendered = '#cloud-config\n' + yaml.safe_dump(config, sort_keys=False)
    private_write(seed / 'user-data', rendered, owner)
    private_write(seed / 'network-config', (root / 'pi' / 'network-config').read_text(), owner)
    private_write(seed / 'meta-data', yaml.safe_dump({'instance-id': instance_id,
                  'local-hostname': 'factory-pi'}, sort_keys=False), owner)
    manifest = {'instance_id': instance_id,
                'seed_sha256': hashlib.sha256(rendered.encode()).hexdigest(),
                'host_public_key': host_public}
    private_write(seed / 'manifest.json', json.dumps(manifest) + '\n', owner)
    return seed, manifest


def arm(manifest_path, root=ROOT):
    manifest = json.loads(manifest_path.read_text())
    digest = hashlib.sha256((manifest_path.parent / 'user-data').read_bytes()).hexdigest()
    if digest != manifest['seed_sha256']:
        raise ValueError('Seed changed after preparation; refusing to arm automation')
    pinned = (root / '.local' / 'pi' / 'known_hosts').read_text().split(' ', 1)[1].strip()
    if pinned != manifest['host_public_key']:
        raise ValueError('SSH identity changed after preparation')
    owner = (root.stat().st_uid, root.stat().st_gid)
    private_write(root / '.local' / 'pi' / 'pending.json', json.dumps(manifest) + '\n', owner)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='Private seed directory')
    parser.add_argument('--arm', type=Path, help='Arm laptop registration after a successful flash')
    args = parser.parse_args()
    if args.arm:
        arm(args.arm)
        print('Automatic HQ registration armed for the newly flashed Pi.')
    else:
        seed, manifest = build(output=args.output)
        print('Private seed prepared:', seed)
        print('Instance:', manifest['instance_id'])
        print('No disk written; credential contents are not displayed.')


if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except (ValueError, OSError, StopIteration, KeyError) as error:
        raise SystemExit('Preparation failed: ' + str(error))
