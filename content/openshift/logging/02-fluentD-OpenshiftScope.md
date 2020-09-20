# FluentD
Everything that a containerized application writes to stdout or stderr is streamed somewhere by the container engine – in Docker’s case,
for example, to a logging driver. These logs are usually located in the /var/log/containers directory on your host.

The fluentd component runs as a **daemonset** it means one pod runs on each node in cluster. As nodes are added/removed, kubernetes orchestration ensures that there is one fluentd pod running on each node. Fluentd is configured to run as a privileged container. **It is able to collect logs from all pods on the node, convert them to a structured format and pass them to log aggregator.**

## Architecture
Kubernetes, containerized applications that log to stdout and stderr have their log streams captured and redirected to JSON files on the nodes. The Fluentd Pod will tail these log files, filter log events, transform the log data, and ship it off to the Elasticsearch logging backend
{{< figure src="img/fluentd-architecture.jpg" title="fluentD architecture" >}}

## FLUENTD BASE CONFIGURATION and CUSTOMIZATION
Base configuration is stored in ConfigMap
```sh
oc get cm fluentd -o json|jq -r '.data["fluent.conf"]'|vim -
oc get cm fluentd -o json|jq -r '.data["run.sh"]'|vim -
```
Version of fluentD from logging-operator csv 4.4 is without fluentd-kafka-plugin
```yaml
 # list ruby gems on container
scl enable rh-ruby25 -- gem list
```
I made a version of fluentd with kafka and other plugins compiled into gems. So let's try as kafka we will use Azure EventHub
dasdas
### TEST FLUENTD locally with podman
plugin used for fluentD build:  
```sh
gem install fluent-config-regexp-type 
gem install fluent-mixin-config-placeholders 
gem install fluent-plugin-concat 
gem install fluent-plugin-elasticsearch 
gem install fluent-plugin-kafka 
gem install fluent-plugin-kubernetes_metadata_filter 
gem install fluent-plugin-multi-format-parser 
gem install fluent-plugin-prometheus 
gem install fluent-plugin-record-modifier 
gem install fluent-plugin-remote-syslog 
gem install fluent-plugin-remote_syslog 
gem install fluent-plugin-rewrite-tag-filter 
gem install fluent-plugin-splunk-hec 
gem install fluent-plugin-systemd 
gem install fluent-plugin-viaq_data_model
```
podman pull fluent/fluentd:v1.11-debian-1
 #with conffile mount
podman run -p 8888:8888 -ti  --rm -v  /home/ts/git_repositories/work/openshift/oshi/logging:/fluentd/etc docker.io/fluent/fluentd:v1.11-debian-1 fluentd -c /fluentd/etc/fluent.conf
```
### USE Azure EventHub instead of Kafka
Azure EventHub is able to consume kafka_output, for testing purposes we will use one.  

```sh
Kafka Concept vs Event Hubs Concept
Cluster        <---->     Namespace
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

### PATCH original CM with custom map

```sh
oc get cm fluentd -n openshift-logging >fluentd-cm.yaml
 # bass is fish specific in bash you can ommit, right way to do it in fish shell
 # is to use process substitution
 # yq w  -i test.yaml 'data.[fluent.conf]' -- (cat fluent.conf|psub) 
 # but not working becouse I get FIFO not a stream
bass 'yq w -i fluentd-cm.yaml 'data.[fluent.conf]'  -- "$(< fluent.conf)"'
oc apply -f fluentd-cm.yaml
```
Custom map is mounted to pod in location 
```sh
/etc/fluentd/config.d/
```
so restart of fluentD is neccesary
```sh
for i in (oc get pods -o name --selector component=fluentd); oc delete $i; end
```
