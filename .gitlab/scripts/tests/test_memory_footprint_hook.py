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


if __name__ == '__main__':
    unittest.main()
