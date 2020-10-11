---
title: "Základní definice RBAC, úprava postinstalačních oprávnění"
date: 2020-10-08 
author: Tomas Dedic
description: "SANDBOX"
lead: "Základní postinstalační RBAC model, úpravy defaultních oprávnění"
categories:
  - "Openshift"
tags:
  - "RBAC"
toc: true
autonumbering: true
---
## ÚPRAVY DEFAULT NASTAVENÍ pro AUTHENTICATED_USER
Po přihlášení jsou uživateli automaticky přiřazeny tyto virtuální skupiny:
```sh
system:authenticated  Automatically associated with all authenticated users.
system:authenticated:oauth  Automatically associated with all users authenticated with an OAuth access token.
system:unauthenticated Automatically associated with all unauthenticated users.
```
```sh
# clusterrole prirazene skupine system:authenticated, system:unauthenticated, system:authenticated:oauth
oc get clusterrolebindings -o json |jq -r \
'.items[]| select(.subjects[].name| contains("system:authenticated")) |{roleRef_kind: .roleRef.kind, roleRef_name:.roleRef.name,subject_kind:.subjects[].kind,subject_name:.subjects[].name}'
oc get clusterrolebindings -o json| jq -r '.items[]| select(.subjects[].name| contains("system:authenticated")) | .metadata.name'
```
**system:authenticated:oauth** má ale právo vytvářet projekty a to bych rád odstranil 
```sh
oc get clusterrolebindings -o json| jq -rj '.items[]| select(.subjects[].name| contains("system:authenticated")) | {clusterrole:.roleRef.name,clusterrolebinging:.metadata.name}'
oc get clusterrolebindings -o json| jq -r '.items[]| select(.subjects[].name| contains("system:authenticated")) | .roleRef.name'|xargs oc get clusterrole -o yaml
```
upravíme tedy CRB **self-provisioners**  
a CRB **console-extension-reader**

> Zatím necháme možnost dostat se do konzole (pro testovací účely) ale pouze s právy get,list.watch

## SKUPINA pro CLUSTERADMINS
```yaml
 # pridam prava pro skupinu v tokenu

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: clusteradmin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: "111980ba-31f2-499d-b021-6d90b684ba54"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

V JWT tokenu sice group mame ale v provisioningu do OCP se neprojeví a uživatel nemá práva přijatá z tokenu.\
Práva získá až po manuálním přiřazení do skupiny.
```yaml
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: 111980ba-31f2-499d-b021-6d90b684ba54
users:
  - tdedic@mspassporttrask.onmicrosoft.com
```


