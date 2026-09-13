########################################################################
# We can't do COPY --from=pvarki/tak-server-dist:$TAK_RELEASE  #
# So work around like this                                             #
########################################################################
ARG TEMURIN_VERSION="17"
ARG JAVA_RUNTIME_IMAGE="eclipse-temurin:${TEMURIN_VERSION}-jre-noble"
ARG TAK_RELEASE="5.8-RELEASE-69"
ARG KW_PRODUCT_INIT_IMAGE="ghcr.io/pvarki/kraftwerk-helper-tool:1.4.0-260912"
FROM ${KW_PRODUCT_INIT_IMAGE} AS product-init
FROM pvarki/tak-server-dist:$TAK_RELEASE AS tak-files
RUN mv /zips/takserver-docker-*.zip /tmp/takserver.zip

FROM ${JAVA_RUNTIME_IMAGE} AS deps
ENV \
  LC_ALL=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssl \
      python3-lxml \
      unzip \
      tini \
      curl \
      pwgen \
      zip \
      postgresql-client \
      jq \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -o /usr/bin/wait-for-it.sh \
    && chmod a+x /usr/bin/wait-for-it.sh \
    && true

COPY --from=hairyhenderson/gomplate:stable /gomplate /bin/gomplate
SHELL ["/bin/bash", "-lc"]


FROM deps AS unpack
COPY --from=tak-files /tmp/takserver.zip /tmp/takserver.zip
RUN cd /tmp \
    && unzip takserver.zip \
    && rm takserver.zip \
    && export DISTDIR=`echo takserver-docker-*` \
    && mv $DISTDIR"/tak" /opt/tak \
    && true

# Keep the distribution archive out of the runtime image's layers.
FROM deps AS install
COPY --from=unpack /opt/tak /opt/tak
COPY docker/entrypoint.sh /entrypoint.sh
COPY scripts /opt/scripts
COPY templates /opt/templates
COPY update /opt/tak/webcontent/update
COPY java /tmp/tak-launcher
RUN unzip -q /opt/tak/takserver-pm.jar 'BOOT-INF/classes/*' 'BOOT-INF/lib/*' -d /tmp/tak-plugin-api \
    && javac --release 17 -cp '/tmp/tak-plugin-api/BOOT-INF/classes:/tmp/tak-plugin-api/BOOT-INF/lib/*' \
      -d /tmp/tak-launcher/classes /tmp/tak-launcher/PluginLauncher.java \
    && jar --create --file /opt/tak/lib/pvarki-launcher.jar -C /tmp/tak-launcher/classes . \
    && rm -rf /tmp/tak-plugin-api /tmp/tak-launcher

FROM install AS run
COPY --from=product-init /kw_product_init /kw_product_init
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
