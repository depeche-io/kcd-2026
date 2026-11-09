"""Check the real systemd ordering graph that previously skipped Pi bootstrap."""
import configparser
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(shutil.which('systemd-analyze'), 'systemd-analyze is not installed')
class BootstrapOrderingTests(unittest.TestCase):
    def verify_boot(self, target=None):
        source = (Path(__file__).resolve().parents[1] / 'kcd-bootstrap.service').read_text()
        config = configparser.ConfigParser(interpolation=None)
        config.read_string(source)
        installed_target = config['Install']['WantedBy']
        target = target or installed_target
        source = source.replace('ExecStart=/usr/local/sbin/kcd-bootstrap', 'ExecStart=/bin/true')
        source = source.replace('WantedBy=' + installed_target, 'WantedBy=' + target)
        with tempfile.TemporaryDirectory(prefix='kcd-boot-order-') as tmp:
            folder = Path(tmp)
            for name in ('basic.target', 'sysinit.target', 'shutdown.target', 'network-online.target'):
                (folder / name).write_text('[Unit]\nDefaultDependencies=no\n')
            # multi-user.target has implicit After= ordering for wanted services.
            (folder / 'multi-user.target').write_text('[Unit]\n')
            (folder / 'cloud-init.target').write_text(
                '[Unit]\nAfter=multi-user.target\nWants=cloud-final.service\n')
            (folder / 'cloud-final.service').write_text(
                '[Unit]\nDefaultDependencies=no\nAfter=multi-user.target\n'
                '[Service]\nType=oneshot\nExecStart=/bin/true\n')
            (folder / 'test-boot.target').write_text(
                '[Unit]\nWants=multi-user.target cloud-init.target\n')
            (folder / 'kcd-bootstrap.service').write_text(source)
            wants = folder / (target + '.wants')
            wants.mkdir()
            (wants / 'kcd-bootstrap.service').symlink_to('../kcd-bootstrap.service')
            result = subprocess.run(['systemd-analyze', 'verify', str(folder / 'test-boot.target')],
                env=dict(os.environ, SYSTEMD_UNIT_PATH=str(folder)),
                capture_output=True, text=True, timeout=20)
            return result.returncode, (result.stdout + result.stderr).lower()

    def test_bootstrap_runs_after_cloud_final_without_an_ordering_cycle(self):
        code, output = self.verify_boot()
        self.assertEqual(code, 0, output)
        self.assertNotIn('ordering cycle', output)

    def test_fixture_detects_the_original_multi_user_ordering_cycle(self):
        _, output = self.verify_boot('multi-user.target')
        self.assertIn('ordering cycle', output)


if __name__ == '__main__':
    unittest.main()
