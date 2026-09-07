"""Scratch paths must stay outside the recipe cwd and be cleaned on exit."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1]/'gen-secure-initramfs.sh'


class ScratchTests(unittest.TestCase):
    def test_scratch_path_and_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            cwd = base/'feeds/vendor/image'
            cwd.mkdir(parents=True)
            output = base/'build dir'
            output.mkdir()
            inputs = base/'inputs'
            (inputs/'initramfs-files').mkdir(parents=True)
            (inputs/'initramfs-files/init').write_text('init fixture\n')
            (inputs/'initramfs-files-list.txt').write_text('')
            rootfs = base/'rootfs'
            (rootfs/'lib').mkdir(parents=True)
            mockbin = base/'bin'
            mockbin.mkdir()
            # Observe the packaging cwd and payload without needing host cpio.
            cpio = mockbin/'cpio'
            cpio.write_text('#!/bin/sh\npwd -P > "$SCRATCH_LOG"\ncat init\n')
            cpio.chmod(0o755)
            env = {**os.environ, 'PATH': str(mockbin)+':'+os.environ['PATH'],
                   'SCRATCH_LOG': str(base/'scratch'), 'UNSTRIPPED_FOLDER': str(rootfs),
                   'BINARIES_PATH': '/bin'}
            for relative in (False, True):
                with self.subTest(relative=relative):
                    dest = output/'image.cpio'
                    result = subprocess.run(['bash', str(SCRIPT), 'build', 'NONE',
                        os.path.relpath(dest, cwd) if relative else str(dest), str(inputs), str(rootfs)],
                        cwd=cwd, env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(dest.read_text(), 'init fixture\n')
                    scratch = Path((base/'scratch').read_text().strip())
                    self.assertTrue(scratch.is_absolute())
                    self.assertEqual(scratch.parent, output)
                    self.assertFalse(scratch.exists())
                    self.assertEqual(list(cwd.iterdir()), [])
                    self.assertEqual(list(output.glob('initramfs.tmp.*')), [])
            # Missing required input exits from import_file; EXIT still cleans.
            (inputs/'initramfs-files-list.txt').write_text('/missing\n')
            result = subprocess.run(['bash', str(SCRIPT), 'build', 'NONE', str(output/'failed'),
                str(inputs), str(rootfs)], cwd=cwd, env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(output.glob('initramfs.tmp.*')), [])
            self.assertEqual(list(cwd.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
