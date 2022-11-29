=====================
Build TAK Server Java
=====================

Docker based builds to build the Java distribution


Build the distribution::

    mkdir outputs
    docker build --progress=plain -f Dockerfile_build --target files -t atakbuild:files  .
    docker run --rm -it -v `pwd`/outputs:/output atakbuild:files

Now you have the build artefacts in outputs -directory.
