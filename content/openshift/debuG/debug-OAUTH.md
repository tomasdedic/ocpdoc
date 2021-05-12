---
title: "Authentication operator degraded "
date: 2020-07-06 
author: Tomas Dedic
description: "Cannot login into cluster, auth operator in degraded STATE"
lead: "DEBUG"
categories:
  - "Openshift"
tags:
  - "OCP"
  - "DEBUG"
---
Nejde se zalogovat prez konzoli. Authentication operator je ve stavu **Degraded**. 
### Authentication and Authentication Operator
```sh
# cluster operator
oc get co 
# operator logs 
set ns openshift-authentication-operator;oc logs -n "$ns" (oc get pods -n "$ns" -o name)
# warning and errors
set ns openshift-authentication-operator;oc logs -n "$ns" (oc get pods -n "$ns" -o name)|grep -E "[W,E][[:digit:]]{4}"

  OAuthClientsDegraded: the server is currently unable to handle the request (get oauthclients.oauth.openshift.io openshift-browser-client) 
  to RouteStatusDegraded: the server is currently unable to handle the request (get routes.route.openshift.io oauth-openshift)

  OAuthClientsDegraded: the server is currently unable to handle the request (get oauthclients.oauth.openshift.io openshift-browser-client)
  failed handling the route: the server is currently unable to handle the request (get routes.route.openshift.io oauth-openshift)
  lookup oauth-openshift.apps.toshi44.sudlice.org on 172.30.0.10:53: read udp 10.130.0.215:56716->172.30.0.10:53: i/o timeout
  failed with: the server is currently unable to handle the request (post oauthclients.oauth.openshift.io)
```
```sh
# curl na oauth endpoint vraci timeout pri kazdem x-tem pokusu
curl -k https://oauth-openshift.apps.oaz-dev.azure.sudlice.cz/oauth/token/display
```
```sh
oc get route -A|grep oauth
  Error from server (ServiceUnavailable): the server is currently unable to handle the request (get routes.route.openshift.io)
```

```sh
stern -n openshift-authentication oauth|grep -E "E[[:digit:]]{4}"
# try to delete all
for i in (oc get pods -o name --selector app=oauth-openshift -n openshift-authentication);
  oc delete $i -n openshift-authentication;
  end
```
### ETCD
seems to be quite happy
```sh
stern -n openshift-etcd-operator etcd|grep -E "[W,E][[:digit:]]{4}"
```
ale openshift-etcd-operator(D: etcd-operator) si stale stezuje  
**unhealthy members: toshi44-l9tcd-master-1,toshi44-l9tcd-master-0,toshi44-l9tcd-master-2**  
kubeAPI ma velkou latenci a to muze klidne s nezdravosti etcd souviset
```sh
etcdctl member list -w table
  24dd89393f91e72e, started, toshi44-l9tcd-master-1, https://10.4.0.4:2380, https://10.4.0.4:2379
  3672e44507206aee, started, toshi44-l9tcd-master-0, https://10.4.0.6:2380, https://10.4.0.6:2379
  d9eaeebdf47b1d9a, started, toshi44-l9tcd-master-2, https://10.4.0.7:2380, https://10.4.0.7:2379

etcdctl endpoint health --cluster
  https://10.4.0.6:2379 is healthy: successfully committed proposal: took = 10.984237ms
  https://10.4.0.7:2379 is healthy: successfully committed proposal: took = 17.462818ms
  https://10.4.0.4:2379 is healthy: successfully committed proposal: took = 22.100276ms

# get events
oc get events --all-namespaces -o json|jq -r '.items[]|{obj: .involvedObject.name,namespace: .involvedObject.namespace,message: .message,last: .lastTimestamp}'|jq -r 'select (.namespace |contains("etcd"))'
```
nedari se mi prijit na to co se etcd nelibi


### get EVENTS
```sh
oc get events --all-namespaces -o json \
|jq -r '.items[]|{obj: .involvedObject.name,namespace: .involvedObject.namespace,message: .message,last: .lastTimestamp}'\
|jq -r 'select (.namespace |contains("sudlice")|not)'\
|jq -r 'select (.namespace | contains("authentication"))'
```
```json
{
  "obj": "authentication-operator",
  "namespace": "openshift-authentication-operator",
  "message": "Status for clusteroperator/authentication changed: Degraded message changed from \"\" to \"WellKnownEndpointDegraded: failed to GET well-known https://10.4.0.4:6443/.well-known/oauth-authorization-server: net/http: TLS handshake timeout\"",
  "last": "2020-07-07T08:46:38Z"
}
{
  "obj": "authentication-operator",
  "namespace": "openshift-authentication-operator",
  "message": "Status for clusteroperator/authentication changed: Degraded message changed from \"WellKnownEndpointDegraded: failed to GET well-known https://10.4.0.4:6443/.well-known/oauth-authorization-server: net/http: TLS handshake timeout\" to \"\"",
  "last": "2020-07-07T08:46:41Z"
}
{
  "obj": "authentication-operator",
  "namespace": "openshift-authentication-operator",
  "message": "Status for clusteroperator/authentication changed: Degraded message changed from \"\" to \"RouteHealthDegraded: failed to GET route: dial tcp: lookup oauth-openshift.apps.toshi44.sudlice.org on 172.30.0.10:53: read udp 10.130.0.215:55146->172.30.0.10:53: i/o timeout\"",
  "last": "2020-07-07T06:00:35Z"
}
```
### Openshift API server and API resources
every three runs 
```sh
oc api-resources

  error: unable to retrieve the complete list of server apis: project.openshift.io/v1: the server is currently unable to handle the request,  
  route.openshift.io/v1: the server is currently unable to handle the request,  
  security.openshift.io/v1: the server is currently unable to handle the request,  
  template.openshift.io/v1: the server is currently unable to handle the request,  
  user.openshift.io/v1: the server is currently unable to handle the request  
```
```sh
stern -n openshift-apiserver apiserver
 # common error
  http: TLS handshake error from 10.129.0.1:4963
```
### DNS 
problem se castecne vyresil restartem dns ale neda se tomu rozhodne rikat celkove reseni. Zaroven se mi nezda ze by byl problem v DNS (samozrejme nejake problemy s resolvingem se z logu vycist daji)
```sh
set ns openshift-dns; for i in (oc get pods -n "$ns" -o name ); oc delete -n "$ns" $i; end
```
### PackageServer
package server ma problemy a zpusobuje obcasnou nedostupnost API  
tyka se to operator-lifecycle-manager-packageserver
```log
packageserver-5df56b8c8-xz257 packageserver I0707 11:13:24.539873       1 log.go:172] http: TLS handshake error from 10.129.0.1:50886: remote error: tls: bad certificate
```
skusime je procistit
```sh
set ns openshift-operator-lifecycle-manager; set sel "app=packageserver"; for i in (oc get pods -n "$ns" --selector $sel -o name ); oc delete -n "$ns" $i; end
```
## HODNOCENI
zda se mi ze za celym problemem se nachazi castecna nedostupnost OpenShift API serveru, kdy pri jenom ze 3 requestu probehne timeout. Otazka je co to zpusobuje.
```sh
stern -n openshift-apiserver apiserver
apiserver-6756b4f77b-fq2sp openshift-apiserver I0707 12:35:04.255724       1 log.go:172] http: TLS handshake error from 10.129.0.1:48138: EOF
```
