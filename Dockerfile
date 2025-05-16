########################################################################
# We can't do COPY --from=pvarki/tak-server-dist:$TAK_RELEASE  #
# So work around like this                                             #
########################################################################
ARG TEMURIN_VERSION="17"
ARG TAK_RELEASE="5.4-RELEASE-19"
FROM pvarki/tak-server-dist:$TAK_RELEASE AS tak-files
RUN mv /zips/takserver-docker-*.zip /tmp/takserver.zip

FROM eclipse-temurin:${TEMURIN_VERSION}-jammy AS deps
ENV \
  LC_ALL=C.UTF-8
RUN apt-get update && apt-get install -y \
      emacs-nox \
      net-tools \
      netcat \
      vim \
      nmon \
      python3-lxml \
      unzip \
      tini \
      curl \
      pwgen \
      zip \
      openssh-client \
      postgresql-client \
      jq \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -o /usr/bin/wait-for-it.sh \
    && chmod a+x /usr/bin/wait-for-it.sh \
    && true

COPY --from=hairyhenderson/gomplate:stable /gomplate /bin/gomplate
SHELL ["/bin/bash", "-lc"]


FROM deps AS install
COPY docker/entrypoint.sh /entrypoint.sh
COPY --from=tak-files /tmp/takserver.zip /tmp/takserver.zip
RUN cd /tmp \
    && unzip takserver.zip \
    && rm takserver.zip \
    && export DISTDIR=`echo takserver-docker-*` \
    && mv $DISTDIR"/tak" /opt/tak \
    && true
COPY scripts /opt/scripts
COPY templates /opt/templates

FROM install AS run
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
