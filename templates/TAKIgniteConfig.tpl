<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!-- Keep Ignite's default finder: TAK's non-multicast finder replaces remote seeds
     with igniteHost. The default finder retains IGNITE_TCP_DISCOVERY_ADDRESSES. -->
<TAKIgniteConfiguration xmlns="http://bbn.com/marti/xml/config"
    igniteHost="{{.Env.TAK_IGNITE_BIND_ADDRESS}}"
    igniteMulticast="true"
    ignitePoolSize="{{getenv "TAK_IGNITE_POOL_SIZE" "-1"}}"
    cacheOffHeapInitialSizeBytes="{{getenv "TAK_IGNITE_CACHE_INITIAL_BYTES" "-1"}}"
    cacheOffHeapMaxSizeBytes="{{getenv "TAK_IGNITE_CACHE_MAX_BYTES" "-1"}}"
    igniteConnectionTimeoutSeconds="{{getenv "TAK_IGNITE_CONNECTION_TIMEOUT" "10"}}"
    igniteClientConnectionTimeoutSeconds="{{getenv "TAK_IGNITE_CLIENT_TIMEOUT" "30"}}"
    igniteFailureDetectionTimeoutSeconds="{{getenv "TAK_IGNITE_FAILURE_TIMEOUT" "60"}}"/>
