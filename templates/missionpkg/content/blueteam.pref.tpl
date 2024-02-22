<?xml version="1.0" encoding="ASCII" standalone="yes"?>
<preferences>
   <preference version="1" name="cot_streams">
      <entry key="count" class="class java.lang.Integer">1</entry>
      <entry key="description0" class="class java.lang.String">{{.Env.TAK_SERVER_NAME}}</entry>
      <entry key="enabled0" class="class java.lang.Boolean">true</entry>
      <entry key="connectString0" class="class java.lang.String">{{.Env.TAK_SERVER_ADDRESS}}:8089:ssl</entry>
   </preference>
   <preference version="1" name="com.atakmap.app_preferences">
      <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
      <entry key="caLocation" class="class java.lang.String">cert/truststore-root.p12</entry>
      <entry key="caPassword" class="class java.lang.String">{{.Env.CA_PASS}}</entry>
      <entry key="certificateLocation" class="class java.lang.String">cert/{{.Env.CLIENT_CERT_NAME}}.p12</entry>
      <entry key="clientPassword" class="class java.lang.String">{{.Env.CLIENT_CERT_PASSWORD}}</entry>
      <entry key="locationCallsign" class="class java.lang.String">{{.Env.CLIENT_CERT_NAME}}</entry>
      <entry key="deviceProfileEnableOnConnect" class="class java.lang.Boolean">true</entry> 
      <entry key="eud_api_sync_mapsources" class="class java.lang.Boolean">false</entry> 
   </preference>
</preferences>
