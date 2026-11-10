#!/usr/bin/env python3
"""Check CDRouter exit codes offline with a mocked API.

Run with the testbed image's Python dependencies installed:
    python3 .gitlab/tests/testbed/test-cdrouter.py
"""

import importlib.util
import io
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/testbed-cdrouter.py"
SPEC = importlib.util.spec_from_file_location("testbed_cdrouter", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class PackageRunTests(unittest.TestCase):
    def check_result(self, status, failed, cutoff, expected):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "result-logdir.tgz"
            payload = b"mock logdir archive"
            args = SimpleNamespace(root_dir=directory, timeout=120)
            runner = MODULE.TestbedCDRouter(args)
            runner.connect = Mock()
            runner.job_launch = Mock()
            runner.package_stop = Mock()
            runner.job = SimpleNamespace(id=11, result_id=22)
            runner.cdr = Mock()
            runner.cdr.jobs.get.return_value = SimpleNamespace(
                status="running" if cutoff else "completed", result_id=22
            )
            runner.cdr.results.get.return_value = SimpleNamespace(
                id=22, status=status, fail=failed, passed=3, tests=3 + failed,
                duration=120,
            )
            runner.cdr.results.download_logdir_archive.return_value = (
                io.BytesIO(payload), str(archive)
            )
            runner.cdr.tests.iter_list.return_value = [
                SimpleNamespace(description="failed test", result="fail")
            ]

            # The cutoff must stop the package before fetching its result.
            def get_result(result_id):
                self.assertEqual(result_id, 22)
                self.assertEqual(runner.package_stop.call_count, int(cutoff))
                return runner.cdr.results.get.return_value

            runner.cdr.results.get.side_effect = get_result
            with patch.object(MODULE.time, "sleep") as sleep, \
                    patch.object(MODULE.logging, "error") as error:
                # Use the real polling cutoff logic without waiting 120 seconds.
                with patch.object(MODULE.time, "time", side_effect=[0, 120, 120]):
                    with self.assertRaises(SystemExit) as exit_status:
                        runner.package_run()
                self.assertEqual(exit_status.exception.code, expected)
                self.assertEqual(archive.read_bytes(), payload)
                runner.cdr.results.download_logdir_archive.assert_called_once_with(
                    22, format="tgz"
                )
                sleep.assert_not_called()
                messages = [call.args[0] for call in error.call_args_list]
                self.assertEqual(
                    "test cutoff reached after 120 s" in messages, cutoff
                )
            runner.connect.assert_called_once_with()
            runner.job_launch.assert_called_once_with()

    def test_completed_success_exits_zero(self):
        self.check_result("completed", 0, False, 0)

    def test_completed_failure_exits_one(self):
        self.check_result("completed", 1, False, 1)

    def test_incomplete_without_failed_tests_exits_one(self):
        self.check_result("stopped", 0, False, 1)

    def test_cutoff_without_failed_tests_exits_86(self):
        self.check_result("stopped", 0, True, 86)

    def test_cutoff_with_failed_tests_exits_86(self):
        self.check_result("stopped", 1, True, 86)

    def test_cutoff_overrides_completed_result(self):
        self.check_result("completed", 0, True, 86)


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(PackageRunTests)
    )
    if result.wasSuccessful():
        print("PASS: CDRouter success, failure, cutoff and logdir download paths")
    sys.exit(not result.wasSuccessful())
