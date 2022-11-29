########################################################################
# We can't do COPY --from=pvarkiprojekti/tak-server-dist:$TAK_RELEASE  #
# So work around like this                                             #
########################################################################
ARG TAK_RELEASE="4.7-RELEASE-32"
FROM pvarkiprojekti/tak-server-dist:$TAK_RELEASE as tak-files
RUN mv /zips/takserver-docker-full-*.zip /tmp/takserver.zip

FROM openjdk:11-jdk-bullseye as deps
ENV \
  LC_ALL=C.UTF-8
COPY --from=tak-files /tmp/takserver.zip /tmp/takserver.zip
RUN apt update && apt-get install -y \
      emacs-nox \
      net-tools \
      netcat \
      vim \
      nmon \
      python3-lxml \
      unzip \
      tini \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && true

COPY --from=hairyhenderson/gomplate:stable /gomplate /bin/gomplate
SHELL ["/bin/bash", "-lc"]


FROM deps as install
RUN cd /tmp \
    && unzip takserver.zip \
    && rm takserver.zip \
    && export DISTDIR=`echo takserver-docker-full*` \
    && mv $DISTDIR"/tak" /opt/tak \
    && true
