# Process privileges

This directory contains the tooling that verifies which user, group and
capabilities every process runs with on the DUT, and this document explains how
to make a plugin run as a non-root user.

- [`rules.yml`](./rules.yml) describes the expected process tree.
- [`verify.py`](./verify.py) copies
  [`target/process-privileges.lua`](./target/process-privileges.lua) to the DUT,
  runs it there, and compares the collected tree against `rules.yml`.
- [`test/`](./test) holds cram tests for `verify.py`. They need no DUT:
  [`test/fake-dut.sh`](./test/fake-dut.sh) stands in for `ssh` and `scp` and
  serves canned process lists. Run them with `python3 -m cram test`.

## How it works at runtime

A plugin does not drop its own privileges. `amxrt` does it, from the
`privileges` section of the plugin ODL configuration:

```odl
%config {
    %global privileges = {
        user = "tr181_app", group = "tr181_app",
        capabilities = [
            "CAP_DAC_OVERRIDE"
        ]
    };
}
```

`amxrt_caps_apply()` clears the capability set, adds the requested
capabilities, and switches user and group. It runs *before* the data model is
registered and before the entry points are invoked, so the plugin is already
unprivileged by the time its own code starts.

## Making a plugin run as non-root

All of the following happens in the component repository. `tr181-usb` is used
here as the worked example; replace the names accordingly.

### 1. Add the configuration options

In `baf.yml`:

```yaml
  CONFIG_AMX_TR181_USB_RUN_AS_USER:
    depends_on:
      - CONFIG_AMX_TR181_USB
    default: "tr181_app"
    type: string
    description: "User will be used for the tr181-usb plugin"
  CONFIG_AMX_TR181_USB_RUN_AS_GROUP:
    depends_on:
      - CONFIG_AMX_TR181_USB
    default: "tr181_app"
    type: string
    description: "Group will be used for the tr181-usb plugin"
```

### 2. Add the capabilities template

Create `odl/<component>_caps.odl.m4`. `USER_ID` and `GROUP_ID` are placeholders
substituted at build time:

```odl
%config {
    %global privileges = {
        user = "USER_ID", group = "GROUP_ID",
        capabilities = [
            "CAP_DAC_OVERRIDE"
        ]
    };
}
```

### 3. Generate it

In `odl/Makefile`, defaulting to `root` keeps a build that does not set the
options working:

```make
ifeq ($(strip $(CONFIG_AMX_TR181_USB_RUN_AS_USER)),)
    CONFIG_AMX_TR181_USB_RUN_AS_USER := "root"
endif

all:
	m4 -D USER_ID=$(CONFIG_AMX_TR181_USB_RUN_AS_USER) \
	   -D GROUP_ID=$(CONFIG_AMX_TR181_USB_RUN_AS_GROUP) \
	   tr181-usb_caps.odl.m4 > tr181-usb_caps.odl
```

Add the `odl` directory to the `build` and `clean` lists in `baf.yml`, and
install the generated file:

```yaml
  - source: "odl/$(COMPONENT)_caps.odl"
    destination: "/etc/amx/$(COMPONENT)/$(COMPONENT)_caps.odl"
    permissions: "0644"
```

### 4. Include it

At the end of the main ODL file, after the definition file:

```odl
#include "${name}_caps.odl";
```

Include it last. A `privileges` section replaces the previous one as a whole
rather than merging key by key, so whichever one is parsed last wins.

Remove any pre-existing `privileges = { keep-all = true }` from the main ODL
file. `keep-all` and `capabilities` are mutually exclusive: with `keep-all` set,
the capability set is never cleared and the requested capabilities are never
added, so the plugin switches user but keeps every root capability.

## Choosing capabilities

Start with an empty list and add only what the plugin is proven to need. A few
properties of the implementation are worth knowing.

- Names are case insensitive and the `CAP_` prefix is optional, so
  `CAP_NET_ADMIN` and `net_admin` both work.
- An **unknown capability name is ignored**. It is logged, but startup
  continues, so a typo silently grants nothing. The cram test below is what
  catches it.
