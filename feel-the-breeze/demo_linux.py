#!/usr/bin/env python3
"""Stop or resume the prepared laptop + physical Pi demo without reflashing."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.parse import quote
from urllib.request import ProxyHandler, build_opener

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'pi'))
from auto_reconnect import Retry, resolve_ip, update_interactive_known_hosts, validate_ready, wait_for_hq
from prepare_autoflash import private_dir, private_write

KUBE = ['kubectl', '--context', 'k3d-hq', '--request-timeout=10s']
DEPLOYMENTS = ['smart-vetrak-controller', 'smart-led-controller']
SCALERS = ['scaledobject/fan-autoscaler', 'scaledobject/led-autoscaler']
UNITS = ['kcd-pi-reconnect.timer', 'kcd-grafana.service', 'kcd-argocd.service']
PODS = 'app in (smart-vetrak-controller,smart-led-controller)'


class Demo:
    def __init__(self):
        self.local = ROOT / '.local' / 'demo'
        self.owner = (ROOT.stat().st_uid, ROOT.stat().st_gid)
        private_dir(self.local, self.owner)
        self.ip = None
        self.ssh = None

    def run(self, args, *, capture=False, timeout=30, input=None):
        result = subprocess.run(args, capture_output=capture, text=True,
                                timeout=timeout, input=input)
        if result.returncode:
            if capture:
                private_write(self.local / 'last-error.log',
                              result.stdout + '\n' + result.stderr, self.owner)
            raise RuntimeError(Path(args[0]).name + ' failed; see .local/demo/last-error.log if present')
        return result.stdout.strip() if capture else ''

    def kube(self, *args, **kwargs):
        return self.run(KUBE + list(args), **kwargs)

    def api(self, route):
        opener = build_opener(ProxyHandler({}))
        with opener.open('http://' + self.ip + ':8000' + route, timeout=20) as response:
            return json.load(response)

    def connect(self, wait=False):
        deadline = time.monotonic() + (300 if wait else 1)
        while True:
            try:
                host = os.environ.get('PI_HOST')
                self.ip = socket.gethostbyname(host) if host else resolve_ip()
                self.ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8',
                            '-o', 'StrictHostKeyChecking=yes', '-o', 'HostKeyAlias=factory-pi.local']
                local = ROOT / '.local' / 'pi'
                pending = local / 'pending.json'
                if pending.exists():
                    manifest = json.loads(pending.read_text())
                    if (local / 'known_hosts').read_text().split(' ', 1)[1].strip() != manifest['host_public_key']:
                        raise ValueError('Prepared Pi host identity does not match the pending flash')
                    self.ssh += ['-o', 'IdentitiesOnly=yes', '-i', str(local / 'id_ed25519'),
                                 '-o', 'UserKnownHostsFile=' + str(local / 'known_hosts')]
                self.ssh.append(os.environ.get('PI_USER', 'ubuntu') + '@' + self.ip)
                self.run(self.ssh + ['sudo -n true'], capture=True)
                if wait and pending.exists():
                    ready = self.run(self.ssh + [
                        'cat /var/lib/kcd-demo/ready && printf "\\n" && cat /proc/sys/kernel/random/boot_id'
                    ], capture=True)
                    validate_ready(ready, json.loads(pending.read_text())['instance_id'])
                if self.api('/healthz').get('status') != 'ok':
                    raise RuntimeError('Pi API is not ready')
                print('Authenticated Pi:', self.ip, flush=True)
                return
            except (OSError, RuntimeError, ValueError, Retry, subprocess.TimeoutExpired):
                if time.monotonic() >= deadline:
                    raise
                print('Waiting for the Pi and its API on this LAN...', flush=True)
                time.sleep(5)

    def suspend_services(self, disable=False):
        action = ['disable', '--now'] if disable else ['stop']
        self.run(['systemctl', '--user'] + action + UNITS)
        self.run(['systemctl', '--user', 'stop', 'kcd-pi-reconnect.service'])

    def pause_controllers(self):
        self.kube('-n', 'default', 'annotate', *SCALERS,
                  'autoscaling.keda.sh/paused-replicas=0', '--overwrite')
        self.kube('-n', 'default', 'scale', *['deployment/' + n for n in DEPLOYMENTS], '--replicas=0')

    def wait_controllers_stopped(self):
        deadline = time.monotonic() + 150
        while time.monotonic() < deadline:
            pods = json.loads(self.kube('-n', 'default', 'get', 'pods', '-l', PODS,
                                        '-o', 'json', capture=True))['items']
            if not pods:
                return
            time.sleep(3)
        raise RuntimeError('Controller pods have not finished stopping; Pi remains powered on')

    def runtime(self, action):
        self.run(['bash', str(ROOT / 'hq' / 'power_linux.sh'), action], timeout=420)

    def record(self, status):
        private_write(self.local / 'state.json', json.dumps({
            'status': status, 'pi_ip': self.ip, 'time_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        }) + '\n', self.owner)

    def wait_poweroff(self):
        # Give systemd time to flush storage and finish powering down.
        print('Pi accepted poweroff; allowing 30 seconds for shutdown...', flush=True)
        time.sleep(30)
        try:
            with socket.create_connection((self.ip, 22), timeout=3):
                raise RuntimeError('Pi still answers on SSH; check shutdown before disconnecting power')
        except OSError:
            return

    def stop(self):
        self.connect()
        self.suspend_services(disable=True)
        self.pause_controllers()
        result = self.api('/blackout')
        if not all(result.get(role, {}).get('ok') for role in ('fan', 'led')):
            raise RuntimeError('Both physical devices must acknowledge OFF before shutdown')
        self.wait_controllers_stopped()
        # No Kubernetes lifecycle hooks can run after this point.
        print('Controllers stopped; fan and LED acknowledged OFF.', flush=True)
        self.runtime('stop')
        self.run(self.ssh + [
            'sudo -n systemctl stop kcd-bootstrap.service kcd-tuya.service; '
            'sudo -n sync && sudo -n systemctl poweroff --no-block'
        ], capture=True)
        self.wait_poweroff()
        self.record('stopped')
        print('STOPPED. HQ containers retained, laptop demo services disabled, Pi shut down.', flush=True)
        print('You may disconnect Pi, meter and device power. Resume with: python3 demo_linux.py start')

    def refresh_devices(self):
        # Send public source only. Device credentials remain on the Pi.
        source = (ROOT / 'pi' / 'refresh_tuya.py').read_text()
        payload = 'import sys\nsys.argv=["refresh_tuya.py","--env","/opt/kcd-tuya/devices.env"]\n' + source
        self.run(self.ssh + ['sudo -n /opt/kcd-tuya/.venv/bin/python -'],
                 input=payload, timeout=90)
        self.run(self.ssh + ['sudo -n systemctl restart kcd-tuya.service'], capture=True)
        for _ in range(20):
            try:
                if self.api('/healthz').get('status') == 'ok':
                    return
            except OSError:
                pass
            time.sleep(1)
        raise RuntimeError('Pi API did not restart')

    def wait_monitoring(self):
        wait_for_hq(KUBE)
        self.kube('-n', 'default', 'wait', '--for=condition=Ready', *SCALERS,
                  '--timeout=180s', timeout=200)
        expected = {'factory-pi/' + job for job in (
            'solar-simulation', 'cadvisor', 'kube-state-metrics', 'node-exporter', 'kubelet', 'kepler')}
        url = 'http://localhost:9090/api/v1/query?query=' + quote('up{cluster="factory-pi"}', safe='')
        # A fresh 2 GB Pi can saturate SD I/O while unpacking exporter images.
        deadline = time.monotonic() + 600
        report_at = 0
        while time.monotonic() < deadline:
            data = json.loads(self.kube('-n', 'monitoring', 'exec',
                'prometheus-kube-prometheus-stack-prometheus-0', '-c', 'prometheus', '--',
                'wget', '-qO-', url, capture=True))
            healthy = {item['metric']['job'] for item in data.get('data', {}).get('result', [])
                       if item['value'][1] == '1'}
            if expected <= healthy:
                print('All six Pi monitoring targets are healthy.', flush=True)
                return
            if time.monotonic() >= report_at:
                print('Waiting for Pi metrics: ' + ', '.join(sorted(expected - healthy)), flush=True)
                report_at = time.monotonic() + 30
            time.sleep(5)
        raise RuntimeError('Pi monitoring targets did not all become healthy')

    def adopt_autoflash(self):
        # A manual resume after flashing must not trigger a second enrolment
        # when the reconnect timer is re-enabled below.
        local = ROOT / '.local' / 'pi'
        pending = local / 'pending.json'
        if not pending.exists():
            return
        manifest = json.loads(pending.read_text())
        pin = (local / 'known_hosts').read_text().split(' ', 1)[1].strip()
        if pin != manifest['host_public_key']:
            raise ValueError('Prepared Pi host identity changed during startup')
        boot_id = validate_ready(self.run(self.ssh + [
            'cat /var/lib/kcd-demo/ready && printf "\\n" && cat /proc/sys/kernel/random/boot_id'
        ], capture=True), manifest['instance_id'])
        hq_id = self.kube('get', 'namespace', 'kube-system', '-o', 'jsonpath={.metadata.uid}', capture=True)
        self.kube('-n', 'argocd', 'annotate', 'secret', 'cluster-factory-pi',
                  'kcd-demo/instance-id=' + manifest['instance_id'], '--overwrite')
        update_interactive_known_hosts(self.ip, manifest['host_public_key'])
        private_write(local / 'connected.json', json.dumps({
            'instance_id': manifest['instance_id'], 'ip': self.ip,
            'boot_id': boot_id, 'hq_id': hq_id,
        }) + '\n', self.owner)

    def start(self):
        self.suspend_services()
        # Existing context and containers are required; this path never creates a cluster.
        if self.run(['kubectl', 'config', 'get-contexts', 'k3d-hq', '-o', 'name'], capture=True) != 'k3d-hq':
            raise RuntimeError('Existing k3d-hq context is missing; refusing to create a replacement')
        try:
            nodes = json.loads(self.kube('get', 'nodes', '-o', 'json', capture=True))['items']
            ready = len(nodes) == 2 and all(any(c['type'] == 'Ready' and c['status'] == 'True'
                for c in n['status']['conditions']) for n in nodes)
        except (RuntimeError, ValueError):
            ready = False
        if not ready:
            self.runtime('start')
        self.kube('wait', 'nodes', '--all', '--for=condition=Ready', '--timeout=180s', timeout=200)
        self.pause_controllers()
        self.connect(wait=True)
        self.refresh_devices()
        env = dict(os.environ, PI_HOST=self.ip, K3D_CLUSTER='hq')
        local = ROOT / '.local' / 'pi'
        if (local / 'pending.json').exists():
            env.update(PI_SSH_IDENTITY_FILE=str(local / 'id_ed25519'),
                       PI_SSH_KNOWN_HOSTS_FILE=str(local / 'known_hosts'))
        else:
            env['PI_SSH_KNOWN_HOSTS_FILE'] = str(Path.home() / '.ssh' / 'known_hosts')
        env['PI_SSH_HOST_KEY_ALIAS'] = 'factory-pi.local'
        result = subprocess.run([str(ROOT / 'pi' / 'up_linux.sh')], env=env, timeout=1200)
        if result.returncode:
            raise RuntimeError('Pi/HQ registration failed; controllers remain paused')
        self.pause_controllers()
        self.wait_controllers_stopped()
        wait_for_hq(KUBE)
        self.api('/recover')
        self.kube('-n', 'default', 'annotate', *SCALERS, 'autoscaling.keda.sh/paused-replicas-')
        self.finish_start()

    def finish_start(self):
        """Wait and publish readiness without restarting already applied workloads."""
        self.wait_monitoring()
        deadline = time.monotonic() + 150
        while time.monotonic() < deadline:
            state = self.api('/state')
            age = state.get('measurement_age_s')
            if not state.get('meter_connected') or age is None or age > 5:
                raise RuntimeError('FNB48P has no fresh USB measurement; connect the meter and retry start')
            desired = dict(zip(DEPLOYMENTS, (1, int(state['solar_generation_watts'] > state['sun_threshold_w']))))
            items = json.loads(self.kube('-n', 'default', 'get', 'deployments', *DEPLOYMENTS,
                                         '-o', 'json', capture=True))['items']
            if all(d['spec'].get('replicas', 0) == desired[d['metadata']['name']] and
                   d.get('status', {}).get('availableReplicas', 0) == desired[d['metadata']['name']]
                   for d in items):
                break
            time.sleep(3)
        else:
            raise RuntimeError('KEDA controllers did not settle')
        for route, enabled in (('vetrak', True), ('led', bool(desired[DEPLOYMENTS[1]]))):
            if not self.api('/' + route + ('/on' if enabled else '/off')).get('ok'):
                raise RuntimeError('Device did not acknowledge the recovered state: ' + route)
        self.adopt_autoflash()
        self.run(['systemctl', '--user', 'enable', '--now', *UNITS])
        self.record('running')
        print('RUNNING. Fan ON; LED follows measured panel power.', flush=True)
        print('Grafana: http://localhost:3000   ArgoCD: http://localhost:8080')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('start', 'stop'))
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as the laptop user, without sudo; Docker prompts separately if needed.')
    os.umask(0o077)
    try:
        demo = Demo()
        with (demo.local / 'control.lock').open('a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError('Another demo start/stop is already running')
            getattr(demo, args.action)()
    except (OSError, RuntimeError, Retry, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit('Demo ' + args.action + ' incomplete: ' + str(error))


if __name__ == '__main__':
    main()
