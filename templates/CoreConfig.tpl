<?xml version="1.0" encoding="UTF-8"?>
<Configuration xmlns="http://bbn.com/marti/xml/config"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="/opt/tak/CoreConfig.xsd">
    <network multicastTTL="5">
        <input _name="stdssl" protocol="tls" port="8089"/>

        <!-- web connectors -->
        <connector port="8443" _name="https"/>
        <connector port="8444" useFederationTruststore="true" _name="fed_https"/>
        <connector port="8446" clientAuth="false" _name="cert_https"/>
    </network>
    <auth>
        <File location="/opt/tak/data/UserAuthenticationFile.xml"/>
    </auth>
    <submission ignoreStaleMessages="false" validateXml="false"/>

    <subscription reloadPersistent="false">
    </subscription>

    <repository enable="true" numDbConnections="50" primaryKeyBatchSize="500" insertionBatchSize="500">
      <connection url="jdbc:postgresql://{{getenv "POSTGRES_ADDRESS" "tak-database"}}:5432/{{getenv "POSTGRES_DB" "cot"}}" username="{{.Env.POSTGRES_USER}}" password="{{.Env.POSTGRES_PASSWORD}}" />
    </repository>

    <repeater enable="true" periodMillis="3000" staleDelayMillis="15000">
        <!-- Examples -->
        <repeatableType initiate-test="/event/detail/emergency[@type='911 Alert']" cancel-test="/event/detail/emergency[@cancel='true']" _name="911"/>
        <repeatableType initiate-test="/event/detail/emergency[@type='Ring The Bell']" cancel-test="/event/detail/emergency[@cancel='true']" _name="RingTheBell"/>
        <repeatableType initiate-test="/event/detail/emergency[@type='Geo-fence Breached']" cancel-test="/event/detail/emergency[@cancel='true']" _name="GeoFenceBreach"/>
        <repeatableType initiate-test="/event/detail/emergency[@type='Troops In Contact']" cancel-test="/event/detail/emergency[@cancel='true']" _name="TroopsInContact"/>
    </repeater>

    <dissemination smartRetry="false" />

    <filter>
        <flowtag enable="false" text=""/>
        <streamingbroker enable="true"/>
        <scrubber enable="false" action="overwrite"/>
    </filter>

    <buffer>
        <latestSA enable="true"/>
        <queue/>
    </buffer>

<!-- With  "Authority Information Access" included in certs this works for both 8089 and 8443 but I see no OCSP query for 8443 -->
    <security>
        <tls keymanager="SunX509"
            keystore="JKS" keystoreFile="/opt/tak/data/certs/files/takserver.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
            truststore="JKS" truststoreFile="/opt/tak/data/certs/files/truststore-root.jks" truststorePass="{{.Env.CA_PASS}}"
            enableOCSP="true" responderUrl="http://{{.Env.TAK_OCSP_UPSTREAM_IP}}:{{.Env.TAK_OCSP_PORT}}"
            />
    </security>

<!-- 8089 works (until CRL expires) but 8443 doesn't, there is no sane way to refresh the CRL (process restart is way too slow)
     and I see *no* queries to OCSP server -->
<!--
    <security>
        <tls keymanager="SunX509"
            keystore="JKS" keystoreFile="/opt/tak/data/certs/files/takserver.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
            truststore="JKS" truststoreFile="/opt/tak/data/certs/files/truststore-root.jks" truststorePass="{{.Env.CA_PASS}}"
            enableOCSP="true" responderUrl="http://{{.Env.TAK_OCSP_UPSTREAM_IP}}:{{.Env.TAK_OCSP_PORT}}"
            >
            <crl _name="ROOT CA" crlFile="/ca_public/crl_root.pem"/>
            <crl _name="RASENMAEHER CA" crlFile="/ca_public/crl_intermediate.pem"/>
        </tls>
    </security>
-->

<!-- in both of the above cases we get: [services-deployment-worker-#57%ignite-takserver%] WARN com.bbn.marti.service.SSLConfig - TLS enabled, but no certificate revocation lists, and OSCP is not enabled in Core Config!
     however in the below case we get similar complaint a *second* time when the 8089 port actually starts serving -->

<!-- 8089 and 8443 work but obviously revocation checks do not work -->
<!--
    <security>
        <tls keymanager="SunX509"
            keystore="JKS" keystoreFile="/opt/tak/data/certs/files/takserver.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
            truststore="JKS" truststoreFile="/opt/tak/data/certs/files/truststore-root.jks" truststorePass="{{.Env.CA_PASS}}"
            />
    </security>
-->

</Configuration>
