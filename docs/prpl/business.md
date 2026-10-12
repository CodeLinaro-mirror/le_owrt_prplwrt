# Business / enterprise routing: BGP and OSPF

## Overview

prplOS can act as a business/enterprise gateway that participates in dynamic
routing instead of (or in addition to) plain static/DHCP-learned routes.
Two protocols are supported, each solving a different part of the problem:

- **BGP** (Border Gateway Protocol, RFC 4271) is an exterior gateway
  protocol. Two routers ("neighbors") open a TCP session (port 179) and
  exchange route advertisements carrying path attributes such as AS number,
  AS-path, next-hop, MED and local preference. On the CPE, BGP is used
  "north-bound": to advertise the customer's LAN prefixes to the operator's
  network gateway, and to learn routes back from it, optionally inside a
  VPN/IPsec tunnel. This is not meant to carry the internet's full routing
  table — only the customer's own routes, shared between a limited set of
  peers.
- **OSPF** (Open Shortest Path First, OSPFv3/RFC 5340) is a link-state
  interior gateway protocol. Routers flood Link State Advertisements (LSAs)
  to build an identical topology database and compute shortest paths
  (Dijkstra SPF); topology is organized in areas (backbone area `0.0.0.0`
  plus optional additional areas). On the CPE, OSPF is used "south-bound":
  to distribute routes across the customer LAN, between the gateway and
  other routers on that LAN.

The two protocols are chained together on the gateway, which acts as an
OSPF **ASBR** (Autonomous System Border Router): routes learned from BGP are
redistributed into OSPF so LAN devices learn the operator/remote-site routes, and
routes learned from OSPF (or LAN devices) are redistributed into BGP so they
are advertised to the operator network gateway.

```
   LAN devices  <---- OSPF ---->  [ CPE / gateway, ASBR ]  <---- BGP ---->  Operator network gateway
                (route exchange)      redistributes            (route exchange, optionally
                 within the LAN     between OSPF <-> BGP        over a VPN/IPsec tunnel)
```

> Note: Creation of the VPN tunnel is not part of this business feature.

These features are integrated into the regular gateway profile (there is no
separate business/extender-style profile or container): a device only needs
the relevant packages, kernel options and TR-181 configuration below to use
them, keeping all other prpl gateway features available.

## Components

