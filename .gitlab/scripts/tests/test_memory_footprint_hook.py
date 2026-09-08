"""Exercise the hook without a DUT, container, or network."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HOOK = Path(__file__).resolve().parents[1] / 'memory-footprint.sh'


class HookTests(unittest.TestCase):
    def test_suite_survives_after_script_and_old_tool(self):
        for suite in ('prplos', 'CDRouter-Top-100+mDNS', 'lcm,prplos'):
            for modern in (False, True):
                with self.subTest(suite=suite, modern=modern), tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)
                    binary = root / 'bin'
                    binary.mkdir()
                    scripts = {
                        'scp': '#!/bin/sh\nexit "${COPY_STATUS:-0}"\n',
                        'ssh': '#!/bin/sh\necho snapshot\n',
                        'mem-report': '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
if '--help' in sys.argv:
    print('--metrics-label --widget-metrics' if os.environ['MODERN'] == '1' else '')
else:
    Path('args.json').write_text(json.dumps(sys.argv[1:]))
    for option in ('-o', '--metrics', '--summary', '--widget-metrics'):
        if option in sys.argv:
            Path(sys.argv[sys.argv.index(option) + 1]).write_text('report')
''',
                    }
                    for name, script in scripts.items():
                        path = binary / name
                        path.write_text(script)
                        path.chmod(0o755)
                    env = {**os.environ, 'PATH': f'{binary}:{os.environ["PATH"]}',
                           'DUT_BOARD': 'board', 'TARGET_LAN_IP': 'dummy',
                           'MODERN': str(int(modern)), 'COMPONENT': suite,
                           'CI_PIPELINE_SOURCE': 'push', 'CI_COMMIT_BRANCH': 'test'}
                    env.pop('TEST_PACKAGE', None)
                    if suite.startswith('CDRouter'):
                        env['TEST_PACKAGE'] = suite
                    def run(phase):
                        result = subprocess.run(['sh', str(HOOK), phase], cwd=root,
                                                env=env, capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        return result
                    run('boot')
                    env.pop('TEST_PACKAGE', None)
                    env.pop('COMPONENT', None)
                    result = run('final')
                    args = json.loads((root / 'args.json').read_text())
                    self.assertEqual('--metrics-label' in args, modern)
                    self.assertEqual('--widget-metrics' in args, modern)
                    if modern:
                        self.assertIn(f'suite={suite}', args)
                    else:
                        self.assertIn('WARNING', result.stderr)
                    (root / 'memory-footprint/board/suite').unlink()
                    (root / 'args.json').unlink()
                    result = run('final')
                    self.assertIn('missing boot suite identity', result.stderr)
                    self.assertNotIn('cat:', result.stderr)
                    self.assertEqual(result.stderr.count('WARNING'), 1 if modern else 2)
                    args = json.loads((root / 'args.json').read_text())
                    self.assertNotIn('--metrics-label', args)
                    self.assertNotIn('--baseline-boot', args)
                    outputs = ['report.html', 'metrics.prom', 'summary.json', 'final.txt.gz']
                    if modern:
                        outputs.append('widget.prom')
                    for name in outputs:
                        self.assertTrue((root / 'memory-footprint/board' / name).is_file())
                    env['COPY_STATUS'] = '1'
                    self.assertIn('WARNING', run('boot').stderr)
                    self.assertFalse((root / 'memory-footprint/board/boot.txt.gz').exists())

    def test_registry_pipeline_paths_and_failures(self):
        for mode in ('weekly', 'upload-error', 'report-error', 'push', 'weekly-no-suite'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                binary = root / 'bin'
                binary.mkdir()
                scripts_dir = root / '.gitlab/scripts'
                scripts_dir.mkdir(parents=True)
                (scripts_dir / 'memory-footprint-registry.py').write_text(
                    HOOK.with_name('memory-footprint-registry.py').read_text())
                scripts = {
                    'scp': '#!/bin/sh\nexit 0\n',
                    'ssh': '#!/bin/sh\necho snapshot\n',
                    'mem-report': '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
if '--help' in sys.argv:
    print('--metrics-label --widget-metrics --baseline-boot --baseline-final')
else:
    Path('args.json').write_text(json.dumps(sys.argv[1:]))
    for option in ('--baseline-boot', '--baseline-final'):
        if option in sys.argv:
            assert Path(sys.argv[sys.argv.index(option) + 1]).read_text() == 'baseline'
    Path(sys.argv[sys.argv.index('--summary') + 1]).write_text('{}')
    sys.exit(1 if os.environ['TEST_MODE'] == 'report-error' else 0)
''',
                    'curl': '''#!/usr/bin/env python3
import gzip, json, os, sys
from pathlib import Path
with Path('requests.jsonl').open('a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
if '--upload-file' in sys.argv:
    sys.exit(22 if os.environ['TEST_MODE'] == 'upload-error' else 0)
elif '/generic/' in sys.argv[-1]:
    if os.environ['TEST_MODE'] == 'missing':
        sys.exit(22)
    sys.stdout.buffer.write(gzip.compress(b'baseline'))
else:
    print(json.dumps([{'name': 'memory-footprint-latest-24.10',
                       'package_type': 'generic', 'version': '100'}]))
''',
                }
                for name, script in scripts.items():
                    path = binary / name
                    path.write_text(script)
                    path.chmod(0o755)
                weekly = mode in ('weekly', 'upload-error', 'report-error', 'weekly-no-suite')
                env = {**os.environ, 'PATH': f'{binary}:{os.environ["PATH"]}',
                       'DUT_BOARD': 'board', 'TARGET_LAN_IP': 'dummy', 'COMPONENT': 'full',
                       'CI_PIPELINE_SOURCE': 'merge_request_event' if mode in ('mr', 'missing', 'mr-no-suite') else 'push',
                       'CI_COMMIT_BRANCH': 'ci-weekly/latest-24.10/2026-09-08' if weekly else 'test',
                       'CI_MERGE_REQUEST_TARGET_BRANCH_NAME': 'latest-24.10',
                       'CI_API_V4_URL': 'https://example.invalid/api/v4', 'CI_PROJECT_ID': '42',
                       'CI_JOB_TOKEN': 'test-token', 'CI_PIPELINE_ID': '200', 'TEST_MODE': mode}
                env.pop('TEST_PACKAGE', None)
                for phase in ('boot', 'final'):
                    if phase == 'final' and mode.endswith('-no-suite'):
                        (root / 'memory-footprint/board/suite').unlink()
                    result = subprocess.run(['sh', str(HOOK), phase], cwd=root, env=env,
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                args = json.loads((root / 'args.json').read_text())
                self.assertEqual('--baseline-boot' in args, mode == 'mr')
                if mode in ('missing', 'upload-error', 'report-error'):
                    self.assertIn('WARNING', result.stderr)
                log = root / 'requests.jsonl'
                if mode.endswith('-no-suite'):
                    self.assertNotIn('--metrics-label', args)
                    self.assertEqual(result.stderr.count('WARNING'), 1)
                    self.assertIn('missing boot suite identity', result.stderr)
                if mode in ('report-error', 'push', 'mr-no-suite', 'weekly-no-suite'):
                    self.assertFalse(log.exists())
                elif mode == 'weekly':
                    requests = [json.loads(line) for line in log.read_text().splitlines()]
                    self.assertEqual(len(requests), 3)
                    self.assertTrue(all('JOB-TOKEN: test-token' in request for request in requests))
                    self.assertTrue(requests[-1][-1].endswith('/200/board-full-summary.json'))


if __name__ == '__main__':
    unittest.main()
