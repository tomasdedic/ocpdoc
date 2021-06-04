---
title: "Logging snipets bez ladu a skladu"
date: 2021-05-25
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Logging"
tags:
  - "Snippets"
thumbnail: "img/lognip.jpg"
---

#### Operator unmanaged/managed state
```sh
oc patch Elasticsearch elasticsearch --type merge --patch '{"spec": {"managementState": "Unmanaged"}}'
oc patch ClusterLogging instance --type merge --patch '{"spec": {"managementState": "Unmanaged"}}'

oc get ClusterLogging instance -o jsonpath='{.items[*]}{"state: "}{.spec.managementState}{"\n"}'
oc get Elasticsearch elasticsearch -o jsonpath='{.items[*]}{"state: "}{.spec.managementState}{"\n"}'
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
### podman
```sh
# run test fluentD
podman run -p 8888:8888 -ti --name fluflu --hostname fluflu --rm -v /home/ts/git_repositories/work/openshift/oshi/logging/etc:/fluentd/etc -v /home/ts/git_repositories/work/openshift/oshi/logging/logs:/logs -v /home/ts/git_repositories/work/openshift/oshi/logging/systemd:/run/log/journal quay.io/dedtom/fluflu:latest fluentd -c /fluentd/etc/fluent.conf
```
### LOG FLOW within kubernetes
The configuration in the directory for Fluentd / td-agent is used
to watch changes to Docker log files. The kubelet creates symlinks that
capture the pod name, namespace, container name & Docker container ID
to the docker logs for pods in /var/log/containers directory on the host.
If running this fluentd configuration in a Docker container, the /var/log
directory should be mounted in the container.

**Example**  
A line in the Docker log file might look like this JSON:
```json
{"log":"2014/09/25 21:15:03 Got request with path wombat\n",
 "stream":"stderr",
  "time":"2014-09-25T21:15:03.499185026Z"}
```
The time_format specification below makes sure we properly
parse the time format produced by Docker. This will be
submitted to Elasticsearch and should appear like:
$ curl 'http://elasticsearch-logging.default:9200/_search?pretty'
```json
{
     "_index" : "logstash-2014.09.25",
     "_type" : "fluentd",
     "_id" : "VBrbor2QTuGpsQyTCdfzqA",
     "_score" : 1.0,
     "_source":{"log":"2014/09/25 22:45:50 Got request with path wombat\n",
                "stream":"stderr","tag":"docker.container.all",
                "@timestamp":"2014-09-25T22:45:50+00:00"}
   },
```
The Kubernetes fluentd plugin is used to write the Kubernetes metadata to the log
record & add labels to the log record if properly configured. This enables users
to filter & search logs on any metadata.
For example a Docker container's logs might be in the directory:
```conf
 /var/lib/docker/containers/997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b

and in the file:

 997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b-json.log
```
where 997599971ee6... is the Docker ID of the running container.
The Kubernetes kubelet makes a symbolic link to this file on the host machine
in the /var/log/containers directory which includes the pod name and the Kubernetes
container name:
```conf
   synthetic-logger-0.25lps-pod_default_synth-lgr-997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b.log
   ->
   /var/lib/docker/containers/997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b/997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b-json.log
```
The /var/log directory on the host is mapped to the /var/log directory in the container
running this instance of Fluentd and we end up collecting the file:
```conf
  /var/log/containers/synthetic-logger-0.25lps-pod_default_synth-lgr-997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b.log

This results in the tag:

 var.log.containers.synthetic-logger-0.25lps-pod_default_synth-lgr-997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b.log

```
The Kubernetes fluentd plugin is used to extract the namespace, pod name & container name
which are added to the log message as a kubernetes field object & the Docker container ID
is also added under the docker field object.
The final tag is:
```conf
  kubernetes.var.log.containers.synthetic-logger-0.25lps-pod_default_synth-lgr-997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b.log
```
And the final log record look like:
```json
{
  "log":"2014/09/25 21:15:03 Got request with path wombat\n",
  "stream":"stderr",
  "time":"2014-09-25T21:15:03.499185026Z",
  "kubernetes": {
    "namespace": "default",
    "pod_name": "synthetic-logger-0.25lps-pod",
    container_name: "synth-lgr"
  },
  "docker": {
    "container_id": "997599971ee6366d4a5920d25b79286ad45ff37a74494f262e3bc98d909d0a7b"
  }
}
```
This makes it easier for users to search for logs by pod name or by
the name of the Kubernetes container regardless of how many times the
Kubernetes pod has been restarted (resulting in a several Docker container IDs).

### log file struct on FS
```sh
eventrouter-5dc5c565cd-dw7tj_openshift-logging_kube-eventrouter-ae666e925d23df257f2360c6bcadc1257a0913b2d98f377d9919085a71812bcf.log -> /var/log/pods/openshift-logging_eventrouter-5dc5c565cd-dw7tj_bf80aa43-5359-48fc-a4f1-9921569a4c43/kube-eventrouter/0.log
```
**nameOfPod_nameOfNamespace_nameOfContainer-hash.log**  

### Prometheus metrics
```sh
# all records for 60min
sort_desc(sum (increase(cluster_logging_collector_input_record_total[60m])))
# all records group by tag for 60min
sort_desc(sum by (tag) (increase(cluster_logging_collector_input_record_total[60m])))
# top 10
topk(10,sort_desc(sum by (tag) (rate(cluster_logging_collector_input_record_total[60m]))))
#grafana messages per second processed messages
sum by (msg_source) (rate(cluster_logging_collector_processed_record_total[$__range]))

```
