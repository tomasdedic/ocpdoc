**Původce: Objevily se problémy s přihlašováním. Všechny api-resources poskytovane openshift-api jsou částečně nedostupné.** 
Jelikož je problém objevuje jen na 1/3 podů, cluster je částečně funkční.Přihlašování dělám přez token jednoho z podů openshift-apiserver --> /run/secrets/kubernetes.io/serviceaccount/token

### Gather Informations
```sh
oc get proxy.config cluster -o yaml

  apiVersion: config.openshift.io/v1
  kind: Proxy
  spec:
    httpProxy: http://10.88.233.244:3128
    httpsProxy: http://10.88.233.244:3128
    noProxy: .cluster.local,.svc,127.0.0.1,172.30.0.0/16,api-int.oaz-dev.azure.csint.cz,etcd-0.oaz-dev.azure.csint.cz,etcd-1.oaz-dev.azure.csint.cz,etcd-2.oaz-dev.azure.csint.cz,localhost,10.88.233.192/28,10.88.233.32/27,.oaz-dev.azure.csint.cz,10.128.0.0/14
```
```sh
oc get clusteroperator
  NAME                                       VERSION                             AVAILABLE   PROGRESSING   DEGRADED   SINCE
  authentication                             4.6.0-0.nightly-2020-07-24-111750   True        False         True       5d19h
  image-registry                             4.6.0-0.nightly-2020-07-24-111750   True        False         True       6d20h
  monitoring                                 4.6.0-0.nightly-2020-07-24-111750   False       True          True       35h
  openshift-apiserver                        4.6.0-0.nightly-2020-07-24-111750   False       False         False      18h

# involved events
oc get events --all-namespaces -o json|jq -r '.items[]|{obj: .involvedObject.name,namespace: .involvedObject.namespace,message: .message,last: .lastTimestamp}'
oc get events -n openshift-apiserver-operator

# api resources
oc api-resources

  error: unable to retrieve the complete list of server APIs: 
  authorization.openshift.io/v1: the server is currently unable to handle the request,
  oauth.openshift.io/v1: the server is currently unable to handle the request,
  packages.operators.coreos.com/v1: the server is currently unable to handle the request,
  route.openshift.io/v1: the server is currently unable to handle the request,
  security.openshift.io/v1: the server is currently unable to handle the request

# log agregation
stern -n openshift-apiserver apiserver

  apiserver-hv5p5 openshift-apiserver I0524 22:17:43.670943       1 log.go:172] http: TLS handshake error from 10.131.0.1:45118: EOF
  apiserver-hv5p5 openshift-apiserver I0524 22:17:47.656841       1 log.go:172] http: TLS handshake error from 10.131.0.1:45152: EOF
  apiserver-hv5p5 openshift-apiserver I0524 22:17:57.658147       1 log.go:172] http: TLS handshake error from 10.131.0.1:45240: 

# kube-apiserver 
stern -n openshift-kube-apiserver kube-apiserver|grep -Eo "E[[:digit:]]{4}.*"

  E0805 05:01:25.907233      17 controller.go:114] loading OpenAPI spec for "v1.build.openshift.io" failed with: failed to retrieve openAPI spec, http error: ResponseCode: 503, Body: Error trying to reach service: 'net/http: TLS handshake timeout', Header: map[Content-Type:[text/plain; charset=utf-8] X-Content-Type-Options:[nosniff]]
  E0805 05:01:45.937641      17 controller.go:114] loading OpenAPI spec for "v1.image.openshift.io" failed with: failed to retrieve openAPI spec, http error: ResponseCode: 503, Body: Error trying to reach service: 'net/http: TLS handshake timeout', Header: map[Content-Type:[text/plain; charset=utf-8] X-Content-Type-Options:[nosniff]]


```
### Debug Description
#### 1. tcpdump on api-server pod
```sh
oc debug node/<nodename>
 # get container pid
chroot /host crictl ps |grep openshift-apiserver
chroot /host crictl inspect 5c831210d2594 |grep '"pid":'
 # nsenter run program in different namespaces
nsenter -n -t $pid -- ip a
nsenter -n -t 2205119 -- tcpdump -nn -i eth0 "tcp port 8443" -w /host/tmp/tcpdump.pcap
#copy output to localhost
oc get pods  #oaz-dev-tnhr6-master-2-debug
oc cp oaz-dev-tnhr6-master-2-debug:/host/tmp/tcpdump.pcap tcpdump.pcap
# and visualize in wireshark
```
Two errors occures in logs and their net stack errors:
{{< figure src="img/Screenshot_2020-07-30_14-04-29.png" title="EOF" >}}
**http: TLS handshake error from xxx: EOF**  
This means that while the server and the client were performing the TLS handshake, the server saw the connection being closed, aka EOF.
{{< figure src="img/Screenshot_2020-07-30_14-08-47.png" title="i/o timeout" >}}
**http: TLS handshake error from xxx: read tcp x.xxx.xxx.xxx:443->xxx:6742: i/o timeout**  
This means that while the server was waiting to read from the client during the TLS handshake, the client didn't send anything before closing the connection.

