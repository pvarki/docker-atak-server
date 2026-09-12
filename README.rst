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
Standalone initialization retains the original shared keystore default.

Rerunning the initializer refreshes the keystores from their PEM files without
regenerating the product key or reimporting the database. HTTPS certificate
rotation therefore leaves CoT and JWT signing keys intact. CoT clients may use
EC certificates. The truststores contain the CFSSL root and intermediate CAs.


Versioning
^^^^^^^^^^

Versioning is handled with bump-my-version_. To increment, use ``bump-my-version bump <patch/minor/major>``.

You can use ``bump-my-version show-bump`` to see how each option would affect the version.

  - Major and minor are TAKServer major and minor
  - Patch is takserver release
  - Build is the modification date for this repo

.. _bump-my-version: https://github.com/callowayproject/bump-my-version
