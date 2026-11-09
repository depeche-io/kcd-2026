#!/usr/bin/env python3
"""Find configured Tuya devices on a new LAN without cloud credentials."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import shlex
import tempfile


def read_env(text):
    values = {}
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        name, value = line.split('=', 1)
        parsed = shlex.split(value)
        if len(parsed) != 1:
            raise ValueError('Invalid value for ' + name.strip())
        values[name.strip()] = parsed[0]
    return values


def validate(values):
    for role in ('FAN', 'LED'):
        prefix = 'TUYA_' + role + '_'
        for field in ('DEVICE_ID', 'LOCAL_KEY', 'VERSION', 'SWITCH_DP'):
            if not values.get(prefix + field):
                raise ValueError('Missing ' + prefix + field)
        if len(values[prefix + 'LOCAL_KEY']) != 16:
            raise ValueError('Invalid local key length for ' + role)
        if values[prefix + 'VERSION'] not in ('3.1', '3.2', '3.3', '3.4', '3.5'):
            raise ValueError('Unsupported protocol version for ' + role)
        if int(values[prefix + 'SWITCH_DP']) <= 0:
            raise ValueError('Invalid switch DP for ' + role)


def refresh(values, discovered, device_factory):
    updated = dict(values)
    by_id = {d.get('gwId') or d.get('id'): dict(d, ip=d.get('ip', ip))
             for ip, d in discovered.items()}
    for role in ('FAN', 'LED'):
        prefix = 'TUYA_' + role + '_'
        found = by_id.get(values[prefix + 'DEVICE_ID'])
        if not found:
            raise ValueError(role + ': device not found on this LAN')
        ip = str(ipaddress.IPv4Address(found['ip']))
        version = str(found.get('version') or values[prefix + 'VERSION'])
        device = device_factory(values[prefix + 'DEVICE_ID'], ip,
                                values[prefix + 'LOCAL_KEY'], version=float(version))
        try:
            device.set_socketTimeout(3)
            device.set_socketRetryLimit(1)
            status = device.status()
            if not isinstance(status, dict) or values[prefix + 'SWITCH_DP'] not in status.get('dps', {}):
                raise ValueError(role + ': cannot read switch DP; check pairing, local key and protocol')
        finally:
            device.close()
        updated[prefix + 'IP'] = ip
        updated[prefix + 'VERSION'] = version
    return updated


def save_env(path, original, values):
    lines = [line for line in original.splitlines()
             if line.split('=', 1)[0].strip() not in values]
    lines.extend(name + '=' + json.dumps(value, ensure_ascii=False)
                 for name, value in values.items())
    fd, temporary = tempfile.mkstemp(prefix='.devices.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write('\n'.join(lines) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    import tinytuya
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env', type=Path, required=True)
    args = parser.parse_args()
    original = args.env.read_text()
    values = read_env(original)
    validate(values)
    devices = tinytuya.deviceScan(verbose=False, maxretry=12, poll=False)
    updated = refresh(values, devices, tinytuya.Device)
    save_env(args.env, original, updated)
    for role in ('FAN', 'LED'):
        print(role + ': verified at ' + updated['TUYA_' + role + '_IP'])


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit(str(error))
