===================
Run TAK Java server
===================

tldr::

    docker build --progress=plain -t takserver:latest -t takserver:4.7-RELEASE-32 .
    cp takserver.env.example takserver.env
    # edit the file
    docker-compose -p tak up -d

Create client package::

    docker-compose -p tak exec takserver /bin/bash -c 'CLIENT_CERT_NAME=replaceme /opt/scripts/make_client_zip.sh'

Then get /opt/tak/certs/files/clientpkgs/replaceme.zip out of the container::

    docker-compose -p tak exec takserver /bin/bash -c 'base64 /opt/tak/certs/files/clientpkgs/replaceme.zip' | base64 -id >replaceme.zip

This approach also works for recovering the admin cert (/opt/tak/certs/files/admin.p12 unless you changed the ADMIN_CERT_NAME ENV)

Gradle builds
^^^^^^^^^^^^^

Build the distribution::

    mkdir outputs
    docker build --progress=plain -f Dockerfile_build --target files -t atakbuild:files  .
    docker run --rm -it -v `pwd`/outputs:/output atakbuild:files

Now you have the build artefacts in outputs -directory.
