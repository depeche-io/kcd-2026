#!/usr/bin/env python3
"""Install the laptop's user timer; an unarmed timer does no network work."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys

from prepare_autoflash import ROOT, private_dir, private_write


def unit_quote(value):
    return '"' + str(value).replace('%', '%%').replace('\\', '\\\\').replace('"', '\\"') + '"'


def render_units(root, python):
    units = {
        'kcd-pi-reconnect.service': f'''[Unit]
Description=Reconnect the flashed KCD Pi to HQ

[Service]
Type=oneshot
WorkingDirectory={str(root).replace('%', '%%')}
Environment="PATH=/usr/local/bin:/usr/bin:/bin:/snap/bin"
ExecStart={unit_quote(python)} {unit_quote(root / 'pi' / 'auto_reconnect.py')}
TimeoutStartSec=30min
UMask=0077
''',
        'kcd-pi-reconnect.timer': '''[Unit]
Description=Watch for the restored KCD Pi

[Timer]
OnActiveSec=15s
OnUnitInactiveSec=30s
AccuracySec=5s

[Install]
WantedBy=timers.target
''',
    }
    context = 'k3d-' + os.environ.get('K3D_CLUSTER', 'hq')
    kubectl = shutil.which('kubectl') or '/snap/bin/kubectl'
    for name, namespace, service, port in (
        ('grafana', 'monitoring', 'kube-prometheus-stack-grafana', 3000),
        ('argocd', 'argocd', 'argocd-server', 8080),
    ):
        units['kcd-' + name + '.service'] = f'''[Unit]
Description=KCD local {name} access
StartLimitIntervalSec=0

[Service]
ExecStart={unit_quote(kubectl)} --context={context} -n {namespace} port-forward svc/{service} {port}:80 --address 127.0.0.1
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
'''
    return units


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--render-only', action='store_true')
    args = parser.parse_args()
    owner = (ROOT.stat().st_uid, ROOT.stat().st_gid)
    local = ROOT / '.local' / 'pi'
    private_dir(local, owner)
    directory = (local / 'units' if args.render_only else
                 Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'systemd' / 'user')
    directory.mkdir(parents=True, exist_ok=True)
    units = render_units(ROOT, Path(sys.executable).resolve())
    for name, content in units.items():
        existing = directory / name
        if existing.exists() and existing.read_text() != content:
            old = existing.read_text()
            managed = (str(ROOT / 'pi' / 'auto_reconnect.py') in old or
                       'Description=KCD local ' in old or
                       name.endswith('.timer') and 'Description=Watch for the restored KCD Pi' in old)
            if not managed:
                raise SystemExit('Refusing to replace an unrelated existing unit: ' + str(existing))
        private_write(directory / name, content, owner)
    subprocess.run(['systemd-analyze', '--user', 'verify',
                    *[str(directory / name) for name in units]], check=True)
    if args.render_only:
        print('User units prepared and validated:', directory)
        return
    subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
    subprocess.run(['systemctl', '--user', 'enable', 'kcd-grafana.service', 'kcd-argocd.service'], check=True)
    subprocess.run(['systemctl', '--user', 'enable', '--now', 'kcd-pi-reconnect.timer'], check=True)
    private_write(local / 'automation-installed.json', json.dumps({
        'unit_dir': str(directory), 'root': str(ROOT),
    }) + '\n', owner)
    print('Automatic reconnect enabled; it will wait for a successful flash to arm it.')


if __name__ == '__main__':
    os.umask(0o077)
    main()
