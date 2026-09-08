"""Registry tests use mocked HTTP commands; never contact GitLab."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'registry', Path(__file__).resolve().parents[1] / 'memory-footprint-registry.py')
registry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(registry)
ENV = {'CI_COMMIT_BRANCH': 'ci-weekly/latest-24.10/2026-09-08',
       'CI_PIPELINE_ID': '123', 'CI_PROJECT_ID': '42',
       'CI_API_V4_URL': 'https://example.invalid/api/v4', 'CI_JOB_TOKEN': 'test-token'}


class RegistryTests(unittest.TestCase):
    def test_weekly_naming(self):
        with patch.dict(os.environ, ENV, clear=True):
            self.assertEqual(registry.weekly_package(), 'memory-footprint-latest-24.10')
        with patch.dict(os.environ, {'CI_COMMIT_BRANCH': 'latest-24.10'}, clear=True):
            self.assertIsNone(registry.weekly_package())
        with patch.dict(os.environ, {'CI_COMMIT_BRANCH': 'ci-weekly/latest-24.10'}, clear=True):
            with self.assertRaises(ValueError):
                registry.weekly_package()
        self.assertNotEqual(registry.key('a/b'), registry.key('a_2fb'))
        self.assertEqual(registry.key('CDRouter+mDNS'), 'CDRouter_2bmDNS')

    def test_upload_complete_pair_and_summary(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, ENV, clear=True):
            output = Path(tmp)
            with patch.object(registry.Registry, 'request') as request:
                with self.assertRaises(ValueError):
                    registry.push(output, 'board', 'full')
                request.assert_not_called()
                for name in ('boot.txt.gz', 'final.txt.gz', 'summary.json'):
                    (output / name).write_text('fixture')
                registry.push(output, 'board', 'full')
                self.assertEqual(request.call_count, 3)
                self.assertEqual(request.call_args.args[0],
                                 '/generic/memory-footprint-latest-24.10/123/board-full-summary.json')
                request.reset_mock()
                os.environ['CI_COMMIT_BRANCH'] = 'latest-24.10'
                registry.push(output, 'board', 'full')
                request.assert_not_called()


if __name__ == '__main__':
    unittest.main()
