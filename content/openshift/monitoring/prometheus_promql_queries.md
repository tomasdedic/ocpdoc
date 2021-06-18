---
title: "Prometheus PromQL"
date: 2021-06-17 
author: Tomas Dedic
description: "Prometheus usefull queries and failing forward with PromQL"
lead: "more to come"
categories:
  - "Openshift"
tags:
  - "Prometheus"
toc: true
thumbnail: "img/prometheus.jpg"
---
## FINDING PODS RESOURCE LIMITS
```sh
# Containers without CPU limits by namespace
sum by (namespace)(count by (namespace,pod,container)(kube_pod_container_info{container!=""}) unless sum by (namespace,pod,container)(kube_pod_container_resource_limits{resource="cpu"}))

# Containers without memory limits by namespace
sum by (namespace)(count by (namespace,pod,container)(kube_pod_container_info{container!=""}) unless sum by (namespace,pod,container)(kube_pod_container_resource_limits{resource="memory"}))

# Top 10 containers without CPU limits, using more CPU
topk(10,sum by (namespace,pod,container)(rate(container_cpu_usage_seconds_total{container!=""}[5m])) unless sum by (namespace,pod,container)(kube_pod_container_resource_limits{resource="cpu"}))

# Top 10 containers without memory limits, using more memory
topk(10,sum by (namespace,pod,container)(container_memory_usage_bytes{container!=""}) unless sum by (namespace,pod,container)(kube_pod_container_resource_limits{resource="memory"}))

# Use this query to find the containers whose CPU usage is close to its limits
(sum by (namespace,pod,container)(rate(container_cpu_usage_seconds_total{container!=""}[5m])) / sum by (namespace,pod,container)(kube_pod_container_resource_limits{resource="cpu"})) > 0.8

# Detecting containers with very tight memory limits
(sum by (namespace,pod,container)(container_memory_usage_bytes{container!=""}) / sum by (namespace,pod,container)(kube_pod_container_resource_limits{resource="memory"})) > 0.8

# Finding the right CPU limit, with the conservative strategy
max by (namespace,owner_name,container)((rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) * on(namespace,pod) group_left(owner_name) avg by (namespace,pod,owner_name)(kube_pod_owner{owner_kind=~"DaemonSet|StatefulSet|Deployment"}))

# Finding the right memory limit, with the conservative strategy
max by (namespace,owner_name,container)((container_memory_usage_bytes{container!="POD",container!=""}) * on(namespace,pod) group_left(owner_name) avg by (namespace,pod,owner_name)(kube_pod_owner{owner_kind=~"DaemonSet|StatefulSet|Deployment"}))

# Aggressive strategy
# We will select the quantile 99 as the limit. This will leave the 1% most consuming out of the limits. This is a good strategy if there are sparse anomalies or peaks that you do not want to support.

# Finding the right memory limit, with the aggressive strategy
quantile by (namespace,owner_name,container)(0.99,(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) * on(namespace,pod) group_left(owner_name) avg by (namespace,pod,owner_name)(kube_pod_owner{owner_kind=~"DaemonSet|StatefulSet|Deployment"}))

# Finding the right memory limit, with the aggressive strategy
quantile by (namespace,owner_name,container)(0.99,(container_memory_usage_bytes{container!="POD",container!=""}) * on(namespace,pod) group_left(owner_name) avg by (namespace,pod,owner_name)(kube_pod_owner{owner_kind=~"DaemonSet|StatefulSet|Deployment"}))
```

## FINDING CLUSTER/NODE overcommit
Normally, not all the containers will be consuming all their resources at the same time, so having an overcommit of 100% is ideal from a resource point of view. On the other hand, this will incur extra costs in infrastructure that will never be used.  

To better adjust the capacity of your cluster, you can opt for a conservative strategy, assuring that the overcommit is under 125%, or an aggressive strategy if you let the overcommit reach 150% of the capacity of your cluster.

```sh
# % memory overcommitted of the cluster
100 * sum(kube_pod_container_resource_limits{container!="",resource="memory"} ) / sum(kube_node_status_capacity_memory_bytes)

# % CPU overcommitted of the cluster
100 * sum(kube_pod_container_resource_limits{container!="",resource="cpu"} ) / sum(kube_node_status_capacity_cpu_cores)
```

It is also important to check the overcommit per node. An example of node overcommit can be a pod with a request of 2 CPUs and a limit of 8. That pod can be scheduled in a node with 4 cores, but as the pod has 8 cores as the limit, the overcommit in that node would be 8 – 4 = 4 cores.

```sh
# % memory overcommitted of the node
sum by (node)(kube_pod_container_resource_limits{container!=””,resource=”memory”} ) / sum by (node)(kube_node_status_capacity_memory_bytes)

# % CPU overcommitted of the node
sum by (node)(kube_pod_container_resource_limits{container!=””,resource=”cpu”} ) / sum by (node)(kube_node_status_capacity_cpu_cores)
```
