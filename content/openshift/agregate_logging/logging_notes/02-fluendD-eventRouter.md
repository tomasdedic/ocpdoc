# EventRouter
Deployment which will periodically query **events** and store and process them over FluentD and store to ElasticSearch
## Events 
By kubernetes events we understand log messages internal to kubernetes, accessible through the kubernetes API */api/v1/events?watch=true*, originally stored in etcd. The **etcd storage has time and performance constraints**, therefore, we would like to collect and store them permanently in EFK.
+ **eventrouter** is deployed to logging project, has a service account and its own role to read events
+ **eventrouter** watches kubernetes events, marshalls them to JSON and outputs to its STDOUT
+ **fluentd** picks them up and inserts to elastic search logging project index
### EventRouter Depoloyment
use template from RHEL  
[event_router_template](yaml/eventrouter/eventRouter-template.yaml)
```sh
oc process -f eventRouter-template.yaml  | oc apply -f -
```
### Configuring the Event Router
```sh
oc project openshift-logging
oc get ds
Set TRANSFORM_EVENTS=true in order to process and store event router events in Elasticsearch.
Set cluster logging to the unmanaged state in web console
oc set env ds/fluentd TRANSFORM_EVENTS=true
```

```sh
oc get clusterlogging instance -o yaml
oc edit ClusterLogging instance
```
get logs:

```sh
oc exec fluentd-ht42r -n openshift-logging -- logs
 # logs is a binary to display logs 
```
You can send Elasticsearch logs to external devices, such as an externally-hosted Elasticsearch instance or an external syslog server. You can also configure Fluentd to send logs to an external log aggregator.

Configuring Fluentd to send logs to an external log aggregator
You can configure Fluentd to send a copy of its logs to an external log aggregator, and not the default Elasticsearch, using the secure-forward plug-in. From there, you can further process log records after the locally hosted Fluentd has processed them.

-->to v podstate znamena pouzitu secure-forward ---> jina instance fluentD s Kafka pluginem a dal do Kafky
> fluentd nema forward plugin pro Kafku a Redhat ani neplanuje

>[object Object]: [security_exception] no permissions for [indices:data/read/field_caps] and User [name=CN=system.logging.kibana,OU=OpenShift,O=Logging, roles=[]]
