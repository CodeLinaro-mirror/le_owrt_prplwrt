"""Registry tests use mocked HTTP commands; never contact GitLab."""
import gzip
import json
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

    def test_fetch_latest_numeric_version_from_target_project(self):
        env = {**ENV, 'CI_PIPELINE_SOURCE': 'merge_request_event',
               'CI_MERGE_REQUEST_TARGET_BRANCH_NAME': 'latest-24.10',
               'CI_MERGE_REQUEST_TARGET_PROJECT_ID': '99'}
        entries = [{'name': 'memory-footprint-latest-24.10', 'package_type': 'generic',
                    'version': version} for version in ('99', '100')]
        entries.append({**entries[0], 'name': 'memory-footprint-latest-24.10-extra',
                        'version': '999'})
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, env, clear=True):
            replies = [json.dumps(entries).encode(), gzip.compress(b'boot'), gzip.compress(b'final')]
            urls = []
            def request(client, path, *args):
                urls.append(client.url + path)
                return replies.pop(0)
            with patch.object(registry.Registry, 'request', request):
                registry.fetch(Path(tmp), 'board', 'full')
            self.assertTrue(all('/projects/99/' in url for url in urls))
            self.assertIn('/100/board-full-boot.txt.gz', urls[1])
            self.assertEqual((Path(tmp) / 'baseline-final.txt').read_bytes(), b'final')

    def test_missing_or_corrupt_pair_publishes_neither_file(self):
        env = {**ENV, 'CI_PIPELINE_SOURCE': 'merge_request_event',
               'CI_MERGE_REQUEST_TARGET_BRANCH_NAME': 'latest-24.10'}
        for final in (b'corrupt', RuntimeError('404')):
            with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, env, clear=True):
                with patch.object(registry.Registry, 'packages', return_value=[{'version': '1'}]), \
                     patch.object(registry.Registry, 'request', side_effect=[gzip.compress(b'boot'), final]):
                    with self.assertRaises((OSError, RuntimeError)):
                        registry.fetch(Path(tmp), 'board', 'full')
                self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_package_pagination(self):
        entry = {'name': 'memory-footprint-main', 'package_type': 'generic', 'version': '1'}
        with patch.dict(os.environ, ENV, clear=True), \
             patch.object(registry.Registry, 'request', side_effect=[
                 json.dumps([entry] * 100).encode(), b'[]']) as request:
            client = registry.Registry('42', 'token')
            self.assertEqual(len(client.packages(entry['name'])), 100)
            self.assertIn('page=2', request.call_args.args[0])

    def test_cleanup_keeps_twelve_distinct_numeric_versions(self):
        entries = [{'id': version, 'version': str(version)} for version in range(1, 15)]
        entries.append({'id': 99, 'version': '14'})
        env = {**ENV, 'MEMORY_FOOTPRINT_API_TOKEN': 'cleanup-token'}
        with patch.dict(os.environ, env, clear=True), \
             patch.object(registry.Registry, 'packages', return_value=entries), \
             patch.object(registry.Registry, 'request') as request:
            registry.cleanup()
            self.assertEqual([call.args for call in request.call_args_list],
                             [('/1', '--request', 'DELETE'), ('/2', '--request', 'DELETE')])
            request.reset_mock()
            os.environ['CI_COMMIT_BRANCH'] = 'latest-24.10'
            registry.cleanup()
            request.assert_not_called()

    def test_cleanup_without_token_never_deletes(self):
        with patch.dict(os.environ, ENV, clear=True), \
             patch.object(registry.Registry, 'request') as request:
            with self.assertRaisesRegex(ValueError, 'credential'):
                registry.cleanup()
            request.assert_not_called()


if __name__ == '__main__':
    unittest.main()
