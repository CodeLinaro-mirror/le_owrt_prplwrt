"""Exercise the real feeds updater with local Git repositories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FeedTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.tree = self.base/'tree'
        (self.tree/'scripts').mkdir(parents=True)
        for name in ('feeds', 'metadata.pm'):
            shutil.copy2(ROOT/'scripts'/name, self.tree/'scripts'/name)
        self.remote = self.base/'remote'
        self.remote.mkdir()
        self.git(self.remote, 'init', '-q')
        (self.remote/'Makefile').write_text('original\n')
        self.git(self.remote, 'add', '.')
        self.git(self.remote, 'commit', '-qm', 'original')
        self.old = self.git(self.remote, 'rev-parse', 'HEAD')
        (self.remote/'other').write_text('new\n')
        self.git(self.remote, 'add', '.')
        self.git(self.remote, 'commit', '-qm', 'new file')
        self.new = self.git(self.remote, 'rev-parse', 'HEAD')
        self.bin = self.base/'bin'
        self.bin.mkdir()
        make = self.bin/'make'
        make.write_text('''#!/usr/bin/env python3
import pathlib,sys
if '-v' in sys.argv:
 print('GNU Make 4.4'); sys.exit(0)
args=dict(a.split('=',1) for a in sys.argv[1:] if '=' in a)
if 'SCAN_TARGET' in args:
 p=pathlib.Path(args['TMP_DIR']); p.mkdir(parents=True,exist_ok=True)
 (p/('.'+args['SCAN_TARGET'])).touch()
''')
        make.chmod(0o755)
        (self.bin/'gmake').symlink_to('make')
        self.env = {**os.environ, 'PATH': str(self.bin)+':'+os.environ['PATH'],
                    'GIT_ALLOW_PROTOCOL': 'file', 'TOPDIR': str(self.tree)}
        self.pin(self.old)

    def git(self, directory, *args):
        return subprocess.check_output([
            'git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            '-c', 'commit.gpgsign=false', '-C', str(directory), *args],
            text=True, stderr=subprocess.DEVNULL).strip()

    def pin(self, sha):
        (self.tree/'feeds.conf.default').write_text(f'src-git test {self.remote.as_uri()}^{sha}\n')

    def update(self):
        result = subprocess.run(['scripts/feeds', 'update', '-k'], cwd=self.tree,
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_unchanged_pin_preserves_worktree_and_index_mtimes(self):
        self.update()
        paths = [self.tree/'feeds'/p for p in ('test/Makefile', 'test/.git/config',
                                             'test.tmp/.packageinfo', 'test.tmp/location')]
        before = [p.stat().st_mtime_ns for p in paths]
        self.update()
        self.assertEqual(before, [p.stat().st_mtime_ns for p in paths])

    def test_dirty_feed_reclones_and_records_reset(self):
        self.update()
        feed = self.tree/'feeds/test'
        self.git(feed, 'config', 'fixture.retained', 'yes')
        (feed/'untracked').touch()
        (feed/'Makefile').write_text('dirty\n')
        result = self.update()
        self.assertIn('dirty worktree, replacing copy', result.stderr)
        self.assertFalse((feed/'untracked').exists())
        self.assertEqual((feed/'Makefile').read_text(), 'original\n')
        self.assertNotIn('retained', (feed/'.git/config').read_text())
        self.assertEqual(self.git(feed, 'status', '--porcelain', '-uall'), '')
        marker = self.tree/'feeds/test.tmp/incremental-reset'
        self.assertEqual(marker.read_text(), 'dirty-feed\n')
        self.assertFalse((self.tree/'.genconfig-state/incremental-plan.failed').exists())
        self.update()
        self.assertFalse(marker.exists())

    def test_changed_pin_fetches_in_place_and_detaches(self):
        self.update()
        feed = self.tree/'feeds/test'
        self.git(feed, 'config', 'fixture.retained', 'yes')
        before = (feed/'Makefile').stat().st_mtime_ns
        self.pin(self.new)
        self.update()
        self.assertEqual(self.git(feed, 'rev-parse', 'HEAD'), self.new)
        self.assertEqual(self.git(feed, 'config', 'fixture.retained'), 'yes')
        self.assertEqual((feed/'Makefile').stat().st_mtime_ns, before)
        self.assertEqual(self.git(feed, 'rev-parse', '--abbrev-ref', 'HEAD'), 'HEAD')


if __name__ == '__main__':
    unittest.main()
