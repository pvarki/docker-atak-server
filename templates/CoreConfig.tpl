<?xml version="1.0" encoding="UTF-8"?>
<Configuration xmlns="http://bbn.com/marti/xml/config"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="CoreConfig.xsd">
    <network multicastTTL="5">
        <input _name="stdssl" protocol="tls" port="8089"/>
        <!--
        <input _name="stdtcp" protocol="tcp" port="8087" auth="anonymous"/>
        <input _name="stdudp" protocol="udp" port="8087" auth="anonymous"/>
        <input _name="streamtcp" protocol="stcp" port="8088" auth="anonymous"/>
        -->
        <!-- <input _name="SAproxy" protocol="mcast" group="239.2.3.1" port="6969" proxy="true" auth="anonymous" /> -->
        <!-- <input _name="GeoChatproxy" protocol="mcast" group="224.10.10.1" port="17012" proxy="true" auth="anonymous" /> -->
        <!--<announce enable="true" uid="Marti1" group="239.2.3.1" port="6969" interval="1" ip="192.168.1.137" />-->
         <!--<input _name="stdssl" protocol="tls" port="8089"/>-->
         <!--<input _name="sslauth" protocol="tls" port="8090" auth="ldap"/> -->
        <!--<input _name="stdtcpwithgroups" protocol="tcp" port="8087" auth="anonymous">-->
            <!--<filtergroup>group one</filtergroup>-->
            <!--<filtergroup>group two</filtergroup>-->
        <!--</input>-->
        <!--<input _name="stdtcpwithfilters" protocol="tcp" port="8087" auth="anonymous">-->
            <!--<filter>-->
                <!--<geospatialFilter>-->
                    <!--<boundingBox minLongitude="-80" minLatitude="34" maxLongitude="-70" maxLatitude="36" />-->
                    <!--<boundingBox minLongitude="-100" minLatitude="34" maxLongitude="-90" maxLatitude="36" />-->
                <!--</geospatialFilter>-->
            <!--</filter>-->
        <!--</input>-->

        <!-- web connectors -->
        <connector port="8443" _name="https"/>
        <connector port="8444" useFederationTruststore="true" _name="fed_https"/>
        <connector port="8446" clientAuth="false" _name="cert_https"/>
        <connector port="8080" tls="false" _name="http_plaintext"/>
    </network>
    <auth>
                <!-- Example OpenLDAP -->
        <!--
        <ldap
            url="ldap://hostname.bbn.com/"
            userstring="uid={username},ou=People,dc=XXX,dc=bbn,dc=com"
            updateinterval="60"
            style="DS"
        />
        -->

        <!-- Example ActiveDirectory -->

        <!--NOTE!! In the example below, GroupBaseDN should be specified relative to the naming context provided in the url attribute below -->
        <!--
        <ldap
            url="ldap://hostname.bbn.com/dc=XXX,dc=bbn,dc=com"
            userstring="DOMAIN\{username}"
            updateinterval="60"
            groupprefix=""
            style="AD"
            ldapSecurityType="simple"
            serviceAccountDN="cn=fred001,cn=Users,cn=Partition1,dc=XYZ,dc=COM"
            serviceAccountCredential="XXXXXX"
            groupObjectClass="group"
            groupBaseRDN="CN=Groups"/>
        />

        -->
            <File location="UserAuthenticationFile.xml"/>
    </auth>
    <submission ignoreStaleMessages="false" validateXml="false"/>

    <subscription reloadPersistent="false">
        <!-- example static subscription that publishes messages to a UDP multicast address and port -->
        <!-- <static _name="MulticastProxy" protocol="udp" address="239.2.3.1" port="6969" /> -->
    </subscription>

    <repository enable="true" numDbConnections="16" primaryKeyBatchSize="500" insertionBatchSize="500">POSTGRES_DB
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
        <!--
        <dropfilter>
            <typefilter type="u-d-p" />
            <typefilter type="u-d-c" />
        </dropfilter>
        -->
        <scrubber enable="false" action="overwrite"/>
    </filter>

    <buffer>
        <latestSA enable="true"/>
        <queue/>
    </buffer>

    <security>
        <tls context="TLSv1.2"
            keymanager="SunX509"
            keystore="JKS" keystoreFile="/opt/tak/certs/files/takserver.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
            truststore="JKS" truststoreFile="/opt/tak/certs/files/truststore-root.jks" truststorePass="{{.Env.CA_PASS}}">
         <!-- <crl _name="TAKServer CA" crlFile="certs/files/ca.crl"/>  -->

        </tls>

         <!-- previous locations of keystore and truststore -->
         <!--
         <tls context="TLSv1.2"
            keymanager="SunX509"
            keystore="JKS" keystoreFile="certs/TAKServer.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
            truststore="JKS" truststoreFile="certs/truststore.jks" truststorePass="{{.Env.CA_PASS}}">
        </tls>
        -->

    </security>

<!--
    <federation>
      <federation-server port="9000">
        <tls context="TLSv1.2"
         keymanager="SunX509"
         keystore="JKS" keystoreFile="certs/files/takserver.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
         truststore="JKS" truststoreFile="certs/files/fed-truststore.jks" truststorePass="{{.Env.CA_PASS}}"/>
      </federation-server>
    </federation>
-->
 <!-- previous locations of federate keystore and truststore -->
 <!--
 <tls context="TLSv1.2"
         keymanager="SunX509"
         keystore="JKS" keystoreFile="certs/TAKServer.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
         truststore="JKS" truststoreFile="certs/fed-truststore.jks" truststorePass="{{.Env.CA_PASS}}"/>
 -->

<!--

<certificateSigning CA="{TAKServer | MicrosoftCA}">
    <certificateConfig>
        <nameEntries>
            <nameEntry name="O" value="Test Org Name"/>
            <nameEntry name="OU" value="Test Org Unit Name"/>
        </nameEntries>
    </certificateConfig>
    <TAKServerCAConfig
        keystore="JKS"
        keystoreFile="certs/files/intermediate-ca-signing.jks"
        keystorePass="atakatak"
        validityDays="30"
        signatureAlg="SHA256WithRSA" />
    <MicrosoftCAConfig
        username="{MS CA Username}"
        password="{MS CA Password}"
        truststore="/opt/tak/certs/files/keystore.jks"
        truststorePass="atakatak"
        svcUrl="https://{server}/{CA name}_CES_UsernamePassword/service.svc"
        templateName="Copy of User"/>
</certificateSigning>

-->

</Configuration>
