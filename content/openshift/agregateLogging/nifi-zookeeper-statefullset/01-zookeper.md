# Instalace **nifi clusteru** do private OCP
+ [cetic/helm-nifi repo](https://github.com/cetic/helm-nifi)
**Helm chart obsahuje 3 subcharty, budeme se s tim muset nejak vypořádat.**


## BASE install
Začneme zhurta
```sh
helm repo add cetic https://cetic.github.io/helm-charts/
helm search repo nifi
helm install cetic/nifi

# unable to validate against any security context constraint:
# [provider restricted: .spec.securityContext.fsGroup: Invalid value: []int64{1001}:
# 1001 is not an allowed group spec.containers[0].securityContext.runAsUser: Invalid value: 1001: must be in the ranges: [1000690000, 1000699999]]

# jasne nas namespace ma automaticky prideleny uid-range,  samozrejme SA dafault default pro deploy neumi beh v jinych UID
oc get ns nifi -o=jsonpath='{.metadata.annotations}'|jq
{
  "openshift.io/description": "",
  "openshift.io/display-name": "",
  "openshift.io/requester": "system:serviceaccount:openshift-apiserver:openshift-apiserver-sa",
  "openshift.io/sa.scc.mcs": "s0:c26,c20",
  "openshift.io/sa.scc.supplemental-groups": "1000690000/10000",
  "openshift.io/sa.scc.uid-range": "1000690000/10000"
}

```
Odinstalujeme tedy helmchart
```sh
# uninstall helm chart
helm delete nifi
oc delete pvc -l app.kubernetes.io/instance=nifi
```
ok potrebujeme securityContext runAsAny jelikoz pod si vynucuje usera, zatim nezkoumam zda se  da upravit **deployment** na defaultni chovani Openshiftu tedy ze kontejner dokáže běžet pod libovolným UID
a koukam helm chart mi nabizi option pro scc

```sh
# nifi-scc provides all features of the restricted SCC but allows users to run with any UID and any GID.
helm install nifi cetic/nifi \
  --set  openshift.scc.enabled=true

# ok vytvorilo se scc a bylo přiřazno uživateli
oc get scc nifi-scc -o=jsonpath='{.users}'
> ["system:serviceaccount:nifi:default"]%

# ok checkneme pod jakym UID a fsGroup nam to bezi
oc get pod -o jsonpath='{range .items[*]}{@.metadata.name}{" runAsUser: "}{@.spec.containers[*].securityContext.runAsUser}{" fsGroup: "}{@.spec.securityContext.fsGroup}{" seLinuxOptions: "}{@.spec.securityContext.seLinuxOptions.level}{"\n"}{end}'

# v deploy sme se posunuli trochu dal ale porad mame nejake chyby
oc get pods

NAME               READY   STATUS                  RESTARTS   AGE
nifi-zookeeper-0   0/1     ImagePullBackOff        0          25m
nifi-zookeeper-1   0/1     ImagePullBackOff        0          25m
nifi-zookeeper-2   0/1     ImagePullBackOff        0          25m

oc describe pods nifi-zookeeper-0|grep Failed
# ok mame problem s proxynou ke ktere jsou presmerovany vsechny image registry, k tomu se dostaneme 
Failed    kubelet   Failed to pull image "docker.io/bitnami/zookeeper:3.6.2-debian-10-r37": rpc error: code = Unknown desc =
                    (Mirrors also failed: [artifactory.sudlice.cz:443/docker-io/bitnami/zookeeper:3.6.2-debian-10-r37:
                    Error reading manifest 3.6.2-debian-10-r37 in artifactory.sudlice.cz:443/docker-io/bitnami/zookeeper:
                    manifest unknown: The named manifest is not known to the registry.]): docker.io/bitnami/zookeeper:3.6.2-debian-10-r37:
                    error pinging docker registry registry-1.docker.io: Get "https://registry-1.docker.io/v2/": Proxy authentication required
Failed    kubelet   Error: ErrImagePull
Failed    kubelet   Error: ImagePullBackOff
```
### Mirror registry/local repository
Jdeme se vypořádat s problémem pro mirror registry resp proxy, tohle je problem whitelistingu kdy vsechny pull requesty jsou smerovany na mirror v Artifactory  
kde jsou povolene jen nekteré [whitelisting nastavení na Artifactory](https://cnfl.sudlice.cz/display/ARTIFACTORY/Artifactory+-+Remote+List).  

[Pro zatím použijeme lokální registry](/openshift/uploading_container_image_to_ocp_registry/) a pak kdyžtak zažádáme o přidání repozitářů do whitelistu.

## SC pro stateFullSet Zookeper
Ještě koukám výtvořili se PV, jelikož jsme nespecifikoval žádnou SC tak přez SC default což je v našem případě azure-disk
```sh
oc get sc

NAME                        PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
managed-premium (default)   kubernetes.io/azure-disk   Delete          WaitForFirstConsumer   true                   84d
```
to nechceme jelikož:
> AzureDisks cannot be created with other redundancy then LRS. Pods with PVC are strained to stay only in oneZone as nodeAffinity. VM provided in Azure has limited numbers of datadisks used as PV.
Resp postavíme se k tomu tak že **zookeeper** necháme na AzureDisk s tím že každou instanci  a tedy i PV(replica 3) rozběhneme v jedné zóně.
```sh
oc get nodes -L failure-domain.beta.kubernetes.io/zone|grep worker|awk '{print $1" "$3" "$6}'

oaz-dev-trkn8-worker-westeurope1-fxthw worker westeurope-1
oaz-dev-trkn8-worker-westeurope2-vg8lc worker westeurope-2
oaz-dev-trkn8-worker-westeurope3-wmqpz worker westeurope-3
```
```yaml
# miluju tuhle ficurku 1.19 kubernetes
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: "failure-domain.beta.kubernetes.io/zone"
        whenUnsatisfiable: "DoNotSchedule"
        labelSelector:
            app.kubernetes.io/name: zookeeper
```








