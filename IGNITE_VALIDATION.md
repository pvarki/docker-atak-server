# Independent-container validation — 2026-09-13

Branches: `feat/container-ignite-networking` in the orchestration repository,
TAK Server and takrmapi. No images were pushed and no PRs were created.

The local runtime was built from cached
`ghcr.io/pvarki/tak-server:5.8.69-2609122002-pr134`, adding the current scripts,
templates and plugin launcher. The launcher was compiled against that image's
plugin libraries using the same build step as the Dockerfile. Upstream
`UserManager.jar` SHA-256 remained
`329c3831d0550bef309a7c77ff29c3b398279f973bc9789e0db5c26817ac39c7`.
takrmapi used its cached Java 17 JRE runtime with the changed application source.

## Passed

- 23 TAK startup regression tests in the Linux image.
- takrmapi local suite: 45 passed, 9 existing skips.
- Standalone project `taksplit20260913`: configuration, messaging, API, retention
  and plugin manager each used a distinct IP. Ignite reported one server and
  four clients; retention's remote query service and the plugin manager's data
  feed, mission and CoreConfig APIs became available.
- A separate takrmapi JNI container registered certificate and password users,
  persisted ordinary/IN/OUT groups, and read them through the remote user manager.
- An EC client certificate exchanged CoT between TLS connections on both 8089
  and 8090 with CA-chain and hostname verification enabled.
- Messaging replacement changed its IP from `10.89.18.13` to `10.89.18.21`.
  All four clients rejoined without being restarted. HTTPS and persisted JNI state
  remained available.
- Independent config/API/retention/plugin restarts also changed each IP; HTTPS
  and remote user/group reads passed after every restart.
- Root project `taksplitrm20260913`: fresh initialization obtained the RSA product
  certificate through RMAPI and CFSSL. All five TAK roles and takrmapi reached
  healthy state in separate network namespaces.

## Findings and remaining validation

A 64 MB messaging cache caused Ignite page eviction to spin while creating CoT
subscriptions. Raising the validation cache maximum to 256 MB resolved it.
Production defaults retain TAK's normal sizing.

The root HTTP suite encountered unreachable interface addresses on multi-network
Podman services. TAK HTTP routing now uses network-specific aliases. During this
investigation the shared Podman VM stopped responding to both API commands and
SSH, preventing a clean rerun. The full root suite has **not passed** in this run.

The standalone admin CLI also needed private TAKCL XML: it cannot reuse the
server's multicast configuration. Its new XML generation has a local regression
test; live CLI validation, a CFSSL-issued EC CoT test, and final root composition
restart checks remain pending VM recovery. No other project's containers or
volumes were intentionally stopped or modified.

Local logs, test scripts and isolated composition definitions are under
`/private/tmp/tak-split-20260913`. The standalone project was stopped with its
volumes retained. Inspect the root project's actual state after VM recovery before
resuming it; attempts to update HTTP aliases and stop its retention/plugin roles
were outstanding when the VM became unresponsive.
