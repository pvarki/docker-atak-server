# TAK Ignite bindings and future sidecar removal

Date: 2026-09-13. Source: the initial JNI implementation in
`../../python-tak-operator`.

TAK Server can bind Ignite to a routable container/Pod IP, allowing the Python
operator to run in a separate network namespace. This was verified with real
TAK JVMs, an embedded Java 17/PyJNIus client, and persisted file-auth mutations.

The validated topology still runs TAK configuration, messaging, and API in one
Pod. Moving those server processes into separate containers with independent
network namespaces is the next experiment; it has not been validated by these
results.

## Reproduction baseline

- TAK release: `5.8-RELEASE-69`.
- Validated image: `ghcr.io/pvarki/tak-server:5.8.69-2609122002-pr134`.
- Image digest: `sha256:04d58dd4b1154ec5232f27131c03affabbf98e6dbc39a4f88ba53066db46e013`.
- `/opt/tak/utils/UserManager.jar` SHA-256:
  `329c3831d0550bef309a7c77ff29c3b398279f973bc9789e0db5c26817ac39c7`.
- Shared test cluster: `kind-rmk8soperator`; namespace: `tak-operator-system`.
- Workloads: `takserver` (config/messaging/api), `tak-database`, `tak-operator`.

This checkout's Compose image name is `pvarki/takserver`, while the validated
artifact uses `pvarki/tak-server`. Check the actual artifact and JAR checksum
when reproducing; similar release tags alone do not establish equivalence.

Useful source files in the neighboring operator repository:

- [Server Ignite template](../../python-tak-operator/deploy/base/TAKIgniteConfig.tpl)
- [TAK deployment](../../python-tak-operator/deploy/base/takserver.yaml)
- [Operator deployment](../../python-tak-operator/deploy/operator/deployment.yaml)
- [JVM bootstrap and Java 17 options](../../python-tak-operator/src/takoperator/runtime.py)
- [Direct JNI store](../../python-tak-operator/src/takoperator/bridge.py)
- [Local commands and networking notes](../../python-tak-operator/deploy/README.md)

The initial implementation is recorded in operator commits `6cae302`, `a33e745`,
and `66eeb1b`.

## Server binding: the verified configuration

Render this gomplate template to `/opt/tak/data/TAKIgniteConfig.xml` before the
TAK JVMs start. The current Kubernetes deployment mounts it over
`/opt/templates/TAKIgniteConfig.tpl` in the configuration container:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<TAKIgniteConfiguration xmlns="http://bbn.com/marti/xml/config"
    igniteHost="{{.Env.POD_IP}}"
    igniteNonMulticastDiscoveryPort="47500"
    igniteNonMulticastDiscoveryPortCount="10"
    igniteCommunicationPort="47100"
    igniteCommunicationPortCount="10"
    ignitePoolSize="4"
    cacheOffHeapInitialSizeBytes="33554432"
    cacheOffHeapMaxSizeBytes="134217728"/>
```

`igniteHost` selects the local bind address. Supply the address assigned to the
network namespace running that JVM. The verified configuration uses an explicit
Pod IP. A remote server address or a Kubernetes Service virtual IP is not the
client's local bind address.

Kubernetes supplies the server address to the template through the Downward API:

```yaml
env:
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
```

The three server containers currently share that Pod IP and XML. Live socket
inspection showed discovery on `<TAK_POD_IP>:47500` and communication on
`<TAK_POD_IP>:47100`, `:47101`, and `:47102`, instead of localhost. The pool and
cache values above are development resource limits, not networking requirements.

## Separate operator: distinguish binding from discovery

The operator generates its own Ignite XML with `igniteHost` set to its own Pod
IP. It does not mount the TAK server's data volume or reuse the server's
address-bearing XML. Its environment is:

```yaml
env:
  - name: TAK_IGNITE_HOST
    value: takserver
  - name: TAK_IGNITE_BIND_ADDRESS
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
  - name: TAK_RUNTIME_DIR
    value: /var/run/takoperator
  - name: IGNITE_WORK_DIR
    value: /var/run/takoperator/temporary