- An unknown **user or group** name is not ignored: `amxrt` refuses to start.
- `amxrt` adds capabilities to the effective, permitted, bounding and
  inheritable sets of the plugin, never to its **ambient** set. What a child
  process gets depends on how the plugin starts it, see below.
- Supplementary groups are dropped when the user is switched, and there is no
  option to keep or add any.

## What capabilities do not solve

Only capabilities in the **ambient** set survive an `execve()` into a program
without file capabilities. What a helper the plugin runs (a binary, a shell
script, a hotplug handler) ends up with therefore depends on how it is started:

| started with | capabilities of the child | example |
| --- | --- | --- |
| `amxp_subproc_start()` and friends | **all** capabilities of the plugin: libamxp raises every inheritable capability into the ambient set of the child before the exec | `tr181-dynamicdns > sh dynamic_dns_updater.sh` has `chown,dac_override,dac_read_search` |
| `popen()`, `system()`, plain `fork()` + `exec()` | none, unless the plugin raised some into its own ambient set first | `tr181-sfp` raises only `CAP_NET_ADMIN` around its EEPROM reads, so `tr181-sfp > sh get_eeprom_info.sh` has `net_admin` |

Whatever a child inherits, it passes on to its own children in the same way,
for as long as none of them is setuid or carries file capabilities. The child
always runs as the plugin user.

Two consequences bite in practice for a child that runs without capabilities:

- Every helper the plugin executes, and every script in the chain it triggers,
  must be executable by the plugin user. Install them `0755`. A helper
  installed `0766` or `0700` works for as long as the plugin is root and fails
  with `EACCES` the moment it is not.
- Files the helper reads or writes must be reachable by the plugin user too.
  `CAP_DAC_OVERRIDE` on the plugin does not help a child process.

This is not hypothetical. `tr181-usb` populates `Device.USB.` by running
`trigger-usb-events`, which calls `hotplug-call`, which runs `event2usb`.
`event2usb` was installed `0766`, which grants execute permission to the owner
only. As root it worked; as `tr181_app` the exec failed and the whole
`USB.USBHosts.` tree stayed empty, with no error anywhere in the data model.

When a plugin misbehaves only after being switched to non-root, look for a
denied access before looking for a missing capability.

## Declaring the expected privileges

Add the plugin to [`rules.yml`](./rules.yml), under the parent process that
starts it, keyed by the process name as it appears on the DUT:

```yaml
  tr181-usb:
    id: tr181_app:tr181_app
    caps: dac_override
```

| field | meaning |
| --- | --- |
| `id` | expected `user:group` |
| `caps` | expected capabilities |
| `child` | expected child processes, same fields, nested. See below for how they are matched |
| `optional` | the process may be absent |
| `ignore_child` | do not check the children of this process |

`caps` is a comma separated list of lowercase names without the `CAP_` prefix,
so `CAP_DAC_OVERRIDE` in the ODL becomes `dac_override` here. Two values are
special: `full` for a process that keeps every capability, and `none` for a
process that has none.

Mark an entry `optional` when the process only exists on some boards or only
under some conditions. A required entry that is missing fails the test on every
board.

### How children are matched

Every entry under `child` is either matched by its process name, or, if it has
a `match` field, by the fields listed in `match`:

```yaml
  tr181-sfp:
    id: tr181_app:tr181_app
    caps: dac_override,net_admin
    child:
      tr181-usb:                    # no match: the key is the process name
        id: tr181_app:tr181_app
        caps: dac_override
      sfp-eeprom-script:            # match: the key is only an id
        match:
          name: sh
          cmd: "~/lib/sfp/get_eeprom_info\\.sh "
        id: tr181_app:tr181_app
        caps: net_admin
        optional: true
        ignore_child: true
```

A process can run several children with the same name but different
privileges, such as two shell scripts. Give each one its own `match`.

- `match` names one or more of `name`, `id`, `exe`, `cwd` and `cmd`. `cmd` is
  the whole command line. All fields must match.
- A value is compared for equality, unless it starts with `~`. Then the rest is
  a regular expression, searched for anywhere in the field. Quote values that
  contain YAML special characters, and escape backslashes.
- A child that matches two entries is an error, `matches more than one rule`.
  Nothing is picked by order.
