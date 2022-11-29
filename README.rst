===================
Run TAK Java server
===================

tldr::

    cp takserver.env.example takserver.env
    # edit the file
    docker-compose -p tak up -d


Gradle builds
^^^^^^^^^^^^^

Build the distribution::

    mkdir outputs
    docker build --progress=plain -f Dockerfile_build --target files -t atakbuild:files  .
    docker run --rm -it -v `pwd`/outputs:/output atakbuild:files

Now you have the build artefacts in outputs -directory.
