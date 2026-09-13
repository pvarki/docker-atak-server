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

- 25 TAK startup regression tests in the final Linux image, including real
  outbound Java truststore import and refresh.
- takrmapi local suite: 45 passed, 9 existing skips.
- Root integration suite after final container recreation: 35 passed, 13 skipped.
  The isolated deployment enabled TAK and Keycloak; other products were omitted.
  A temporary pytest harness substituted its ports and credential directories
  without changing the repository's assertions.
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
- The administrative CLI updated the product certificate user over remote Ignite
  using its private TAKCL configuration.
- Inside takrmapi, both the user's `_rm.pem` main certificate and the separate
  TAK-package certificate used EC keys and verified against the CFSSL chain.
  The package certificate exchanged CoT on 8089 and 8090 with OCSP enabled,
  and client-side CA-chain and hostname verification enabled.
- Root TAK containers were recreated using the final image. A dummy federation
  peer (`127.0.0.1:9`), federation policy, user authentication entries, and the
  federation truststore persisted. The truststore's SHA-256 remained
  `812a5f6f80ba9218d2fd60b5372766e14bf754bc1f3d3af9c8629b6aba7455f2`.
  HTTPS/CoT identity separation, OCSP and port 8090's disabled archiving remained
  configured. The closed dummy endpoint exercised persistence, not communication
  with a real federation peer.

## Findings

A 64 MB messaging cache caused Ignite page eviction to spin while creating CoT
subscriptions. Raising the validation cache maximum to 256 MB resolved it.
Production defaults retain TAK's normal sizing.

The root HTTP suite initially encountered unreachable interface addresses on
multi-network Podman services. TAK HTTP routing now uses network-specific aliases.
The isolated harness also gave RMAPI an alias on its HTTP network.

The administrative CLI requires private unicast TAKCL XML; it cannot reuse the
server's multicast configuration.

The CFSSL CoT test exposed two OCSP transport problems. Separate messaging
containers resolved the development OCSP hostname to loopback, and the default
Java truststore did not trust miniwerk's HTTPS CA. The server reported only
`General OpenSslEngine problem`; a direct Java HTTPS probe exposed connection
refusal and then PKIX trust failure. Internal proxy aliases and private outbound
truststores fixed both, retaining public CAs and leaving OCSP enabled.

The shared Podman VM temporarily stopped responding during validation and later
recovered without a VM restart. All remaining checks above completed afterward.
No other project's containers or volumes were stopped or modified.

Local logs, test scripts and isolated composition definitions are under
`/private/tmp/tak-split-20260913`. Both isolated projects were stopped after
validation with their volumes retained. The final images remain local as
`localhost/tak-split:server` and `localhost/tak-split:rmapi`. These checks used
cached runtime layers with the changed source; they did not download and rebuild
the upstream TAK distribution or exercise a live federation peer.