- Reports name a matched rule by its id, e.g. `sh[sfp-eeprom-script]`, and a
  missing one as `missing required child process 'sfp-eeprom-script (name=sh,
  cmd=~...)'`.
- An entry with `match` takes the same fields as any other entry, and may nest
  `child` itself.

### Several rules files

`verify.py` takes one or more rules files, and merges them in the order given,
so later files override earlier ones. This is how a board adds or removes rules
without copying `rules.yml`:

```sh
python3 verify.py rules.yml board-rules.yml
```

- Maps merge key by key. Any other value replaces the earlier one.
- A `null` value deletes the key from the merged rules. For example
  `sfp-oper-state-script: null` removes that rule for the board. A `null` for a
  key that no earlier file defines adds an empty entry.
- A key that is repeated within one file is an error. A YAML parser would
  otherwise keep only the last one.

### Profiles

Rules that depend on the situation, such as the board or whether it has a
modem, go in `profiles/`. [`profiles/profiles.yml`](./profiles/profiles.yml)
lists which files load, and under which conditions:

```yaml
version: 1
defaults:                       # used when the environment does not set the variable
  DUT_HAS_MODEM: "1"
profiles:                       # loaded in this order, each merged over the previous
  - file: has_modem.yml
    when:
      DUT_HAS_MODEM: "1"
  - file: "${DUT_BOARD}.yml"    # ${VAR} is expanded in the file name
    optional: true
  - file: wan_ppp.yml
    when:
      DUT_WAN_INTERFACE: "~^ppp"
    optional: true
```

- `when` lists variables that must all match. A value is compared for equality,
  or is a regular expression with `~`. A list accepts any of its values. Write
  values as strings: an unquoted `true` is an error, so it can't silently never
  match.
- A variable counts as set when it is non-empty in the environment, or in
  `defaults`. The environment wins over `defaults`.
- A profile whose `when` does not match, or whose file name uses an unset
  variable, is skipped. A profile whose file is missing is an error, unless it is
  `optional`.
- A file name must stay inside `profiles/`. Names with `/` or `..` are an error.
- Profiles are applied after the rules files given on the command line, so a
  profile overrides them.
- `--list-profiles` prints to stderr which profiles load and why the others are
  skipped. `--no-profiles` applies none. `--profiles-dir` selects another
  directory.

Finally, add the two configuration options to the board fixtures in
`.gitlab/tests/cram/<board>/005-build-config.t`, for every board that selects
the component:

```
  CONFIG_AMX_TR181_USB_RUN_AS_GROUP="tr181_app"
  CONFIG_AMX_TR181_USB_RUN_AS_USER="tr181_app"
```

## Verifying

Three cram tests cover this:

- [`generic/acceleration-plan-components/002-processes-privileges.t`](../../generic/acceleration-plan-components/002-processes-privileges.t)
  compares the whole process tree against `rules.yml`, checks that the
  unprivileged user cannot escalate through `sudo`, and checks that `amxrt`
  refuses an unknown user or group.
- [`post/generic/45-process-privileges.t`](../../post/generic/45-process-privileges.t)
  compares the process tree again after every suite, to catch a privilege that
  a test left changed.
- [`post/generic/40-check-for-permissions-issues.t`](../../post/generic/40-check-for-permissions-issues.t)
  runs after every suite and greps the DUT log for `EPERM`, `EACCES` and
  refused `sudo` attempts. This is the one that catches the failures described
  above, so read its output even when it passes.

To run the privilege check against a DUT:

```sh
export CRAM_REMOTE_COMMAND="ssh root@192.168.1.1"
export CRAM_REMOTE_COPY="scp -O"
python3 verify.py
```

It prints `OK: All process privileges match expected configuration` when the
tree matches, and otherwise one line per problem:

| message | meaning |
| --- | --- |
| `missing required process 'x'` | in `rules.yml`, not on the DUT |
| `x: missing required child process 'y'` | parent found, child absent |
| `unexpected root process 'x' (id=..., caps=...)` | on the DUT, not in `rules.yml` |
| `x: unexpected child process 'y' (id=..., caps=...)` | undeclared child |
| `x: expected id 'a', got 'b'` | wrong user or group |
| `x: expected caps 'a', got 'b'` | wrong capabilities |