Dynamic routing protocols, BGP and OSPF, are implemented by the [`bird2`](https://bird.network.cz/)
routing daemon, driven and configured through TR-181:

- [`tr181-bgp-ospf`](https://gitlab.com/prpl-foundation/components/core/plugins/tr181-bgp-ospf)
  — TR-181 `Device.Routing.X_PRPLWARE-COM_{BGP, OSPF, RouteFiltering}` datamodel plugin. It
  exposes the BGP/OSPF data model and delegates the actual protocol handling to a pluggable back-end module.
- [`mod-routing-bird2`](https://gitlab.com/prpl-foundation/components/core/modules/mod-routing-bird2)
  — the back-end module selected for dynamic routing. It translates the
  TR-181 BGP/OSPF configuration into `bird2` configuration and manages the
  `bird2` daemon lifecycle (see below).
- [`netdev`](https://gitlab.com/prpl-foundation/components/core/plugins/netdev) — mirrors kernel routes into the data model; exposes a
  `RouteProtocolIgnoreList` filter so routes installed by a routing protocol
  (`bird2` installs routes with `rtproto` 12/"bird") can be excluded from the
  data model. See the `netdev` component documentation for configuration
  details and the default value.

## Enabling BGP/OSPF

### 1. Build-time: packages

`mod-routing-bird2` and `tr181-bgp-ospf` are included by default in the
[`prpl_core`](../../profiles/prpl_core.yml) build profile
(`profiles/prpl_core.yml`), so a standard prplOS image already ships with the
packages required for BGP/OSPF support — no separate profile needs to be
selected as of right now.

To remove dynamic routing support entirely (e.g. for a memory-constrained
device that will never need it):
1. Drop `mod-routing-bird2` from the build profile so `bird2` is not compiled/installed at all.
2. Disable dynamic routing support via `CONFIG_PACKAGE_tr181-bgp-ospf` handle. (e.g. set to 'n')

### 2. Build-time: kernel configuration

BGP authentication depends on kernel support that is **not enabled by
default** in the prplOS generic kernel config:

| Kernel option | Purpose | Status in prplOS | Notes |
| --- | --- | --- | --- |
| `CONFIG_TCP_MD5SIG` | TCP MD5 Signature Option (RFC 2385) — used by `SecureSession.MD5.Password` in the BGP data model | Present but disabled by default: it's a dependency of the `mod-routing-bird2` | Enabled automatically when `mod-routing-bird2` is enabled. |
| `CONFIG_TCP_AO` | TCP Authentication Option (RFC 5925) — used by `SecureSession.AO.*` in the BGP data model | **Not available**: added upstream in Linux 6.7; prplOS currently builds kernel 5.15 or 6.6 (`target/linux/generic/config-5.15`, `config-6.6`), both below 6.7 | Use MD5 authentication (`CONFIG_TCP_MD5SIG`) instead until a prplOS target moves to kernel >= 6.7. |

### 3. Run-time: TR-181 data model

BGP and OSPF configuration lives under `Device.Routing.`, using a vendor
prefix until standardized by the Broadband Forum:

- `Device.Routing.X_PRPLWARE-COM_BGP.` — BGP configuration
- `Device.Routing.X_PRPLWARE-COM_OSPF.` — OSPF configuration
- `Device.Routing.X_PRPLWARE-COM_RouteFiltering.` — shared route filtering
  rules, referenced from BGP/OSPF

To actually enable dynamic routing:

1. **BGP**: set `Device.Routing.X_PRPLWARE-COM_BGP.Enable = true`, create at
   least one `Config.{i}` instance (`AS`, `RouterID`, `Timers`, ...) with
   `Config.{i}.Enable = true`, and add `Neighbor.{i}` entries
   (`RemoteAddress`, `RemoteAS`, `AFISAFI`, optionally
   `SecureSession.MD5`/`SecureSession.AO`) with `Neighbor.{i}.Enable = true`.
2. **OSPF**: set `Device.Routing.X_PRPLWARE-COM_OSPF.Enable = true`, create
   at least one `Config.{i}` instance (`InstanceID`, `IPVersion`,
   `RouterID`) with `Config.{i}.Enable = true`, add an `Area.{i}` with
   `Enable = true`, and an `Interface.{i}` bound to a LAN interface with
   `Enable = true`.

`mod-routing-bird2` only starts the `bird2` daemon once at least one
protocol has its global `Enable = true` **and** at least one rendered
`Config` entry; it stops `bird2` again once that is no longer true. The
OpenWrt `bird2` package's own init-script autostart is patched out, so
`bird2` is never running with an empty configuration — this keeps the
runtime footprint minimal when BGP/OSPF are not configured.

See the `tr181-routing` and `mod-routing-bird2` READMEs (linked above) for
the full parameter reference, RPCs and operational data models (RIB, LSDB, neighbor state, etc.).

## Scale and memory considerations

BGP/OSPF deployments can involve a large number of routes (on the order of
10,000). Reflecting all of them in the TR-181 data model would use a
significant amount of memory, so:

- Routes installed by `bird2` are filtered out of the `netdev`/routing
  data model via `RouteProtocolIgnoreList`, instead of being mirrored 1:1.
  This means that no BGP or OSPF routes (installed by `bird2`) are present in the `Device.Routing.Router.{i}.IPv4Forwarding.{i}.` and `Device.Routing.Router.{i}.IPv6Forwarding.{i}.` tables.
- When BGP and OSPF are disabled and `bird2` is not running, the extra
  footprint contributed by dynamic-routing support in `tr181-routing` is
  minimal.

## Logging

`bird2` logs to syslog. Use
[`Device.Syslog.`](https://usp-data-models.broadband-forum.org/tr-181-2-21-0-usp.html#D.Device:2.Device.Syslog.)
and
[`Device.DeviceInfo.LogRotate.`](https://usp-data-models.broadband-forum.org/tr-181-2-21-0-usp.html#D.Device:2.Device.DeviceInfo.LogRotate.)
to configure the log file path, filter which `bird2` logs are captured, and
enable log rotation.

## Data model status

The BGP/OSPF data model (`Device.Routing.X_PRPLWARE-COM_BGP.` /
`Device.Routing.X_PRPLWARE-COM_OSPF.`) is a vendor extension on top of
`Device.Routing.`, pending standardization in the Broadband Forum TR-181
data model.

On the ubus, the datamodels are also available under `BGPOSPF.` common root:
```
BGPOSPF.X_PRPLWARE-COM_BGP
BGPOSPF.X_PRPLWARE-COM_RouteFiltering
BGPOSPF.X_PRPLWARE-COM_OSPF
```