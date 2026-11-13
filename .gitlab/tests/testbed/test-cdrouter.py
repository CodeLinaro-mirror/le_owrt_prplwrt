#!/usr/bin/env python3
"""Check CDRouter exit codes offline with a mocked API.

Run with the testbed image's Python dependencies installed:
    python3 .gitlab/tests/testbed/test-cdrouter.py
"""

import importlib.util
import io
import os
import subprocess
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
                    "The time budget for the tests ended after 2 min. Stopping the package." in messages, cutoff
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


    def test_duration_words(self):
        for seconds, expected in (
            (0, "0 s"), (42, "42 s"), (60, "1 min"),
            (252, "4 min 12 s"), (3720, "1 h 2 min"),
        ):
            with self.subTest(seconds=seconds):
                self.assertEqual(MODULE.format_duration(seconds), expected)

    def test_job_templates_preserve_status_and_show_visible_stop_reason(self):
        # Execute the actual YAML script tail with local command stubs. Nothing
        # connects to a device or API, and the timeout statuses are deterministic.
        import yaml

        root = SCRIPT.parents[2]
        helpers = SCRIPT.with_name("helpers.sh")
        for template, key in (("cdrouter", ".cdrouter"), ("testbed", ".testbed")):
            config = yaml.load((root / f".gitlab/{template}.yml").read_text(), Loader=yaml.BaseLoader)[key]
            commands = config["script"]
            script = "\n".join(commands[commands.index("test_budget"):])
            run_check = ""
            if template == "testbed":
                run_check = next(c for c in config["before_script"] if isinstance(c, str) and "run_check()" in c)
            for status, reason, left, post_status, expected in (
                (0, "", 2678, 0, 0), (1, "", 2678, 0, 1),
                (86, "cutoff", 2678, 0, 86), (86, "hung-test", 2678, 0, 86),
                (124, "", 2678, 0, 86), (137, "", 2678, 0, 86),
                (137, "", 2678, 0, 137),
                (124, "hung-test", 2678, 0, 86),
                (0, "", 119, 0, 86), (0, "", -1, 0, 86),
                (0, "", 120, 0, 0), (0, "", 2678, 1, 1),
                (0, "", 2678, 124, 1),
                (124, "", 2678, 1, 86),
            ):
                if template == "testbed" and (status == 86 or reason == "hung-test"):
                    continue  # cram has only suite timeouts, reported as 124 or 137.
                if template == "cdrouter" and post_status == 124:
                    continue  # The post-suite timeout message is specific to cram.
                at_limit = status == 137 and expected == 86
                if template == "testbed" and expected == 137:
                    expected = 1  # The cram wrapper maps an ordinary failure to 1.
                with self.subTest(template=template, status=status, reason=reason, left=left, post=post_status,
                                  at_limit=at_limit), \
                        tempfile.TemporaryDirectory() as directory:
                    env = dict(os.environ, CI_PROJECT_DIR=directory, CI_JOB_ID="123",
                               CI_JOB_STARTED_AT="1970-01-01T00:10:18Z", CI_JOB_TIMEOUT=str(1042 + left),
                               TEST_TEARDOWN_RESERVE="660", TEST_PACKAGE="suite", CDROUTER_TEST_CONFIG="generic",
                               LABGRID_TARGET="generic", CRAM_TEST_SUITE="suite.t", CRAM_TEST_SUITE_EXTRA="",
                               CRAM_TEST_SUITE_POST="post.t", TARGET_LAN_IP="unused", COMPONENT="",
                               TEST_STATUS=str(status), STOP_REASON=reason, POST_STATUS=str(post_status),
                               AT_LIMIT=str(int(at_limit)))
                    stubs = r'''
source "$1"
date() { if [ "$*" = '+%s' ]; then echo 1000; else command date "$@"; fi; }
sudo() { :; }
ssh() { :; }
sleep() { :; }
setup_step() { :; }
timeout() {
  case "$*" in
    *testbed-cdrouter.py*|*suite.t*)
      echo 'MOCK TESTS STARTED'
      [ -z "$STOP_REASON" ] || write_outcome "$STOP_REASON"
      if [ "$AT_LIMIT" -eq 1 ]; then
        case "$2" in
          --verbose) SECONDS=$((SECONDS + ${3%s})) ;;
          *) SECONDS=$((SECONDS + $2)) ;;
        esac
      fi
      return "$TEST_STATUS" ;;
    *) return "$POST_STATUS" ;;
  esac
}
touch .run_failed
'''
                    result = subprocess.run(["bash", "-eo", "pipefail", "-c", stubs + run_check + "\n" + script,
                                             "bash", str(helpers)], cwd=directory, env=env,
                                            text=True, capture_output=True)
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    outcome = (Path(directory) / ".ci-job-state/123/outcome").read_text().strip()
                    expected_outcome = "passed" if expected == 0 else "tests-failed"
                    if expected == 86:
                        expected_outcome = "hung-test" if reason == "hung-test" else "cutoff"
                    self.assertEqual(outcome, expected_outcome)
                    if post_status == 124:
                        self.assertIn("Post suite stopped at its time limit of 1 min 30 s.", result.stdout)
                    self.assertIn("⏳ Time budget: the job may run", result.stdout)
                    if left == 2678:
                        self.assertIn("1 h 2 min. 6 min 22 s have passed and 11 min are kept", result.stdout)
                        self.assertIn("tests may run 44 min 38 s (until 01:01 UTC).", result.stdout)
                    self.assertEqual("MOCK TESTS STARTED" in result.stdout, left >= 120)
                    if left >= 120:
                        self.assertIn("🧪 Test Execution", result.stdout)
                    meaning = "❌ ERROR: The job fails with exit code 86, which means a time limit was reached."
                    self.assertEqual(result.stdout.count(meaning), int(expected == 86))
                    if expected == 86:
                        stop = "🛑 Tests stopped on purpose: " + (
                            "one test did not finish." if expected_outcome == "hung-test" else "the time budget ended."
                        )
                        self.assertEqual(result.stdout.count(stop), 1)
                        self.assertIn("💡 Results up to this point are kept. Teardown and artifact upload follow.", result.stdout)
                        if left >= 120:
                            self.assertLess(result.stdout.index("section_end:"), result.stdout.index(stop))
                        self.assertNotIn("rc=", result.stdout)
                    duration = (Path(directory) / ".ci-job-state/123/duration-tests").read_text().strip()
                    self.assertTrue(duration.isdigit())
                    if left < 120:
                        self.assertEqual(duration, "0")


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(PackageRunTests)
    )
    if result.wasSuccessful():
        print("PASS: CDRouter success, failure, cutoff and logdir download paths")
    sys.exit(not result.wasSuccessful())
