<MissionPackageManifest version="2">
   <Configuration>
      <Parameter name="uid" value="{{print .Env.TAK_SERVER_NAME "-DEFAULT" | strings.Slug}}"/>
      <Parameter name="name" value="{{.Env.TAK_SERVER_NAME}}"/>
      <Parameter name="onReceiveDelete" value="false"/>
   </Configuration>
   <Contents>
      <Content ignore="false" zipEntry="content/blueteam.pref"/>
      <Content ignore="false" zipEntry="content/Google_Hybrid.xml"/>
      <Content ignore="false" zipEntry="content/{{.Env.CLIENT_CERT_NAME}}.p12"/>
      <Content ignore="false" zipEntry="content/takserver-public.p12"/>
      <Content ignore="false" zipEntry="TAK_defaults.pref"/>
   </Contents>
</MissionPackageManifest>