```

`TAK_IGNITE_HOST`, `TAK_IGNITE_BIND_ADDRESS`, and `TAK_RUNTIME_DIR` are variables
implemented by the Python operator. They are not automatically recognized by
TAK server launch scripts. `takserver` is a headless Service in the same namespace;
use its fully qualified DNS name from another namespace.

The operator sets these JVM properties before importing `jnius`:

```text
-Dcom.bbn.marti.takcl.config.filepath=/var/run/takoperator/TAKCLConfig.xml
-Dcom.bbn.marti.takcl.takIgniteConfigPath=/var/run/takoperator/data/TAKIgniteConfig.xml
-Dcom.bbn.marti.takcl.ignoreCoreConfig=true
-Dcom.bbn.marti.takcl.igniteIpAddressOverride=takserver
-Dcom.bbn.marti.takcl.igniteNetworkTimeout=10000
-Dcom.bbn.marti.takcl.igniteClientFailureDetectionTimeout=30000
```

`igniteIpAddressOverride` provides the remote discovery seed independently of
the local XML bind address. This is verified for **TAKCL/TakclIgniteHelper**.
Do not assume the config, messaging, API, retention, or plugin server launch paths
consume that TAKCL property; trace their own discovery initialization before
splitting those JVMs across network namespaces.

Use the existing runtime module for the complete valid TAKCL XML, classpath,
Java 17 module opens, temporary directories, and CLI server-profile construction.
The XML declaration must start at byte zero. The operator maintains one JVM and
one Ignite client for the process lifetime, closing its client only on shutdown.

## Network requirements

This is an Ignite Java cluster client, not an HTTP endpoint or a thin client on
port 10800. Discovery is only the first connection; members subsequently connect
to the advertised Pod addresses and communication ports.

| Destination | TCP ports allowed in the tested manifests | Purpose |
| --- | --- | --- |
| TAK Pod | 47500-47510 | Discovery range |
| TAK Pod | 47100-47110 | Communication range for the server JVMs |
| Operator Pod | 47500-47600 | Default local discovery range |
| Operator Pod | 47100-47200 | Default local communication range |

Allow bidirectional reachability between the participating Pod/container IPs.
Publishing only 47500, or port-forwarding it to localhost, does not provide the
full cluster transport. The headless Service supplies a routable discovery
address without port translation. Address ranges above are the manifest's
firewall allowances; the observed active server sockets are listed earlier.

For a future Compose split, use a common user-defined network with routable
container addresses and service DNS. Move externally published CoT/HTTPS ports
to the containers actually serving them. The existing `ports` declarations on
`takserver_config` rely on the shared network namespace.

The local experiment uses Ignite without TLS. Keep its control plane internal
and restrict ingress to intended members. The operator manifests include
NetworkPolicies, but the default kind CNI does not enforce them. NetworkPolicy
enforcement and Ignite transport security need separate validation for deployment
outside this local test setup.

## Writable work directory: a misleading startup failure

This version of Ignite reads `IGNITE_WORK_DIR` using `System.getenv`.
`-DIGNITE_WORK_DIR=...` did not configure it. Set the **environment variable**
before the JVM starts and ensure the directory exists and is writable.

Without it, the non-root, read-only operator attempted to create
`/app/ignite/work`. TAKCL hid the underlying filesystem failure behind:

```text
Could not connect to server within the 0 ms timeout!
```

Setting `IGNITE_WORK_DIR=/var/run/takoperator/temporary` and using
`workingDir: /var/run/takoperator` on a writable `emptyDir` fixed startup. The
operator remains UID/GID 1000 with a read-only root filesystem. A separate writable
`/tmp` is also mounted. Check filesystem permissions and the underlying Ignite
exception before treating that message as a networking timeout.

## What must change before removing the TAK sidecars

In the current [Compose file](docker-compose.yml), messaging shares config's
network namespace; API, retention, and plugin manager share messaging's.
The empty [Ignite template](templates/TAKIgniteConfig.tpl) leaves binding defaults
in effect.

The [startup code](scripts/start_tak.py) also has an important ownership contract:
only `config` renders shared XML; other profiles wait for its generation/lock
marker. Every profile links `/opt/tak/TAKIgniteConfig.xml` to the same
`/opt/tak/data/TAKIgniteConfig.xml`.

A future migration should address these steps together:

1. Trace the exact 5.8.69 server discovery setup and identify a supported way to
   configure common remote seeds independently from each JVM's local bind IP.
   The successful external TAKCL client does not establish this for server JVMs.
2. Give each independently networked JVM its own Ignite configuration. A shared
   XML containing the config container's IP cannot be used as every container's
   local bind address. Split Ignite rendering from shared CoreConfig ownership;
   do not make every service overwrite the shared configuration files.
3. Preserve the existing single-writer CoreConfig and file-auth persistence
   semantics. Decide how other containers receive configuration and readiness;
   the present shared-volume `flock`/generation contract needs reconsideration
   if storage or node placement also changes. Binding changes alone require no
   certificate regeneration or volume deletion.
4. Replace `network_mode: service:...` with explicit network attachments only
   after per-process binding and discovery work. On Compose, resolve each local
   bind IP at startup; do not hardcode the IP observed in one container run.
5. Audit other localhost assumptions and shared paths, including configuration
   service access, certificates, API/messaging dependencies, retention, and plugin
   startup. Independent Ignite connections do not prove these paths work.
6. Replace the Compose `true` healthchecks with actual service readiness. Test
   independent starts, failure/rejoin, and container IP changes on recreation.
7. Move published application ports to their owning services and keep Ignite
   internally reachable in both directions. Use a distinct writable Ignite work
   directory for each JVM.

## Acceptance checks for the follow-up

Reproduce the known topology first using `task tak:up` and `task operator:up` in
`../../python-tak-operator`; build its image with `task operator:build` when needed.
Use `task cluster:up` only if the shared cluster is absent. Preserve the existing
cluster, test Secrets, and persistent volumes.

The initial experiment passed separate-Pod JNI tests for password and certificate
creation, password updates, ordinary/IN/OUT membership replacement, no-op repeats,
server-role clearing, listing, and deletion. The deployed controller also passed
Bob/Charlie reconciliation, group removal/restoration, credential rotation,
revocation/reactivation, finalizer deletion, and operator restart. Results were
checked against persisted TAK state while preserving platform status.

For the full server split, additionally require:

- Every process binds its own IP and joins the intended discovery topology;
  inspect sockets, topology membership, and remote service availability.
- The operator performs real file-auth reads and writes from another container;
  a successful TCP probe is insufficient.
- Each TAK service can restart/rejoin independently, including after its IP
  changes, without losing users, certificates, directional groups, or admin state.
- CoreConfig changes and startup ownership remain correct through those restarts.
- HTTPS/admin operations and a real TAK client's authentication and CoT flow work.
- Retention/plugin behavior is tested when those services are reintroduced; they
  were omitted from the initial Kubernetes experiment.

No full multi-namespace TAK server split, cross-node deployment, Ignite TLS, or
client-visible routing behavior was proven by the initial operator tests.
