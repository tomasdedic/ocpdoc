---
title: "User Namespaces with Openshift using CRIO"
date: 2021-06-10 
author: Tomas Dedic
description: "Test user namespaces (root inside user namespace, standart user outside) in Openshift with Cri-O 1.20"
lead: "run baby run, outrun my gun"
categories:
  - "Openshift"
tags:
  - "Config"
thumbnail: "img/usernamespaces.jpg"
---
### REF
[https://asciinema.org/a/351396](https://asciinema.org/a/351396)  
[https://frasertweedale.github.io/blog-redhat/posts/2020-12-01-openshift-crio-userns.html](https://frasertweedale.github.io/blog-redhat/posts/2020-12-01-openshift-crio-userns.html)  
[https://opensource.com/article/18/12/podman-and-user-namespaces](https://opensource.com/article/18/12/podman-and-user-namespaces)  
[https://www.openshift.com/blog/a-guide-to-openshift-and-uids](https://www.openshift.com/blog/a-guide-to-openshift-and-uids)  
[https://opensource.com/article/19/2/how-does-rootless-podman-work](https://opensource.com/article/19/2/how-does-rootless-podman-work)  
[https://frasertweedale.github.io/blog-redhat/posts/2020-12-01-openshift-crio-userns.html](https://frasertweedale.github.io/blog-redhat/posts/2020-12-01-openshift-crio-userns.html)  
[https://cri-o.io](https://cri-o.io)  

Tak jako první věc uděláme standartní deploy bez jakýchkoliv úprav, pod uživatelem desmond kterému dáme pouze práva edit nad NS

## DefaultDeploy
```yaml
➤ cat deploybusybox-normal.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busy-normal
annotations:
  openshift.io/scc: restricted
spec:
  containers:
  - name: busy-normal
    image: busybox
    command: ["sleep", "3601"]
```
```sh
➤ oc create user desmond
➤ oc adm policy add-role-to-user edit desmond
➤ oc --as desmond apply -f deploybusybox-normal.yaml
➤ oc get pods busy-normal -o json| jq -rj '.status.containerStatuses[0].containerID,"\n",.spec.nodeName,"\n"'
  cri-o://28573906ef64e4c6f02b84e92917fe714ba01c1183c7677ee526172c622367bc
  oshi43-f7fsr-worker-westeurope2-p7g6r
➤ crictl inspect 28573906ef64e4c6f02b84e92917fe714ba01c1183c7677ee526172c622367bc| jq '.info.pid'
➤ cat /proc/1407303/uid_map
  0          0 4294967295
# procesy běží jako uid 0 (první záznam) ve svém namespacu a uid 0 (druhý záznam) mimo něj v parent NS - uživatel root bude pořád root

➤ lsns -t user
  NS TYPE  NPROCS PID USER COMMAND
        4026531837 user     284   1 root /usr/lib/systemd/systemd --switched-root --system --deserialize 17
# no process running in user namespace
➤ oc rsh busy-normal
  ~ $ id
  uid=1000800000(1000800000) gid=0(root) groups=1000800000
# namespace definition
➤ oc get ns blaster -o jsonpath='{ .metadata.annotations}{"\n"}'
{"openshift.io/description":"","openshift.io/display-name":"","openshift.io/requester":"tdedic","openshift.io/sa.scc.mcs":"s0:c28,c22","openshift.io/sa.scc.supplemental-groups":"1000800000/10000","openshift.io/sa.scc.uid-range":"1000800000/10000"}
# on FS process is running as
➤ sh-4.4# cat /proc/1499053/status|grep -e Pid -e Uid -e Gid -e Tgid
Pid:    1499053
PPid:   1499042
Tgid:   1720096
Uid:    1000800000      1000800000      1000800000      1000800000
Gid:    0       0       0       0
# enter namespace and check files
nsenter -t 1720096 -m ls -la

```

## Deploy with userNamespace annotation
**Not working in Openshift 4.7**  
I checked RFE [0] [1] status and can see feature is completed in 4.8 and will be coming up with this version. We are expecting 4.8 to be released in Mid July.  


Uživatel který vytváří kontejner potřebuje SCC anyuid
```sh
➤ oc adm policy add-scc-to-user anyuid desmond
```
```yaml
➤ oc --as desmond apply -f deploybusybox-userns.yaml
➤ cat deploybusybox-userns.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busy-userns
  annotations:
    openshift.io/scc: restricted
    io.kubernetes.cri-o.userns-mode: "auto:size=65536;map-to-root=true"
spec:
  containers:
  - name: busy-userns
    image: busybox
    command: ["sleep", "3601"]
    securityContext:
      runAsUser: 0
      runAsGroup: 0
  securityContext:
    sysctls:
    - name: "net.ipv4.ping_group_range"
      value: "0 65535"
```
> net.ipv4.ping_group_range and user namespaces 
> The net.ipv4.ping_group_range sysctl defines the range of group IDs that are allowed to send ICMP Echo packets. Setting it to the full gid range allows ping to be used in rootless containers, without setuid or the CAP_NET_ADMIN and CAP_NET_RAW capabilities.
```sh
➤ crictl inspect b1d599757328c|jq .info.pid
➤ cat /proc/75526/uid_map
         0          0 429496729
# no mapping
 ➤ lsns -t user
        NS TYPE  NPROCS PID USER COMMAND
4026531837 user     211   1 root /usr/lib/systemd/systemd --switched-root --system --deserialize 17
# no processes in user namespace
➤ cat /etc/crio/crio.conf|grep allow_userns_annotation
```

## NEW runtimeClass to enable
```yaml
annotations:
    openshift.io/scc: restricted
    io.kubernetes.cri-o.userns-mode: "auto:size=65536;map-to-root=true"

cri-o file:
   [cri-o.runtime.runtimes.userns]
   runtime_path = "/usr/bin/runc"
   allowed_annotations = ["io.kubernetes.cri-o.userns-mode"]
Selec the runtime class in pod:
    runtimeClassName: userns
```
