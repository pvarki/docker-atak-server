================================
Run TAK Java server in container
================================

tldr::

    cp takserver.env.example takserver.env
    # edit the env
    # export the variables gomplate uses (see the .tpl files)
    docker compose pull --include-deps --ignore-pull-failures
    docker compose -p tak up -d


or if you want to first build locally to test changes use the compose build so that the local image is used instead:

    export DOCKER_TAG_EXTRA="-dev"
    docker compose -f docker-compose.yml -p tak build
    cp takserver.env.example takserver.env
    # edit the env
    docker compose -f docker-compose.yml -p tak up

Note, for things that live in the volumes (like TAK certs) you must nuke the volumes to see changes::

    docker compose -f docker-compose.yml -p tak down -v ; docker compose -f docker-compose.yml -p tak rm -vf



Creating client packages locally
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Using the REST API is probably nicer though

Create client package::

    docker compose -p tak exec takserver_api /bin/bash -c 'CLIENT_CERT_NAME=replaceme /opt/scripts/make_client_zip.sh'

Then get /opt/tak/certs/files/clientpkgs/replaceme.zip out of the container::

    docker compose -p tak exec taktakserver_apiserver /bin/bash -c 'base64 /opt/tak/certs/files/clientpkgs/replaceme.zip' | base64 -id >replaceme.zip

This approach also works for recovering the admin cert (/opt/tak/certs/files/admin.p12 unless you changed the ADMIN_CERT_NAME ENV)


Creating new admin users
^^^^^^^^^^^^^^^^^^^^^^^^

Create the user on the takserver container::

    docker compose -p tak exec takserver_api /bin/bash -c 'cd /opt/tak/data/certs/ && CAPASS=$CA_PASS PASS=replaceme_user_cert_pass ./makeCert.sh client replaceme_username && ADMIN_CERT_NAME=replaceme_username /opt/scripts/enable_admin.sh'

See above about the hard way of getting the cert file, or use the REST API.


Gradle builds
^^^^^^^^^^^^^

Build the distribution::

    mkdir outputs
    docker build --progress=plain -f Dockerfile_build --target files -t atakbuild:files  .
    docker run --rm -it -v `pwd`/outputs:/output atakbuild:files

Now you have the build artefacts in outputs -directory.


CFSSL and HTTPS certificates
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``/opt/scripts/firstrun_rm.sh`` initializes the product identity through RMAPI,
which signs its CSR with CFSSL. It requests RSA explicitly because TAK 5.8 uses
its global TLS key for RS256 JWT signing. No TAK Java classes are modified.

Mount the same volume at ``/data/persistent`` in ``takinit`` and ``takrmapi``.
The initializer owns the single-use CSR token in ``/pvarki/kraftwerk-init.json``;
``takrmapi`` reuses the resulting ``private/mtlsclient.key`` and
``public/mtlsclient.pem``. Existing RSA product credentials are reused. Older
certificates with only client authentication are renewed through mTLS to obtain
server authentication too. Deploy the corresponding RMAPI CFSSL profile update
before this initializer.

CoT on port 8089 uses ``/opt/tak/data/certs/files/takserver.jks`` with the CFSSL
identity. HTTPS on port 8443 uses ``takserver-https.jks``, imported from
``/le_certs/rasenmaeher/privkey.pem`` and ``fullchain.pem``. Set
``TAK_HTTPS_KEYSTORE_FILENAME=/opt/tak/data/certs/files/takserver-https.jks``
for all TAK processes; the integration compositions set this automatically.
The API startup script also sets Spring's SSL keystore property because TAK's
primary HTTPS connector ignores the per-connector keystore override.
Both keystores use ``TAKSERVER_CERT_PASS`` / ``TAKSERVER_KEYSTORE_PASS``.
The dedicated HTTPS keystore is also the image default when the override is unset.
Neither startup mode requires ``TAK_HTTPS_*`` overrides for certificate separation.
RASENMAEHER defaults to its product mTLS PEM for CoT and the files in
``/le_certs/rasenmaeher`` for HTTPS; standalone defaults to two locally generated
identities. Omitting HTTPS configuration never selects CoT's keystore for HTTPS.
When the optional password aliases are unset, RASENMAEHER initialization uses
``TAKSERVER_CERT_PASS`` for identity stores and ``CA_PASS`` for truststores.

Rerunning the initializer refreshes the keystores from their PEM files without
regenerating the product key or reimporting the database. HTTPS certificate
rotation therefore leaves CoT and JWT signing keys intact. CoT clients may use
EC certificates. The truststores contain the CFSSL root and intermediate CAs.


Standalone certificates and persistence
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``/opt/scripts/firstrun.sh`` uses the standalone Python initializer. It needs no
RASENMAEHER manifest, RMAPI, CFSSL service or ``kw_product_init``. It generates a
local CA on first initialization and preserves existing CA, CoT and administrator
identities on subsequent runs. CoT and JWT signing use the RSA identity in
``takserver.jks``. HTTPS uses the separate ``takserver-https.jks`` store.

By default, HTTPS receives its own EC P-256 identity signed by the local CA.
New server certificates include ``TAK_SERVER_ADDRESS`` as a DNS or IP SAN.
Clients must trust the local CA when this default is used. Existing CoT
certificates are reused, including their original names and validity periods.