An unexpected child process is followed by its context, taken from the same
snapshot. Such a process is often short-lived and gone by the time anyone looks:

```
ERROR: procd > tr181-sfp: unexpected child process 'sh' (id=tr181_app:tr181_app, caps=none)
procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
   tr181-sfp (pid=500, id=tr181_app:tr181_app, caps=net_admin, exe=/usr/bin/amxrt, cwd=/)
      sh (pid=900, id=tr181_app:tr181_app, caps=net_admin, exe=/bin/busybox, cwd=/)
         - cmd: /bin/sh /lib/sfp/get_eeprom_info.sh sfp0
         ethtool (pid=901, id=tr181_app:tr181_app, caps=net_admin, exe=/usr/sbin/ethtool, cwd=/)
            - cmd: ethtool -m eth5 raw on
```

The ancestors are listed first, then the unexpected process and all its
descendants, each with its command line. The other errors are a single line.

### Transient processes

A single snapshot can catch the DUT in a transient state: a plugin running a
short-lived helper that is not in `rules.yml`, or a service that is restarting
and has not dropped its privileges yet. Give `verify.py` a timeout to collect
and verify again until the tree matches or the time runs out:

```sh
python3 verify.py --timeout 45 --interval 2
```

| option | environment | meaning |
| --- | --- | --- |
| `-t`, `--timeout <s>` | `VERIFY_TIMEOUT` | keep retrying for this many seconds (default `0`, a single attempt) |
| `-i`, `--interval <s>` | `VERIFY_INTERVAL` | seconds between attempts (default `2`) |
| `-v`, `--verbose` | | print the errors of every failed attempt to stderr, also when a later attempt succeeds |

On success it prints only the `OK` line. On timeout it prints the errors of the
last attempt, followed by
`ERROR: process privileges did not match after N attempts in Ns`. The cram
tests use `--timeout 45`.

A retry hides a problem that does not show up on every snapshot, such as a
helper that briefly runs as root with full capabilities. When a test passes
only after retrying, run `verify.py -v` to see what the earlier attempts
caught.

The collector is copied to the DUT once, run once per attempt, and removed at
the end.

### Collecting manually

To look at the process tree without verifying it, use `--collect`:

```sh
python3 verify.py --collect             # tree, children sorted by name
python3 verify.py --collect color       # same, root and full caps in red
python3 verify.py --collect list        # one line per process, with pid and ppid
```

Each `list` line is `pid ppid name user:group caps exe cwd cmdline`. Whitespace
in `name`, `exe` and `cwd` is escaped as octal (`\040`), an empty value is
`-`, and the command line takes up the rest of the line. Lists that stop after
`caps`, the older format, are still accepted.

The `list` output is what the verification consumes. Save it to verify it
later, or against modified rules, without touching the DUT again:

```sh
python3 verify.py --collect list > processes.txt
python3 verify.py --input processes.txt my-rules.yml
```

`--lua <binary>` selects the lua interpreter on the DUT (default `lua`).

### Transport

Both transport variables come from the environment, as described in
[`../README.md`](../README.md), and neither is a command line argument.
`TARGET_LAN_IP` names the DUT when it cannot be derived from
`CRAM_REMOTE_COMMAND`.

[`verify.py`](./verify.py) copies the collector to the DUT and runs it there
rather than feeding it on standard input, because a `CRAM_REMOTE_COMMAND`
containing `ssh -n` redirects standard input from `/dev/null` and would deliver
an empty script. This is the form CI uses.

## Checklist

1. `baf.yml`: add the `RUN_AS_USER` and `RUN_AS_GROUP` options.
2. `baf.yml`: build and clean the `odl` directory, install the caps ODL.
3. Add `odl/<component>_caps.odl.m4`.
4. Generate it from `odl/Makefile`, defaulting to `root`.
5. Include it last in the main ODL, and delete any `keep-all` block.
6. Install every helper the plugin executes as `0755`.
7. Add the entry to `rules.yml`.
8. Add the options to every board `005-build-config.t` that selects it.
9. Run the three security tests and read the post-suite permission check.
