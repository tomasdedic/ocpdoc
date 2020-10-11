### list machineconfig version
```sh
oc get nodes -o json|jq -r '.items[].metadata.annotations|{name:.["machine.openshift.io/machine"],current:.["machineconfiguration.openshift.io/currentConfig"],desired:.["machineconfiguration.openshift.io/desiredConfig"],state:.["machineconfiguration.openshift.io/state"]}'
# s custom-columns
oc get nodes -o custom-columns='NAME:metadata.name,CURRENT:metadata.annotations.machineconfiguration\.openshift\.io/currentConfig,DESIRED:metadata.annotations.machineconfiguration\.openshift\.io/desiredConfig,STATE:metadata.annotations.machineconfiguration\.openshift\.io/state'
```


### grep and keep first line (header)
```sh
oc get co| sed -n '1p;/openshift-apiserver/p'
```
### fast cluster operator grep
oc get co | grep -v "True.*False.*False"
### use SS to list all tcp4 connections 
while true;do sleep 2;ss -nt4pe -o state established >sslog;done
The ss program is using a sock_diag(7) netlink socket to retrieve information about sockets. But the sock_diag interface doesn't support a "monitor"/watching/listening mode, as rtnetlink(7) does. You can only do queries via a sock_diag socket.
### use tcpdump on a NODE
```sh
oc debug node/<nodename>
 # get container pid
chroot /host crictl ps |grep openshift-apiserver
chroot /host crictl inspect 5c831210d2594 |grep '"pid":'
 # nsenter run program in different namespaces
nsenter -n -t $pid -- ip a
 #pouziva se pri debugu, jde pustit rucne pokud pouzijeme SSH
/usr/bin/toolbox
nsenter -n -t $pid -- tcpdump -D
nsenter -n -t $pid -- tcpdump -nn -i ${INTERFACE} -w /host/tmp/${HOSTNAME}_$(date +\%d_%m_%Y-%H_%M_%S-%Z).pcap ${TCPDUMP_EXTRA_PARAMS}
nsenter -n -t 2205119 -- tcpdump -nn -i eth0 "tcp port 8443" -w /host/tmp/tcpdump.pcap
#copy output to localhost
oc get pods  #oaz-dev-tnhr6-master-2-debug
oc cp oaz-dev-tnhr6-master-2-debug:/host/tmp/tcpdump.pcap tcpdump.pcap
```

### list all certs in cert bundle
```sh
openssl crl2pkcs7 -nocrl -certfile ca.crt | openssl pkcs7 -print_certs -noout
openssl crl2pkcs7 -nocrl -certfile ca.crt | openssl pkcs7 -print_certs -text -noout
```
### get all secret decoded cloud-credentials scope
```sh
# get all secret decoded cloud-credentials scope
# oc get secret -n openshift-machine-api azure-cloud-credentials
 for i in $(oc get secret -n openshift-machine-api azure-cloud-credentials -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n openshift-machine-api azure-cloud-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 
# oc get secret -n kube-system azure-credentials
 for i in $(oc get secret -n kube-system azure-credentials -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n kube-system azure-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 

 for i in $(oc get secret -n openshift-image-registry installer-cloud-credentials  -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n openshift-image-registry installer-cloud-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 
 # tyhle dva credentials by se meli rovnat
 # a meli by se rovnat s 
  ~/.azure/osServicePrincipal.json

oc logs -n openshift-cloud-credential-operator deploy/cloud-credential-operator
```

### delete all pods in namespace by selector
```sh
# delete all pods in namespace by selector
set ns openshift-dns; for i in (oc get pods -n "$ns" -o name ); oc delete -n "$ns" $i; end

# events filtering
oc get events --all-namespaces -o json|jq -r '.items[]|{obj: .involvedObject.name,namespace: .involvedObject.namespace,message: .message,last: .lastTimestamp}'
 # with not contain csas string
oc get events --all-namespaces -o json|jq -r '.items[]|{obj: .involvedObject.name,namespace: .involvedObject.namespace,message: .message,last: .lastTimestamp}'|jq -r 'select (.namespace |contains("csas")|not)'
```
### ETCD related
#### oc get logs for ETCD
```sh
# zsh specific, nepouziva \n na worldsplit takze bud setopt setopt SH_WORD_SPLIT
# nebo {=pods} jinak ta se ta loopa vykona jen jednou
pods=$(oc get pods -n openshift-etcd -l etcd -o name)
for i in ${=pods};do oc logs -n openshift-etcd $i -c etcd |grep 'embed: rejected connection';done
```
#### bootstrap ETCD node obcas neni vyřazen po installu
```sh
# etcd status
oc get etcd -o=json|jq '.items[].status.conditions[]|select(.type=="EtcdMembersAvailable").message'
oc get etcd -o=json|jq '.items[].status.conditions[]|select(.type=="NodeInstallerProgressing")|.reason,.message'
# Force a new revision on etcd:
oc patch etcd cluster -p='{"spec": {"forceRedeploymentReason": "recovery-'"$( date --rfc-3339=ns )"'"}}' --type=merge
Verify the nodes are at the latest revision:
oc get etcd '-o=jsonpath={range .items[0].status.conditions[?(@.type=="NodeInstallerProgressing")]}{.reason}{"\n"}{.message}{"\n"}'
```
```sh
etcd-operator-598fdf5b6-mzljn operator W0716 14:03:52.271545 1 clientconn.go:1208] grpc: addrConn.createTransport failed to connect to {https://10.3.0.8:2379 <nil> 0 <nil>}. Err :connection error: desc = "transport: Error while dialing dial tcp 10.3.0.8:2379: operation was canceled". Reconnecting...

This IP (10.3.0.8) is an IP address of bootstrap node, which has been removed during installation, but some OCP configuration keeps this setting.
We have solved this issue by removing annotaion "alpha.installer.openshift.io/etcd-bootstrap" from "openshift-etcd:endpoints/host-etcd-X" endpoint. After this change no more error about bootstrap etcd member.
```
### NODES related
```sh
# nodes
kubectl get nodes -o json|jq -r '.items[].status.addresses[]|select(.type=="InternalIP").address'
kubectl patch svc loadbalancer -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```
### oc explain
```sh
# explain with API
oc get crd
oc get api-version
oc explain networks --api-version='operator.openshift.io/v1' --recursive=true
```
### install debug tools on a node
```sh
 # debug deploy by creating debug pod with rhel-tools
oc debug -t deployment/foobar-dev-bar-helm-guestbook --image registry.access.redhat.com/rhel7/rhel-tools
 # debug inside coreOS node
/usr/bin/toolbox
install new:
dnf install package
```
### security context constraints
pokud ma NS label openshift.io/run-level: "1", tak se SCC vubec neuplatni a pod se klidne spusti pod rootem

### oc env
```sh
# env variables for object
oc set env ds/fluentd --list
# resource volumes
oc set volumes ds/fluentd
```

### create serviceaccount, get token and login
```sh
# get token from serviceaccount
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sadmin
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
 name: sadmin-admin-bind
roleRef:
 kind: ClusterRole
 name: cluster-admin
 apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: sadmin
    namespace: default

oc get secret (oc get serviceaccount sadmin -o json|jq -r '.secrets[0]["name"]') -o json|jq -r '.data.token' >token
oc login --token=(cat token|base64 -d)
```
On a pod service account is stored in:  
**/run/secrets/kubernetes.io/serviceaccount/token**
