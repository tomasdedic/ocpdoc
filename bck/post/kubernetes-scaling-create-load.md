---
title: Kubernetes LOAD service on Docker container
date: 2019-03-11
author: Tomas Dedic
description: "create LOAD service on docker image to serve on GET request"
thumbnail: "img/45bc0788acb68519f8647b61fb08f35fb297332e_m.jpg" # Optional, thumbnail
lead: "create LOAD service on docker image to serve on GET request"
disable_comments: true # Optional, disable Disqus comments if true
authorbox: false # Optional, enable authorbox for specific post
toc: false # Optional, enable Table of Contents for specific post
mathjax: false # Optional, enable MathJax for specific post
categories:
  - "Kubernetes"
  - "Docker"
  - "Scaling"
tags:
  - "Kubernetes"
  - "GKE"
  - "Docker"
  - "Scaling"
menu: side # Optional, add page to a menu. Options: main, side, footer
sidebar: true
draft: false
---
Service to generate load on all selector pods in GKE. Main reason is to generate homogenous load for HPA (horizntal pod autoscaling) metrics with showcase as Prometheus/Grafana operator.

Kubernetes LOAD service on Docker container
https://github.com/msoap/shell2http

na docker image tomcat běží 3 služby generující load

```bash
shell2http -port 18080 /load "$TRASK_HOME/loadgenerator/runnc.sh" \
/ip "$TRASK_HOME/loadgenerator/runinfo.sh" \
/load1 "$TRASK_HOME/loadgenerator/runnc.sh 1" \
/load2 "$TRASK_HOME/loadgenerator/runnc.sh 2" &
```
+ /load  
	pustí 10 instancí (yes > /dev/null) s timeout 300-370 s
+ /load1  
	pustí 1 instancí (yes > /dev/null) s timeout 300-370 s
+ /load2  
	pustí 2 instancí (yes > /dev/null) s timeout 300-370 s

deployment bude nascalován jako:
```bash
kubectl autoscale deployment tomcat-deployment --min=1 --max=4 --cpu-percent=20
```

pro vyvolání zátěže na jednotlivých kontejnerech provedeme něco takového:
```bash
for pod in $(kubectl get pod --selector="app=tomcat" --output jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}") 
do
	printf "%s\n" "POD: $pod"
	printf "%s\n" "Forwarding from 127.0.0.1:18080 -> 18080"
	kubectl port-forward $pod 18080 >/dev/null &
	FORWARD_PID=$!
	#echo $FORWARD_PID
	sleep 7
	echo "======POD INFO======"
	curl http://127.0.0.1:18080/load
	#curl http://127.0.0.1:18080/load1
	echo "===================="
	sleep 2
	kill -INT $FORWARD_PID 
  #kill -9 $FORWARD_PID 1>&2>/dev/null
done
```

pro smazání autoscalingu:
```bash
kubectl delete hpa tomcat-deployment
horizontalpodautoscaler.autoscaling "tomcat-deployment" deleted
```
vizualizace:

```bash
kubectl port-forward service/prometheus-operator-grafana 4444:80 --namespace=monitoring
kubectl port-forward service/prometheus-operator-prometheus 5555:9090 --namespace=monitoring
```
