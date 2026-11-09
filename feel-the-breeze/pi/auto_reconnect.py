#!/usr/bin/env python3
"""Reconnect a specifically armed, authenticated Pi to HQ after flashing."""
import argparse
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import socket
import subprocess
from urllib.error import URLError
from urllib.request import build_opener, ProxyHandler

ROOT = Path(__file__).resolve().parent.parent


class Retry(Exception):
    def __init__(self, message, diagnostics=''):
        super().__init__(message)
        self.diagnostics = diagnostics


def command(args, *, env=None, timeout=20):
    result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise Retry(Path(args[0]).name + ' is not ready (exit ' + str(result.returncode) + ')',
                    result.stdout + '\n' + result.stderr)
    return result.stdout.strip()


def resolve_ip():
    # Prefer mDNS over a possibly stale static /etc/hosts entry.
    try:
        answer = command(['avahi-resolve-host-name', '-4', 'factory-pi.local'], timeout=8)
        return str(ipaddress.IPv4Address(answer.split()[-1]))
    except (Retry, FileNotFoundError, ValueError):
        for record in socket.getaddrinfo('factory-pi.local', None, socket.AF_INET):
            return str(ipaddress.IPv4Address(record[4][0]))
    raise Retry('Waiting for factory-pi.local')


def http_json(ip, route):
    opener = build_opener(ProxyHandler({}))
    with opener.open('http://' + ip + ':8000' + route, timeout=10) as response:
        return json.load(response)


def validate_ready(output, instance_id):
    lines = output.splitlines()
    if len(lines) != 2:
        raise Retry('Pi bootstrap has not finished')
    ready = json.loads(lines[0])
    if ready.get('instance_id') != instance_id or ready.get('boot_id') != lines[1]:
        raise Retry('Waiting for the newly flashed instance to finish bootstrapping')
    return ready['boot_id']


def ensure_ui_services():
    opener = build_opener(ProxyHandler({}))
    for service, url in (
        ('kcd-grafana.service', 'http://127.0.0.1:3000/api/health'),
        ('kcd-argocd.service', 'http://127.0.0.1:8080'),
    ):
        try:
            with opener.open(url, timeout=3) as response:
                if response.status == 200:
                    continue
        except (OSError, URLError):
            pass
        command(['systemctl', '--user', 'start', service])


def wait_for_hq(kube):
    # A reachable API can coexist with an offline worker and stranded StatefulSets.
    command(kube + ['wait', 'nodes', '--all', '--for=condition=Ready', '--timeout=90s'],
            timeout=110)
    for namespace, workload in (
        ('argocd', 'statefulset/argocd-application-controller'),
        ('monitoring', 'statefulset/prometheus-kube-prometheus-stack-prometheus'),
    ):
        command(kube + ['-n', namespace, 'rollout', 'status', workload, '--timeout=180s'],
                timeout=200)


def update_interactive_known_hosts(ip, public_key):
    """Update only this Pi's names, after authenticating against the private pin."""
    directory = Path.home() / '.ssh'
    directory.mkdir(mode=0o700, exist_ok=True)
    path = directory / 'known_hosts'
    if path.exists():
        for name in ('factory-pi.local', ip):
            command(['ssh-keygen', '-R', name, '-f', str(path)])
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600), 'a') as stream:
        stream.write('factory-pi.local,' + ip + ' ' + public_key + '\n')


