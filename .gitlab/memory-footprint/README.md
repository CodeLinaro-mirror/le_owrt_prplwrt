# Weekly memory baselines

The DUT hook saves the boot suite identity for use in after_script. Cram
uses COMPONENT (including runtime auto-selection); CDRouter uses
TEST_PACKAGE. New mem-report options are probed with --help until the
container ships them. Missing options, snapshots, baselines, credentials
and failed transfers produce warnings and do not change the DUT job result.

If the saved suite identity is missing at final capture, the hook still
produces the boot-to-final reports, omitting the suite label, baseline fetch
and weekly upload with a warning.

Weekly branches have the form ci-weekly/<base branch>/YYYY-MM-DD, as created
by the n8n weekly CI commits. Only those branch pipelines upload baselines:

- Package: memory-footprint-<encoded base branch>.
- Version: CI_PIPELINE_ID.
- Files: <board>-<suite>-boot.txt.gz, <board>-<suite>-final.txt.gz and
  <board>-<suite>-summary.json.

Each key preserves ASCII letters, digits, dots and hyphens; other UTF-8
bytes become _hh, including underscores. For example, CDRouter-Top-100+mDNS
becomes CDRouter-Top-100_2bmDNS. This avoids lossy slug collisions. Summary
names include board and suite because all jobs share one package version.

MR pipelines use CI_JOB_TOKEN to fetch the target project's newest numeric
version for the exact target-branch package. Both matching snapshots must
be present and decompress successfully before mem-report receives baseline
arguments. Missing pairs produce absolute metrics with a warning; no older
version or different suite is silently substituted. Full metrics remain
in ordinary artifacts; widget.prom contains the compact report.

The weekly .post job keeps 12 distinct numeric versions for that base
branch package. It fetches all pages before deleting older packages and
serializes cleanup jobs. Configure MEMORY_FOOTPRINT_API_TOKEN as a masked,
protected project access token with api scope and package deletion rights
(Maintainer role). Protected ci-weekly/* branches are needed to expose that
variable. No token is provisioned by this change. MR jobs need no API token.
See the [Packages API](https://docs.gitlab.com/api/packages/) and
[generic registry authentication](https://docs.gitlab.com/user/packages/generic_packages/).

Deployment considerations:

- Re-point all five testbed image pins at release, including the cleanup
  job in `.gitlab/testbed.yml`.

- Board and suite are the agreed identity. Existing CDRouter jobs with the
  same board/package but different VLAN or PPPoE configurations share keys;
  job retries also reuse filenames. Those jobs can replace the effective
  baseline files depending on registry duplicate settings. A future identity
  extension requires a naming decision before relying on configuration deltas.
- Only suites and boards actually run by the weekly pipeline have baselines.
  Current weekly overrides primarily select full cram and selected CDRouter
  jobs, so component-specific MR suites can legitimately have no baseline.
- Fork MR tokens must be allowed to read the target project's registry.
  Verify job-token access and duplicate-file policy during live CI rollout.
