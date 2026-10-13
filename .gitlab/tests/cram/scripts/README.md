# OBUSPA Test Scripts

This directory contains shared helper scripts used by cram tests.

## `verify-obuspa-datamodel.sh`

[`verify-obuspa-datamodel.sh`](./verify-obuspa-datamodel.sh) verifies
the generic and cellular OBUSPA datamodel fixtures used by:

- [`../generic/obuspa.t`](../generic/obuspa.t)
- [`../generic/obuspa-cellular.t`](../generic/obuspa-cellular.t)

The helper uploads
[`target/obuspa-datamodel-dump.sh`](./target/obuspa-datamodel-dump.sh)
to the DUT, captures the filtered datamodel on the DUT itself, copies
the snapshot back to the host, and runs the comparison locally.

It supports two calling patterns:

1. Single snapshot verification

   ```sh
   sh verify-obuspa-datamodel.sh \
     --mode generic \
     --expected path/to/obuspa.expected \
     --actual path/to/obuspa.actual \
     --diff path/to/obuspa.diff
   ```

2. Before/after restart verification

   ```sh
   sh verify-obuspa-datamodel.sh \
     --mode generic \
     --expected path/to/obuspa.expected \
     --before-actual path/to/obuspa.before-restart.actual \
     --before-diff path/to/obuspa.before-restart.diff \
     --after-actual path/to/obuspa.after-restart.actual \
     --after-diff path/to/obuspa.after-restart.diff
   ```

Before the first capture, the helper waits for
`DeviceInfo.DeviceStatus` to become `Up` (end of boot). USP Services
register asynchronously with obuspa, so each snapshot is then captured
and compared again until it matches the expected fixture or the timeout
expires. Only the last mismatching snapshot and diff are saved.

In restart mode the helper:

1. captures and verifies the `before` snapshot,
2. runs `service obuspa restart` on the DUT,
3. captures and verifies the `after` snapshot, with the same retry
   mechanism.

When a snapshot still mismatches at the end of the timeout, the helper
uploads [`target/obuspa-diagnostics.sh`](./target/obuspa-diagnostics.sh)
and saves its output next to the actual snapshot, with a `.diag`
extension (e.g. `obuspa.before-restart.diag`). The USP Services owning
the missing or unexpected elements (`proto::...` in the diff) are passed
to it, and for each of them it collects the process status, its
registration in `Device.USPServices.USPService.`, the obuspa plugin
trace (`/tmp/obuspa_plugin_trace.log`), a manual GSDM and the related
syslog. ProcessMonitor, process faults and obuspa logs are also
collected. The `.diag` files are kept as CI artifacts.

The timeouts can be tuned with environment variables:

- `OBUSPA_DEVICE_UP_TIMEOUT` (default `180` seconds)
- `OBUSPA_DATAMODEL_TIMEOUT` (default `90` seconds, per snapshot)
- `OBUSPA_RETRY_INTERVAL` (default `5` seconds)

## Environment

The helper expects the same transport variables used by the cram tests:

- `CRAM_REMOTE_COMMAND` for remote shell access
- `CRAM_REMOTE_COPY` for file copies
- `TARGET_LAN_IP` if the host cannot be derived from
  `CRAM_REMOTE_COMMAND`

`CRAM_REMOTE_COPY` defaults to `scp` when it is unset.

For local testing against Dropbear with newer OpenSSH clients, override
the copy command explicitly, for example:

```sh
export CRAM_REMOTE_COPY='scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR'
```

On mismatches the helper prints the unified diff, saves the captured
snapshot as `*.actual`, and saves the diff as `*.diff`.
