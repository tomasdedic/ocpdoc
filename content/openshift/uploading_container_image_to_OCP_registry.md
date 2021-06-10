---
title: Uploading local container images to OCP registry
date: 2020-02-01
author: Tomas Dedic
description: "Upload local container image to OCP registry"
lead: ""
categories:
  - "OpenShift"
tags:
  - "SNIPPETS"
toc: true
---

## PORT FORWARD
```sh
#!/bin/bash

# Define constants
registry_namespace=openshift-image-registry
registry_svc=image-registry
LOCAL_PORT=5000



# Get port where the remote registry is on
registry_port=$(oc get svc $registry_svc -n $registry_namespace -o jsonpath='{.spec.ports[0].port}')

# Get object that we'll port forward to
port_fwd_obj=$(oc get pods -n $registry_namespace | awk '/^image-registry-/ {print $1}'|tail -n 1)

# Do port forwarding on the needed pod
oc --loglevel=9 port-forward "$port_fwd_obj" -n "$registry_namespace" "$LOCAL_PORT:$registry_port" > pf.log 2>&1 &

port_forward_proc=$!
echo "The process spawned is $port_foward_proc"

# Use token to log in with docker
podman login -u "user" -p "$(oc whoami -t)" localhost:5000
# ale nas registry bude insecure TLS neni pro localhost
sudo vim /etc/containers/registries.conf
# pridat nebo upravit sekci
  [registries.insecure]
  registries = ['localhost:5000']l
```
This allows you to use localhost:5000 as an endpoint to upload your images towards your clusters image registry. Note that you’ll need to specify the specific openshift “project” as part of the path when you’re uploading images.

Lets say, for instance, that you want to upload the image my-image, and you have access to the project default. You’ll do:

docker push localhost:5000/default/my-image:latest
Note when you want to use your new image in an application, you must replace localhost:5000 with image-registry.openshift-image-registry.svc:5000, since that’s the URL that OpenShift makes available.

So, you’ll have something as:
```yaml
...
    spec:
      containers:
        ...
        image: image-registry.openshift-image-registry.svc:5000/default/my-image:latest
        imagePullPolicy: Always
```

## EXPOSE as ROUTE

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: public-routes
  namespace: openshift-image-registry
spec:
  host: ocr.apps.oaz-dev.ocp4.azure.sudlice.cz
  tls:
    termination: reencrypt
  to:
    kind: Service
    name: image-registry
    weight: 100
  wildcardPolicy: None
```
or
```sh
# edit imageregistry operator
oc edit configs.imageregistry.operator.openshift.io/cluster
# add
spec:
  routes:
    - name: public-routes
      hostname: ocr.apps.oaz-dev.ocp4.azure.sudlice.cz
```
```sh
podman tag docker.io/bitnami/zookeeper:3.6.2-debian-10-r37 ocr.apps.oaz-dev.ocp4.azure.sudlice.cz/nifi/zookeeper:3.6.2-debian-10-r37
podman login -u $(oc whoami) -p $(oc whoami -t) ocr.apps.oaz-dev.ocp4.azure.sudlice.cz
podman push ocr.apps.oaz-dev.ocp4.azure.sudlice.cz/nifi/zookeeper:3.6.2-debian-10-r37
```
**pozor pro image v deploymentu je potreba se odkazovat takto nebo upravit secret default-dockercfg, nebo pridat pull secret**
```sh
# dockercfg pro servisni ucet default ktery bude delat deploy obsahuje pouze tyto tri registry
yq eval .data.\".dockercfg\" <(oc get secrets default-dockercfg-2gv2z -o yaml)|base64 -d|jq keys
[
  "172.30.4.159:5000",
  "image-registry.openshift-image-registry.svc.cluster.local:5000",
  "image-registry.openshift-image-registry.svc:5000"
]
```

```yaml
# deploymentu nadefinujeme takhle
...
    spec:
      containers:
        ...
        image: image-registry.openshift-image-registry.svc:5000/default/my-image:latest
        imagePullPolicy: Always
```


