"""Verify that a recovered dirty feed is reported in the generator manifest."""
import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import test_feeds_incremental as feed_fixtures

spec = importlib.util.spec_from_file_location('incremental', feed_fixtures.ROOT/'scripts/gen_config_incremental.py')
incremental = importlib.util.module_from_spec(spec)
spec.loader.exec_module(incremental)


class ManifestTests(unittest.TestCase):
    def test_dirty_feed_reset_manifest_is_per_update(self):
        fixture = feed_fixtures.FeedTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        fixture.update()
        tree = fixture.tree
        (tree/'feeds.conf').write_bytes((tree/'feeds.conf.default').read_bytes())
        fixture.git(tree, 'init', '-q')
        (tree/'.gitignore').write_text('feeds/\nlogs/\n.genconfig-state/\n.config\n')
        fixture.git(tree, 'add', '.')
        fixture.git(tree, 'commit', '-qm', 'fixture')
        (tree/'feeds/test/untracked').touch()
        previous_cwd = Path.cwd()
        try:
            os.chdir(tree)
            with patch.dict(os.environ, fixture.env):
                for expected in ('dirty-feed', None):
                    setup = incremental.IncrementalSetup()
                    setup.update()
                    Path('.config').write_text('CONFIG_TEST=y\n')
                    setup.finish()
                    plan = json.loads(Path('logs/incremental-plan.json').read_text())
                    self.assertEqual(plan['feeds'][0]['reset_reason'], expected)
                    self.assertEqual(plan['feeds'][0]['changed_paths'], [])
                    self.assertFalse(plan['feeds'][0]['requires_full_rebuild'])
                    self.assertFalse(Path('feeds/test/untracked').exists())
        finally:
            os.chdir(previous_cwd)


if __name__ == '__main__':
    unittest.main()