def reconnect(root=ROOT):
    local = root / '.local' / 'pi'
    pending = local / 'pending.json'
    if not pending.exists():
        return False  # Preparation alone must never contact an unplugged Pi.
    manifest = json.loads(pending.read_text())
    pin = (local / 'known_hosts').read_text().split(' ', 1)[1].strip()
    if pin != manifest['host_public_key']:
        raise Retry('Prepared SSH identity does not match the armed flash')
    ip = resolve_ip()
    ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8',
           '-o', 'StrictHostKeyChecking=yes', '-o', 'IdentitiesOnly=yes',
           '-o', 'HostKeyAlias=factory-pi.local',
           '-o', 'UserKnownHostsFile=' + str(local / 'known_hosts'),
           '-i', str(local / 'id_ed25519'), 'ubuntu@' + ip]
    boot_id = validate_ready(command(ssh + [
        'cat /var/lib/kcd-demo/ready && printf "\\n" && cat /proc/sys/kernel/random/boot_id'
    ]), manifest['instance_id'])
    if http_json(ip, '/healthz').get('status') != 'ok':
        raise Retry('Pi API has not started')

    context = 'k3d-' + os.environ.get('K3D_CLUSTER', 'hq')
    kube = ['kubectl', '--context', context, '--request-timeout=10s']
    try:
        hq_id = command(kube + ['get', 'namespace', 'kube-system', '-o', 'jsonpath={.metadata.uid}'])
    except Retry:
        command([str(root / 'hq' / 'up_linux.sh')], timeout=300)
        hq_id = command(kube + ['get', 'namespace', 'kube-system', '-o', 'jsonpath={.metadata.uid}'])
    try:
        command(kube + ['-n', 'argocd', 'get', 'deployment', 'argocd-server', '-o', 'name'])
        command(kube + ['-n', 'monitoring', 'get', 'service', 'kube-prometheus-stack-grafana', '-o', 'name'])
    except Retry:
        command([str(root / 'hq' / 'bootstrap-argocd_linux.sh')], timeout=1200)
    wait_for_hq(kube)
    ensure_ui_services()
    signature = {'instance_id': manifest['instance_id'], 'ip': ip,
                 'boot_id': boot_id, 'hq_id': hq_id}
    state_path = local / 'connected.json'
    previous = json.loads(state_path.read_text()) if state_path.exists() else None
    try:
        registered = command(kube + ['-n', 'argocd', 'get', 'secret', 'cluster-factory-pi',
                                    '-o', 'jsonpath={.metadata.annotations.kcd-demo/instance-id}'])
    except Retry:
        registered = ''
    if previous == signature and registered == manifest['instance_id']:
        return False

    env = {**os.environ, 'PI_HOST': ip,
           'PI_SSH_IDENTITY_FILE': str(local / 'id_ed25519'),
           'PI_SSH_KNOWN_HOSTS_FILE': str(local / 'known_hosts'),
           'PI_SSH_HOST_KEY_ALIAS': 'factory-pi.local'}
    print('Registering verified Pi at ' + ip + ' with ' + context, flush=True)
    command([str(root / 'pi' / 'up_linux.sh')], env=env, timeout=1200)
    # Registration restarts Prometheus to load the refreshed Pi credentials.
    wait_for_hq(kube)
    command(kube + ['-n', 'default', 'wait', '--for=condition=Ready',
                    'scaledobject/fan-autoscaler', 'scaledobject/led-autoscaler',
                    '--timeout=180s'], timeout=200)
    deployments = ['deployment/smart-vetrak-controller', 'deployment/smart-led-controller']
    command(kube + ['-n', 'default', 'rollout', 'restart'] + deployments)
    for deployment in deployments:
        command(kube + ['-n', 'default', 'rollout', 'status', deployment, '--timeout=120s'], timeout=140)
    # Initialize physical state even if a 0-replica controller had no lifecycle event.
    state = http_json(ip, '/state')
    for route, enabled in (
        ('vetrak', state['fan_controller_enabled']),
        ('led', state['solar_generation_watts'] > state['sun_threshold_w']),
    ):
        if not http_json(ip, '/' + route + ('/on' if enabled else '/off')).get('ok'):
            raise Retry('Waiting for Tuya device ' + route)
    command(kube + ['-n', 'argocd', 'annotate', 'secret', 'cluster-factory-pi',
                   'kcd-demo/instance-id=' + manifest['instance_id'], '--overwrite'])
    update_interactive_known_hosts(ip, manifest['host_public_key'])
    temporary = state_path.with_suffix('.tmp')
    temporary.write_text(json.dumps(signature) + '\n')
    temporary.chmod(0o600)
    os.replace(temporary, state_path)
    print('HQ and physical device state restored.', flush=True)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    local = args.root / '.local' / 'pi'
    local.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.umask(0o077)
    with (local / 'reconnect.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        try:
            reconnect(args.root)
        except (Retry, OSError, ValueError, URLError, subprocess.SubprocessError) as error:
            details = getattr(error, 'diagnostics', '')
            if details:
                path = local / 'last-error.log'
                with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as stream:
                    stream.write(details)
            print('Automatic reconnect pending: ' + str(error))
            raise SystemExit(1)


if __name__ == '__main__':
    main()
