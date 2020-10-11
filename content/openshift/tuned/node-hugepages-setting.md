## Redis si stěžuje na nastavení huge pages
> WARNING you have Transparent Huge Pages (THP) support enabled in your kernel.  This will create latency and memory usage issues with Redis. To fix this issue run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as root, and add it to your /etc/rc.local in order to retain the setting after a reboot.

TODO: přidat do ARGA

Jak ten parametr ale dostat do jednotlivých nódů, resp bylo by vhodné to dostat jen do worker nodů

**skusime vyuzit node-tuning-operator**
```sh    
oc get -n openshift-cluster-node-tuning-operator Tuned/default -o yaml
```

vytvoříme tedy nový **Tuned profil a přez MachineConfigPool based matching ho navážeme na role=worker**

```yaml
apiVersion: tuned.openshift.io/v1
kind: Tuned
metadata:
  name: openshift-node-custom
  namespace: openshift-cluster-node-tuning-operator
spec:
  profile:
  - data: |
      [main]
      summary=Disable Transparent hugepages at boot time
      # includujeme puvodni profil a jen ho rozsirime
      include=openshift-node
      [bootloader]
      cmdline_openshift_node_custom=transparent_hugepage=never
    name: openshift-node-custom

  recommend:
  - machineConfigLabels:
      machineconfiguration.openshift.io/role: "worker"
    priority: 20
    profile: openshift-node-custom
```
```sh
# vytvori se machineconfig
oc get machineconfig 50-nto-worker -o yaml
```

na podech tuned DS se vytvoří přibližně taková directory structure dle definovaných profilů:
```sh
oc rsh -n openshift-cluster-node-tuning-operator tuned-rvdkq

/etc/tuned/{profile_name}/tuned.conf
/etc/tuned/active_profile #aktivni profil
cat /proc/cmdline #pokud menime cmdline
```

vazby na tuned_profily jdou dělat i složitěji a to i na základě labelů podu schedulovaných na nod, pozor na restarty NODU
```sh
# Node/Pod label based matching
- match:
  - label: tuned.openshift.io/elasticsearch
    match:
    - label: node-role.kubernetes.io/master
    - label: node-role.kubernetes.io/infra
    type: pod
  priority: 10
  profile: openshift-control-plane-es
- match:
  - label: node-role.kubernetes.io/master
  - label: node-role.kubernetes.io/infra
  priority: 20
  profile: openshift-control-plane
- priority: 30
  profile: openshift-node
```
{{< figure src="img/matching.png" caption="node/pod label based matching" >}}

```sh
# check for applied profiles
for p in `oc get pods -n openshift-cluster-node-tuning-operator -l openshift-app=tuned -o=jsonpath='{range .items[*]}{.metadata.name} {end}'`;\
do printf "\n*** $p ***\n" ; oc logs pod/$p -n openshift-cluster-node-tuning-operator | grep applied; done

  *** tuned-rvdkq ***
  2020-10-04 20:23:53,819 INFO     tuned.daemon.daemon: static tuning from profile 'openshift-node' applied
  2020-10-04 20:51:20,578 INFO     tuned.daemon.daemon: static tuning from profile 'openshift-node' applied
  2020-10-08 11:13:55,231 INFO     tuned.daemon.daemon: static tuning from profile 'openshift-node' applied
  2020-10-09 18:14:35,498 INFO     tuned.daemon.daemon: static tuning from profile 'openshift-node-custom' applied
  2020-10-09 18:19:37,531 INFO     tuned.daemon.daemon: static tuning from profile 'openshift-node-custom' applied
```

