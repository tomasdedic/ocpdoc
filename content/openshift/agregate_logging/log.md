---
title: "Logging snipets bez ladu a skladu"
date: 2020-11-15 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Logging"
tags:
  - "Snippets"
---

```sh
oc patch Elasticsearch elasticsearch --type merge --patch '{"spec": {"managementState": "Unmanaged"}}'
oc patch ClusterLogging instance --type merge --patch '{"spec": {"managementState": "Unmanaged"}}'


```
#### Exposing Elasticsearch as a route
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: elasticsearch
  namespace: openshift-logging
spec:
  host:
  to:
    kind: Service
    name: elasticsearch
  tls:
    termination: reencrypt
    destinationCACertificate: | 
```
```sh
 oc extract secret/elasticsearch --to=. --keys=admin-ca

cat ./admin-ca | sed -e "s/^/      /" >> <file-name>.yaml
oc create -f <file-name>.yaml
token=$(oc whoami -t) #get Bearer token
routeES=$(oc get route elasticsearch -o jsonpath={.spec.host})

set token (oc get secrets elasticsearch-token-56mz6 -n openshift-logging -o json|jq -Mr '.data.token'|base64 -d)
set routeES (oc get route -n openshift-logging elasticsearch -o json|jq -Mr '.spec.host')
curl -tlsv1.2 --insecure -H "Authorization: Bearer $token" "https://$routeES/.operations.*/_search?size=1" | jq
```
#### ES query
```sh
# get incices order by creation
GET _cat/indices?h=health,status,index,id,pri,rep,docs.count,docs.deleted,store.size,creation.date.string&s=creation.date.string

GET _cat/aliases

GET _cat/templates?v
```
#### Curator settings
Beginning with Elasticsearch version 6.6, Elasticsearch has provided Index Lifecycle Management (or, ILM) to users with at least a Basic license. ILM provides users with many of the most common index management features as a matter of policy, rather than execution time analysis (which is how Curator works).
  
Nastavit curator tak aby retence proindexy byla 6 dnů.
!! kurator uz se nepouziva
#### KIBANA problem
!! jak funguje RBAC a role mapping
```sh
_cat/aliases
"type": "security_exception",
        "reason": "no permissions for [indices:admin/aliases/get] and User [name=tdedic, roles=[admin_reader], requestedTenant=admin]"
      }
```
### USE Azure EventHub instead of Kafka
Azure EventHub is able to consume kafka_output, for testing purposes we will use one.  

```sh
Kafka Concept vs Event Hubs Concept
Cluster        <---->     NamespaceL
Topic          <---->     Event Hub
Partition      <---->     Partition
Consumer Group <---->     Consumer Group
Offset         <---->     Offset
```
fluentD kafka output sample configuration:
```sh
  <store>
  @type kafka2
  brokers fluentd-eventhub-oshi.servicebus.windows.net:9093
  flush_interval 3s
  <buffer topic>
    @type file
    path '/var/lib/fluentd/retry_clo_default_kafka_out'
		flush_interval "#{ENV['ES_FLUSH_INTERVAL'] || '1s'}"
		flush_thread_count "#{ENV['ES_FLUSH_THREAD_COUNT'] || 2}"
		flush_at_shutdown "#{ENV['FLUSH_AT_SHUTDOWN'] || 'false'}"
		retry_max_interval "#{ENV['ES_RETRY_WAIT'] || '300'}"
		retry_forever true
		queue_limit_length "#{ENV['BUFFER_QUEUE_LIMIT'] || '32' }"
		chunk_limit_size "#{ENV['BUFFER_SIZE_LIMIT'] || '8m' }"
		overflow_action "#{ENV['BUFFER_QUEUE_FULL_ACTION'] || 'block'}"
    flush_interval 3s
  </buffer>

  # topic settings
  default_topic kafka_output 

  # producer settings
  max_send_retries 1
  required_acks 1
  <format>
    @type json
  </format>
  ssl_ca_certs_from_system true

  username $ConnectionString
  password "Endpoint=sb://fluentd-eventhub-oshi.servicebus.windows.net/;SharedAccessKeyName=ss;SharedAccessKey=zeWz+9rSS/yWGanjcKrXMA2mAVCO0hL+MULhNWXHfkk=;EntityPath=kafka_output"
  </store>
```


