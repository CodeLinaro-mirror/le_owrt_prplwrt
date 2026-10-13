# Running prplOS components as a non-root user

## Concept

prplOS supports running application processes (TR-181 plugins and other
`amxrt`-based components) as an unprivileged user instead of `root`. Instead of one
process holding full root, each component drops to a dedicated user/group and keeps
only the specific Linux capabilities it actually needs. This reduces the impact of a
compromised or buggy plugin (defense in depth / least privilege), without changing
the plugin's functional behavior.

This is delivered incrementally, one component at a time.

## How it works

Each ported component carries three pieces:

- **`baf.yml`** declares two config symbols:
  - `CONFIG_SAH_AMX_<COMPONENT>_RUN_AS_USER`
  - `CONFIG_SAH_AMX_<COMPONENT>_RUN_AS_GROUP`

  Both default to `tr181_app`, a shared non-root user/group. `makefile.inc` carries
  the same default (`?= tr181_app`) so a board that never sets the symbol still gets
  the non-root user.

- **`odl/<component>_caps.odl.m4`** declares the runtime privileges for that user:

  ```
  %config {
      %global privileges = {
          user = "USER_ID", group = "GROUP_ID",
          capabilities = [
              "CAP_CHOWN",
              "CAP_DAC_OVERRIDE",
              ...
          ]
      };
  }
  ```

  `amxrt` (from `libamxrt`) reads this block at startup, switches to `user`/`group`,
  and adds only the listed capabilities to its effective/permitted/bounding/
  inheritable sets before dropping supplementary groups.

- **`config/sudoers.d/<component>.m4`** grants that group passwordless `sudo` rights
  to the handful of root-only commands the component still has to invoke directly
  (e.g. `/sbin/reboot`), instead of granting it broader privileges.

The `prpl`/`prpl_core` profiles (`profiles/prpl.yml`, `profiles/prpl_core.yml`) pull
in the supporting packages this relies on: `sudo`, `libcap-bin`, `libcap-ng-bin`.

## Enabling / disabling

There is no single repo-wide switch in `prplos/prplos` that turns this on or off for
every component at once. It is opt-in **per component**: once a component is ported
(its `baf.yml`/`makefile.inc` carry the `RUN_AS_USER`/`RUN_AS_GROUP` symbols above),
it defaults to running as `tr181_app`.

- **To disable it for one component**, override its config symbols back to root in
  the board/profile config:

  ```
  CONFIG_SAH_AMX_<COMPONENT>_RUN_AS_USER=root
  CONFIG_SAH_AMX_<COMPONENT>_RUN_AS_GROUP=root
  ```

- **To disable it everywhere**, every ported component's `RUN_AS_USER`/
  `RUN_AS_GROUP` symbols must be overridden the same way — there is currently no
  single flag that does this for the whole build. Grep the target board's
  `.gitlab/tests/cram/<board>/005-build-config.t` fixture for `RUN_AS_USER` to see
  the resolved value per component for that board.

## Known caveats

- **No ambient capability set.** `amxrt_caps_apply()` sets the effective, permitted,
  bounding and inheritable sets, but not the ambient set. A capability granted in
  `<component>_caps.odl.m4` is usable by the plugin process itself, and by any child
  it spawns with `amxp_subproc_astart()`/`amxp_subproc_vstart()`, but **not** by a
  child started with a plain `popen()`/`system()`/shell script — that child gets no
  capabilities at all and any privileged call in it fails with `EPERM`.
- **Exact user/group match required.** The `RUN_AS_USER`/`RUN_AS_GROUP` default must
  exactly match a user that actually exists on the target (`tr181_app`, not e.g.
  `tr181-app`). A mismatch does not fail the build — it silently leaves the
  component running as root, so the privilege drop looks configured but never
  happens.