To use an external HTTPS certificate, mount its files into the initialization
container and set both ``TAK_HTTPS_KEY_FILENAME`` and ``TAK_HTTPS_CERT_FILENAME``
in ``takserver.env``. The certificate PEM should contain the leaf and its chain.
For encrypted private keys, also set ``TAK_HTTPS_KEY_PASSWORD``. HTTPS's JKS uses
``TAKSERVER_CERT_PASS``, independently of the PEM private-key password. An optional
``TAK_HTTPS_KEYSTORE_FILENAME`` override must be shared across TAK services and
must point to a different store from CoT's ``takserver.jks``.

Rerun initialization after replacing external HTTPS PEM files, then restart the
API service to load the new keystore. The key/certificate pair is checked before
the HTTPS store is replaced. Local generated identities are not automatically
rotated. Database initialization remains gated by ``firstrun.done``; that marker
does not block HTTPS refresh or adding the separate HTTPS store to an older
standalone installation. Neither operation resets saved administrator XML.

A missing federation truststore is initialized with the local CoT certificate
and CA chain. An existing store, including imported remote CA certificates, is
left unchanged. The persistent configuration ownership and migration rules
below apply equally to standalone and RASENMAEHER deployments.

Persistent administrator configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The configuration service owns ``/opt/tak/data/CoreConfig_config.xml`` on the
persistent TAK volume. All services read this file through their
``/opt/tak/CoreConfig.xml`` symlink. The common ``/opt/tak/data/CoreConfig.xml``
path used by UserManager and takrmapi is also a symlink to this authority.

On configuration-service startup, Python renders the template and merges only
explicitly deployment-owned settings into the saved XML:

* The ``stdssl`` and ``stdssl-noarchive`` listeners, including their ports and
  archiving setting, and the ``https`` connector's deployment settings.
* Database connection parameters, local TLS identity/trust paths and passwords,
  and OCSP configuration.
* Deployment authentication defaults, the user-authentication file location,
  and LDAP configuration.
* The federation server's local identity keystore and web base URL.

Other saved settings survive, including federation peers, group mappings,
federation policy, federation truststore path/password, custom listeners and
administrator adjustments outside these managed fields. The exact attribute
allowlist is in ``scripts/coreconfig.py``. New template defaults outside this
allowlist apply only to new installations; changes to existing installations
need an explicit migration or an administrator edit.

The merged XML must validate against the installed TAK schema. Conflicting
listener ports and invalid XML stop startup without replacing the saved file.
A successful change first saves ``CoreConfig_config.xml.pre-merge-backup`` and
then atomically publishes the new configuration. An unchanged merge does not
replace the backup. Configuration files and these backups are written with
owner-only permissions because they contain credentials.

Only the configuration service renders shared XML. It holds an exclusive lock
for its lifetime; other services wait up to 180 seconds for the current service
to finish preparing configuration. Restart the configuration service to apply
deployment-environment changes. Restarting API or messaging alone does not
re-render configuration.

For an existing installation, the saved ``CoreConfig_config.xml`` takes priority
over the common file. If absent, the common file is used as the migration source.
The original common file is retained as ``CoreConfig.xml.pre-authority-backup``
before that path becomes a symlink. Old process-specific files are left in place
but are no longer read. Recreate all TAK service containers with the updated
image together: an old container still running the old startup script can
overwrite saved configuration. Keep the existing TAK volume; deleting it would
delete administrator configuration and certificates.

Federation truststore initialization
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``firstrun_rm.sh`` initializes a missing ``fed-truststore.jks`` with the public
product mTLS certificate from ``kw_product_init`` and the local CA chain.
Repeated certificates are deduplicated; no private key is imported. Creation is
atomic, and an existing store is left untouched, preserving administrator-added
federation trust. Later product/CA rotation or truststore-password changes require
explicit federation truststore maintenance; restarting initialization does not
replace this store. Other local TLS stores continue to be refreshed as before.

Configuration regression tests
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Run these checks using the TAK image, which provides Python, lxml, gomplate,
OpenSSL, keytool and the matching configuration schema::

    docker run --rm -v "$PWD:/workspace:ro" --entrypoint /usr/bin/python3 \
      ghcr.io/pvarki/tak-server:5.8.69-260912 \
      -m unittest discover -s /workspace/tests -v
    docker run --rm -v "$PWD:/workspace:ro" --entrypoint /bin/bash \
      ghcr.io/pvarki/tak-server:5.8.69-260912 /workspace/tests/test-fed-truststore.sh
    docker run --rm -v "$PWD:/workspace:ro" --entrypoint /bin/bash \
      ghcr.io/pvarki/tak-server:5.8.69-260912 /workspace/tests/test-api-keystore.sh

These tests do not start the full integration composition. Standalone tests use
real certificate tools but mock database initialization; the API keystore test
executes the startup script with a stub JVM to inspect the Spring environment.

To also exercise the RASENMAEHER initialization defaults with synthetic internal
and external certificate chains, run in a fresh disposable container::

    docker run --rm -v "$PWD:/workspace:ro" -v "$PWD/scripts:/opt/scripts:ro" \
      --entrypoint /usr/bin/python3 ghcr.io/pvarki/tak-server:5.8.69-260912 \
      /workspace/tests/check_rm_defaults.py

This check clears HTTPS overrides, supplies an existing product identity and
database marker, and compares the certificates actually imported into both JKS
stores. It does not contact RMAPI or a database.

Versioning
^^^^^^^^^^

Versioning is handled with bump-my-version_. To increment, use ``bump-my-version bump <patch/minor/major>``.

You can use ``bump-my-version show-bump`` to see how each option would affect the version.

  - Major and minor are TAKServer major and minor
  - Patch is takserver release
  - Build is the modification date for this repo

.. _bump-my-version: https://github.com/callowayproject/bump-my-version
