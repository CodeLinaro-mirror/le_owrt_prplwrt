# Content

This directory contains files used mainly during testing on the GitLab CI.

## requirements.txt

This `requirements.txt` file is used for specifying what Python packages are required to run the scripts in this directory. Usually used with `pip install -f requirements.txt` command.

## prpl-jira.py

This helper Python script creates new or updates existing Jira ticket when something goes wrong during GitLab CI testing process. Currently only supports reporting of build test failures.

**Needs** Python version **3.6+** due to use of f-strings feature.

## testbed-device.py

This helper Python scripts allows managing of device under test (DUT) via labgrid framework.

## CDRouter reports

The testbed image supplies `cdrouter-ci` from version `vX.Y.Z`.
The CDRouter job runs
`cdrouter-ci report cdrouter-results/` after it extracts the result archive.
The command reads local logs, including partial runs without `final.txt`.
It prints failure messages, preceding log lines, and file names with line
numbers. It writes `cdrouter-junit.xml`, `failure-digest.md`, and
`failure-digest.json` in the job directory. GitLab collects the JUnit report
and keeps the logs and digests as artifacts, including `final.txt` when present.
