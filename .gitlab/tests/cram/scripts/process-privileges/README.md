# Process privileges

This directory contains the tooling that verifies which user, group and
capabilities every process runs with on the DUT, and this document explains how
to make a plugin run as a non-root user.

- [`rules.yml`](./rules.yml) describes the expected process tree.
- [`collect.sh`](./collect.sh) copies
  [`target/process-privileges.lua`](./target/process-privileges.lua) to the DUT
  and runs it there.
- [`verify.py`](./verify.py) compares the collected tree against `rules.yml`.
- [`verify.sh`](./verify.sh) wires the two together for the cram tests.

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
- Capabilities are added to the effective, permitted, bounding and inheritable
  sets, never to the **ambient** set.
- Supplementary groups are dropped when the user is switched, and there is no
  option to keep or add any.

## What capabilities do not solve

Capabilities apply to the plugin process itself. They are **not inherited
across `execve()`**, because the ambient set is never populated. Anything the
plugin runs as a separate program (a helper binary, a shell script, a hotplug
handler) starts with no capabilities at all, as the plugin user.

Two consequences bite in practice:

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
starts it:

```yaml
  - cmd: tr181-usb
    id: tr181_app:tr181_app
    caps: dac_override
```

| field | meaning |
| --- | --- |
| `cmd` | process name as it appears on the DUT |
| `id` | expected `user:group` |
| `caps` | expected capabilities |
| `child` | expected child processes, same fields, nested |
| `optional` | the process may be absent |
| `ignore_child` | do not check the children of this process |

`caps` is a comma separated list of lowercase names without the `CAP_` prefix,
so `CAP_DAC_OVERRIDE` in the ODL becomes `dac_override` here. Two values are
special: `full` for a process that keeps every capability, and `none` for a
process that has none.

Mark an entry `optional` when the process only exists on some boards or only
under some conditions. A required entry that is missing fails the test on every
board.

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
sh verify.sh
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

Both transport variables come from the environment, as described in
[`../README.md`](../README.md), and neither is a command line argument.
`TARGET_LAN_IP` names the DUT when it cannot be derived from
`CRAM_REMOTE_COMMAND`.

[`collect.sh`](./collect.sh) copies the collector to the DUT and runs it there
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
