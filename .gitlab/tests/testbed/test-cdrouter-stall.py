#!/usr/bin/env python3
"""Check the optional test stall guard offline with a mocked CDRouter API.

Run with the testbed image's Python dependencies installed:
    python3 .gitlab/tests/testbed/test-cdrouter-stall.py
"""

import importlib.util
import io
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/testbed-cdrouter.py"
SPEC = importlib.util.spec_from_file_location("testbed_cdrouter_stall", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class StallTests(unittest.TestCase):
    def run_package(
        self, descriptions, ticks, *, stall_timeout=10, timeout=None,
        stopped=False, result_status="completed", failed=0, progress=True,
    ):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(root_dir=directory)
            if stall_timeout is not None:
                args.stall_timeout = stall_timeout
            if timeout is not None:
                args.timeout = timeout
            runner = MODULE.TestbedCDRouter(args)
            runner.connect = Mock()
            runner.job_launch = Mock()
            runner.package_stop = Mock()
            runner.job = SimpleNamespace(id=11, result_id=22)
            runner.job_total = 3
            runner.cdr = Mock()
            running_job = SimpleNamespace(status="running", result_id=22)
            completed_job = SimpleNamespace(status="completed", result_id=22)
            runner.cdr.jobs.get.side_effect = (
                [running_job] * len(descriptions) + [completed_job]
            )
            runner.cdr.results.updates.side_effect = [
                SimpleNamespace(
                    running=(SimpleNamespace(description=name) if name else None),
                    progress=(
                        SimpleNamespace(progress=10, finished=0) if progress else None
                    ),
                )
                for name in descriptions
            ]
            runner.cdr.results.get.return_value = SimpleNamespace(
                id=22, status=result_status, fail=failed, passed=3, tests=3 + failed,
                duration=30,
            )
            runner.cdr.tests.iter_list.return_value = [
                SimpleNamespace(description="failed test", result="fail")
            ]
            archive = Path(directory) / "result-logdir.tgz"
            runner.cdr.results.download_logdir_archive.return_value = (
                io.BytesIO(b"mock logdir archive"), str(archive)
            )

            def get_result(result_id):
                self.assertEqual(result_id, 22)
                self.assertEqual(runner.package_stop.call_count, int(stopped))
                return runner.cdr.results.get.return_value

            runner.cdr.results.get.side_effect = get_result
            with patch.object(MODULE.time, "monotonic", side_effect=ticks) as clock, \
                    patch.object(MODULE.time, "sleep"), \
                    patch.object(MODULE.logging, "info"), \
                    patch.object(MODULE.logging, "error") as error:
                with self.assertRaises(SystemExit) as exit_status:
                    runner.package_run()
                expected = 86 if stopped else int(failed > 0 or result_status != "completed")
                self.assertEqual(exit_status.exception.code, expected)
                messages = [call.args[0] for call in error.call_args_list]
                if stopped:
                    self.assertIn("stall stop: test test A ran 11 s, limit 10 s", messages)
                    runner.package_stop.assert_called_once_with()
                else:
                    runner.package_stop.assert_not_called()
                    self.assertFalse(any("stall stop:" in message for message in messages))
                self.assertFalse(any("test cutoff reached" in message for message in messages))
                if stall_timeout is None or stall_timeout == 0:
                    clock.assert_not_called()

            self.assertEqual(archive.read_bytes(), b"mock logdir archive")
            runner.cdr.results.download_logdir_archive.assert_called_once_with(22, format="tgz")
            for call in runner.cdr.results.updates.call_args_list:
                self.assertEqual(call.args, (22,))
                self.assertEqual(call.kwargs, {})

    def test_stall_stops_before_result_collection_and_exits_86(self):
        for result_status, failed in (("stopped", 0), ("stopped", 1), ("completed", 0)):
            with self.subTest(result_status=result_status, failed=failed):
                self.run_package(
                    ["test A", "test A"], [0, 11], stopped=True,
                    result_status=result_status, failed=failed,
                )

    def test_normal_test_does_not_stop(self):
        self.run_package(["test A", "test A"], [0, 9])

    def test_equal_limit_does_not_stop(self):
        self.run_package(["test A", "test A"], [0, 10])

    def test_description_change_resets_timer(self):
        self.run_package(["test A", "test A", "test B", "test B"], [0, 6, 11, 17])

    def test_no_running_test_resets_timer(self):
        self.run_package(["test A", None, "test A", "test A"], [0, 100, 106])

    def test_missing_progress_does_not_disable_guard(self):
        self.run_package(["test A", "test A"], [0, 11], stopped=True, progress=False)

    def test_missing_or_zero_limits_leave_guard_off(self):
        for stall_timeout in (None, 0):
            for timeout in (None, 0):
                with self.subTest(stall_timeout=stall_timeout, timeout=timeout):
                    self.run_package(
                        ["test A", "test A"], [],
                        stall_timeout=stall_timeout, timeout=timeout,
                    )

    def test_cli_default_and_explicit_limits(self):
        for options, stall_timeout, timeout in (
            ([], 0, None),
            (["--stall-timeout", "0", "--timeout", "0"], 0, 0),
            (["--stall-timeout", "10"], 10, None),
        ):
            with self.subTest(options=options), \
                    patch.object(MODULE.sys, "argv", [str(SCRIPT), "package_run", "suite"] + options), \
                    patch.object(MODULE.TestbedCDRouter, "package_run") as run:
                MODULE.main()
                runner = run.call_args.args[0]
                self.assertEqual(runner.args.stall_timeout, stall_timeout)
                self.assertEqual(runner.args.timeout, timeout)

    def test_limits_are_not_forwarded_to_launch_api(self):
        for timeout, stall_timeout in ((None, 0), (0, 0), (120, 10)):
            with self.subTest(timeout=timeout, stall_timeout=stall_timeout):
                args = SimpleNamespace(
                    root_dir=".", package_name="suite", configuration=None,
                    device=None, system_info=None, tags=None,
                    timeout=timeout, stall_timeout=stall_timeout,
                )
                runner = MODULE.TestbedCDRouter(args)
                runner.cdr = Mock()
                runner.cdr.packages.get_by_name.return_value = SimpleNamespace(
                    id=1, name="suite", test_count=3
                )
                runner.cdr.packages.get.return_value = runner.cdr.packages.get_by_name.return_value
                runner.cdr.configs.get_by_name.return_value = None
                runner.cdr.devices.get_by_name.return_value = None
                runner.cdr.packages.analyze.return_value = SimpleNamespace(
                    run_count=3, skipped_count=0, skipped_tests=[]
                )
                runner.cdr.jobs.launch.return_value = SimpleNamespace(id=11, result_id=22)
                with patch.object(MODULE, "Options") as options, \
                        patch.object(MODULE, "Job") as job, \
                        patch.object(MODULE.GitLabEnvironment, "as_tags", return_value=None):
                    runner.job_launch()
                options.assert_called_once_with(tags=[])
                job.assert_called_once_with(package_id=1, options=options.return_value)
                runner.cdr.jobs.launch.assert_called_once_with(job.return_value)


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(StallTests)
    )
    if result.wasSuccessful():
        print("PASS: CDRouter stall stop, normal progress, disabled limits and launch API")
    sys.exit(not result.wasSuccessful())
