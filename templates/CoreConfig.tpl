<?xml version="1.0" encoding="UTF-8"?>
<Configuration xmlns="http://bbn.com/marti/xml/config"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="/opt/tak/CoreConfig.xsd">
    <network multicastTTL="5">
        <input _name="stdssl" protocol="tls" port="8089" coreVersion="2"/>

        <!-- default web connectors
        <connector port="8443" _name="https"/>
        <connector port="8444" useFederationTruststore="true" _name="fed_https"/>
        <connector port="8446" clientAuth="false" _name="cert_https"/>
        -->
        <!-- Disable webtak and non-admin user interfaces -->
        <connector port="8443" _name="https" enableWebtak="{{getenv "WEBTAK_ENABLE" "false"}}" enableNonAdminUI="false" />
    </network>
{{if getenv "LDAP_BIND_PASSWORD" ""}}
<!--
    <auth default="ldap" x509groups="true" x509addAnonymous="false">
        <File location="/opt/tak/data/UserAuthenticationFile.xml" />
        <ldap url="{{getenv "LDAP_URL" "ldap://openldap:1389"}}"
              updateinterval="60"
              userstring="uid={username},ou=users,dc=example,dc=org"
              style="DS"
              ldapSecurityType="simple"
              serviceAccountDN="cn={{getenv "LDAP_BIND_USER" "admin"}},dc=example,dc=org"
              serviceAccountCredential="{{getenv "LDAP_BIND_PASSWORD" ""}}"
              groupBaseRDN="ou=groups,dc=example,dc=org"
              groupObjectClass="groupOfNames"
              groupNameExtractorRegex="(?:cn|CN)=(?:tak_)?(.+?),"
              groupprefix="CN=tak_"
        />
    </auth>
-->
<auth default="ldap" x509groups="true" x509addAnonymous="false">

     <File location="/opt/tak/data/UserAuthenticationFile.xml"/>

     <ldap url="ldaps://idm.localmaeher.dev.pvarki.fi:636"
     userstring="spn={username}@idm.localmaeher.dev.pvarki.fi,o=kanidm"
     updateinterval="60"
     groupprefix="spn=tak_"
     groupNameExtractorRegex="spn=(?:tak_)?([^,@]+)"
     style="DS"
     ldapSecurityType="simple"
     serviceAccountDN="dn=token"
     serviceAccountCredential="eyJhbGciOiJFUzI1NiIsImtpZCI6IjkzMTJmZjRhYzcxODNkYzA5NjM4Y2QzZWE4YjM5MTQwIn0.eyJhY2NvdW50X2lkIjoiOGMzMTU3ZGEtMjRiYy00ZWUxLWEzNTUtMzc0NTZhNGVhM2E3IiwidG9rZW5faWQiOiI3OTcxNmYyZi02NGIxLTQ3ZmQtODFjOS1kNGRlZWZhNDQ3NjQiLCJsYWJlbCI6IkFQSSBUb2tlbiIsImV4cGlyeSI6bnVsbCwiaXNzdWVkX2F0IjoxNzc5NDY4OTUzLCJwdXJwb3NlIjoicmVhZG9ubHkifQ.40Da8jsMLXr62pceWYSoKw1ahvevLBpFTCtF87CQGfTG6ff_Im_z_mPY1cTLgX3qA6P0NJ3HNVEtIOY3tY-FHg"
    
     groupObjectClass="memberOf"
     groupBaseRDN="o=kanidm"
     
     readGroupSuffix="_read"
     writeGroupSuffix="_write"
     
     ldapsTruststore="JKS"
     ldapsTruststoreFile="/opt/tak/data/certs/files/truststore-root.jks"
     ldapsTruststorePass="takcacertpw"
     />


</auth>

{{else}}
    <auth x509groups="true" x509addAnonymous="false">
        <File location="/opt/tak/data/UserAuthenticationFile.xml"/>
    </auth>
{{end}}
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

    <security>
        <tls context="TLSv1.2"
            keymanager="SunX509"
            keystore="JKS" keystoreFile="/opt/tak/data/certs/files/takserver.jks" keystorePass="{{.Env.TAKSERVER_CERT_PASS}}"
            truststore="JKS" truststoreFile="/opt/tak/data/certs/files/truststore-root.jks" truststorePass="{{.Env.CA_PASS}}"
            enableOCSP="{{getenv "TAK_OCSP_ENABLE" "false"}}"
            />
    </security>
</Configuration>
