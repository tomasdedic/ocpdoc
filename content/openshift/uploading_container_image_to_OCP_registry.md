---
title: Uploading local container images to OCP registry
date: 2020-02-01
author: Tomas Dedic
description: "Upload local container image to OCP registry"
lead: ""
categories:
  - "OpenShift"
tags:
  - "OCP"
---

```sh
#!/bin/bash

# Define constants
set registry_namespace openshift-image-registry
set registry_svc image-registry
set LOCAL_PORT 5000



# Get port where the remote registry is on
registry_port=$(oc get svc $registry_svc -n $registry_namespace -o jsonpath='{.spec.ports[0].port}')
set registry_port (oc get svc $registry_svc -n $registry_namespace -o json| jq '.spec.ports[0].port')

# Get object that we'll port forward to
port_fwd_obj=$(oc get pods -n $registry_namespace | awk '/^image-registry-/ {print $1}' )
set port_fwd_obj (oc get pods -n $registry_namespace | awk '/^image-registry-/ {print $1}')

# Do port forwarding on the needed pod
oc --loglevel=9 port-forward "$port_fwd_obj" -n "$registry_namespace" "$LOCAL_PORT:$registry_port" > pf.log 2>&1 &

port_foward_proc=$!
echo "The process spawned is $port_foward_proc"

# Get token for kubeadmin user
oc login -u kubeadmin -p "$(cat ~/openshift-dev-cluster/auth/kubeadmin-password)"

# Use token to log in with docker
docker login -u "kubeadmin" -p "$(oc whoami -t)" localhost:5000
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