#### 2. netstat
oc rsh -n openshift-apiserver apiserver-hv5p5
  yum install net-tools
  netstat -nputw
  netstat -nputwc
   - z 10.131.0.1 prichazeji requesty a jsou ve stavu ESTABILISHED
   - nektere se objevi v chybach, zda se ze bude problem s timeoutem

#### 3. use SS to list all tcp4 connections 
from master node
```sh
while true;do sleep 2;ss -nt4pe -o state established >sslog;done
#find source ports in log
```
The ss program is using a sock_diag(7) netlink socket to retrieve information about sockets. But the sock_diag interface doesn't support a "monitor"/watching/listening mode, as rtnetlink(7) does. You can only do queries via a sock_diag socket.

#### 4. force restart api servers

```sh
# openshift-api
for i in (oc get pods -n openshift-apiserver -o name); oc delete -n openshift-apiserver $i;end
for i in (oc get pods -n openshift-sdn --selector app=sdn -o name); oc delete -n openshift-sdn $i;end
# openshift-kube-apiserver runs as static pod
# from masternode {kube-apiserver,kube-apiserver-check-endpoints}
crictl ps |grep kube-apiserver
crictl stop/start  UID
```
#### 5. delete podnetworkconnectivitycheck 
I have found some errors like routing to non-existing pods, delete will force to update.
```sh
oc scale --replicas 0 -n openshift-kube-apiserver-operator deployments/openshift-kube-apiserver-operator
oc scale --replicas 0 -n openshift-apiserver-operator deployments/openshift-apiserver-operator
oc delete -n openshift-kube-apiserver podnetworkconnectivitycheck --all
oc delete -n openshift-apiserver podnetworkconnectivitycheck --all
oc scale --replicas 1 -n openshift-kube-apiserver-operator deployments/openshift-kube-apiserver-operator
oc scale --replicas 1 -n openshift-apiserver-operator deployments/openshift-apiserver-operator
```

#### 6. curl API from different locations
Curl does not support CIDR in NO_PROXY "A comma-separated list of host names that shouldn't go through any proxy is set in ... NO_PROXY".

```sh
# openshift apiserver endpoints
oc get endpoints -n openshift-apiserver
  NAME   ENDPOINTS                                            AGE
  api    10.128.0.40:8443,10.129.0.28:8443,10.130.0.55:8443   11d
```
```sh
#kube apiservers
oc get pods -n openshift-kube-apiserver -o wide|sed -n '1p;/kube-apiserver/p'|awk '{print $1"  "$6"   "$7}'

  NAME                                   IP              NODE
  kube-apiserver-oaz-dev-tnhr6-master-0  10.88.233.196   oaz-dev-tnhr6-master-0
  kube-apiserver-oaz-dev-tnhr6-master-1  10.88.233.198   oaz-dev-tnhr6-master-1
  kube-apiserver-oaz-dev-tnhr6-master-2  10.88.233.200   oaz-dev-tnhr6-master-2
```
```ssh
oc rsh  -n openshift-kube-apiserver kube-apiserver-oaz-dev-tnhr6-master-0
for i in {10.128.0.40:8443,10.129.0.28:8443,10.130.0.55:8443}; do echo -e "https://$i/apis";curl -k https://$i/apis --header "Authorization: Bearer $TOKEN" --connect-timeout 10 ;echo;done

  https://10.128.0.40:8443/apis
  curl: (28) Operation timed out after 10001 milliseconds with 0 out of 0 bytes received
  
  https://10.129.0.28:8443/apis
  {
    "kind": "APIGroupList",
    "groups": []
  }
  https://10.130.0.55:8443/apis
  {
    "kind": "APIGroupList",
    "groups": []
  }
```
```sh
oc rsh  -n openshift-kube-apiserver kube-apiserver-oaz-dev-tnhr6-master-1
for i in {10.128.0.40:8443,10.129.0.28:8443,10.130.0.55:8443}; do echo -e "https://$i/apis";curl -k https://$i/apis --header "Authorization: Bearer $TOKEN" --connect-timeout 10 ;echo;done
https://10.128.0.40:8443/apis
{
  "kind": "APIGroupList",
  "groups": []
}
https://10.129.0.28:8443/apis
{
  "kind": "APIGroupList",
  "groups": []
}
https://10.130.0.55:8443/apis
curl: (28) Operation timed out after 10001 milliseconds with 0 out of 0 bytes received
```
```sh
oc rsh  -n openshift-kube-apiserver kube-apiserver-oaz-dev-tnhr6-master-2
for i in {10.128.0.40:8443,10.129.0.28:8443,10.130.0.55:8443}; do echo -e "https://$i/apis";curl -k https://$i/apis --header "Authorization: Bearer $TOKEN" --connect-timeout 10 ;echo;done
https://10.128.0.40:8443/apis
{
  "kind": "APIGroupList",
  "groups": []
}
https://10.129.0.28:8443/apis
{
  "kind": "APIGroupList",
  "groups": []
}
https://10.130.0.55:8443/apis
curl: (28) Operation timed out after 10001 milliseconds with 0 out of 0 bytes received
```
