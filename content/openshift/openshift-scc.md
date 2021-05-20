---
title: "Openshift SecurityContextConstaints short howto"
date: 2021-05-13 
author: Tomas Dedic
description: "SCC"
lead: "busy"
categories:
  - "Openshift"
tags:
  - "Deploy"
---

By default pods use the Restricted SCC. The pod's SCC is determined by the User/ServiceAccount and/or Group. Then, you also have to consider that a SA may or may not be bound to a Role, which can set a list of available SCCs.

**We have two options how to grant a custom SCC**
```sh
# grant scc to user
oc adm policy add-scc-to-user privileged -z default #service account default

# it will create clusterrolebinding/clusterrole as
oc adm policy add-scc-to-user privileged -z default --dry-run=client -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  creationTimestamp: null
  name: system:openshift:scc:privileged
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:privileged
subjects:
- kind: ServiceAccount
  name: default
  namespace: nifi
```
or by edit scc
```yaml
oc edit scc privileged

users:
- system:serviceaccount:nifi:default
```
```sh
# get pod's SA name
oc get pods $podName -o jsonpath='{.metadata.annotations.openshift\.io/scc}{"\n"}'

# list service accounts that can use a particular SCC
# if you add user by editing scc yaml, it will not be listed
oc adm policy who-can use scc privileged

# list users added by editing scc CR
oc get scc nifi-scc -o jsonpath='{.users}{"\n"}'

# check roles and role bindings of your SA
# you need to look at rules.apiGroups: security.openshift.io
oc get rolebindings -o wide
oc get role $ROLE_NAME -o yaml
```
