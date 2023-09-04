# 68. Je definována komponenta LOKI včetně jejího účelu, provozního modelu a práci s daty 
## 1. Proč centrální LOKI
**Na centrální LOKI cluster se v tento okamžik díváme jako na dlouhodé úložiště logů pro OPS. Nemáme ambice nahrazovat budoucí řešení Monolog.**
Hlavní výrazná změna Loki oproti ELK je ta že LOKI neindexuje všechny řádky logů, ale pouze metadata logu. Díky tomu je výrazně rychlejší ale zároveň na heuristické analýzy spíše méně vhodný. Pro potřeby OPS však naprosto dostačující.

Logy na jednotlivých clusterech budou uloženy v lokálním ES s relativně krátkou retencí.
Všechny logy budou zároveň z jednotlivých OCP clusterů přez CLusterLogForwarder směrovány do OCP Infra clusteru.
**Pro každý cluster vznikne instance LOKI s backendem postaveným nad S3 storage.**
Nebudeme tedy provozovat multitenanci na úrovni LOKI, každá instance bude mít svojí vlastní S3 storage a svoje vlastní endpointy, následně bude samostatný i Grafana datasource směřující do instance Loki.

## 2. Instance LOKI
### 2.1. Izolace tenantů
Instalaci provedeme samostatnou instancí Loki per cluster, se všemi samostatnými endpointy. Každý cluster z kterého budou logy propagovány budou mít vlastní S3 bucket.
{{< figure src="img/LOKI-multiinstance.png" caption="Izolace tenantu" width="500" >}}

### 2.2. Multitenantí přístup
> Grafana Loki does not come with any included authentication layer. Operators are expected to run an authenticating reverse proxy in front of your services, such as NGINX using basic auth or an OAuth2 proxy. Note that when using Loki in multi-tenant mode, Loki requires the HTTP header X-Scope-OrgID to be set to a string identifying the tenant; the responsibility of populating this value should be handled by the authenticating reverse proxy.  

O oddělení přistupu k datům na úrovni rozdílných RBAC a tenantů uvažujeme ale zatím nejsme ve fázi kdy by bylo zřejmé jak multitenantnost implementovat na úrovni Grafany, zároveň bychom byli nuceni použít jeden **S3 bucket**
  
Pro implementaci na úrovni lokiho bychom mohli použít [multitenant proxy](https://github.com/k8spin/loki-multi-tenant-proxy) ale zatím přesunuji do backlogu.

## 3. Transport logů do LOKI
Pro transport logů bude pooužit CRD ClusterLogForwarder na jednotlivých clusterech
### 3.1. ClusterLogForwarder definition

```yaml
apiVersion: "logging.openshift.io/v1"
kind: ClusterLogForwarder
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
  name: instance
  namespace: openshift-logging
spec:
  inputs:
  #argocd jako samostatny input
  - name: argocd
    application:
      namespaces:
      - csas-argocd-sys
      - csas-argocd-app
  - name: events
    application:
      namespaces:
        - openshift-logging
      selector:
        matchLabels:
          component: eventrouter

  outputs:
  - name: external-elasticsearch
    type: "elasticsearch"
    url: https://deva-monolog-elastic.vs.csin.cz:9200
    secret:
      name: external-elasticsearch-secret
  - name: loki
    type: "loki"
    url: http://loki-tocp4s.apps.iocp4s.csin.cz
    loki:
      # tenantKey: kubernetes.namespace_name
      # definice labelu ktere budou komponovat index
      labelKeys: [log_type, openshift.labels.logtype, kubernetes.namespace_name, kubernetes.pod_name, kubernetes_host, kubernetes.container_name]
  # Kafka pro aplikacni logy
  - name: kafka-app-in
    type: kafka
    secret:
      name: kafka-credentials
    kafka:
      brokers:
      - tls://ppkafpl02.vs.csin.cz:9095/
      - tls://pbkafpl02.vs.csin.cz:9095/
      - tls://ppkafpl03.vs.csin.cz:9095/
      - tls://pbkafpl03.vs.csin.cz:9095/
      - tls://ppkafpl04.vs.csin.cz:9095/
      - tls://pbkafpl04.vs.csin.cz:9095/
      topic: "LOG.OCP.TOCP4S_PROD_APP_IN"
  # Kafka pro auditni logy
  - name: kafka-aud-in
    type: kafka
    secret:
      name: kafka-credentials
    kafka:
      brokers:
      - tls://ppkafpl02.vs.csin.cz:9095/
      - tls://pbkafpl02.vs.csin.cz:9095/
      - tls://ppkafpl03.vs.csin.cz:9095/
      - tls://pbkafpl03.vs.csin.cz:9095/
      - tls://ppkafpl04.vs.csin.cz:9095/
      - tls://pbkafpl04.vs.csin.cz:9095/
      topic: "LOG.OCP.TOCP4S_PROD_AUD_IN"
  # Kafka pro event logy
  - name: kafka-evt-in
    type: kafka
    secret:
      name: kafka-credentials
    kafka:
      brokers:
        - tls://ppkafpl02.vs.csin.cz:9095/
        - tls://pbkafpl02.vs.csin.cz:9095/
        - tls://ppkafpl03.vs.csin.cz:9095/
        - tls://pbkafpl03.vs.csin.cz:9095/
        - tls://ppkafpl04.vs.csin.cz:9095/
        - tls://pbkafpl04.vs.csin.cz:9095/
      topic: "LOG.OCP.TOCP4S_PROD_EVT_IN"

  pipelines:
  - name: argocd-logs
    inputRefs:
    - argocd
    outputRefs:
    - loki
    labels:
      logtype: argocd #openshift.labels.logtype = argocd
      clustername: tocp4s #openshift.lables.clustername =tocp4s
  - name: events-logs
    inputRefs:
      - events
    outputRefs:
      - kafka-evt-in
    labels:
      logtype: event
      clustername: tocp4s

  - name: audit-logs
    inputRefs:
    - audit
    - argocd
    outputRefs:
    - default #internal ES
    - kafka-aud-in
    labels:
      logtype: audit #openshift.labels.logtype = audit
      clustername: tocp4s

  - name: infrastructure-logs
    inputRefs:
    - infrastructure
    outputRefs:
    - default
    - loki
    labels:
      logtype: infrastructure
      clustername: tocp4s

  - name: application-logs
    inputRefs:
    - application
    outputRefs:
    - default
    - kafka-app-in
    - external-elasticsearch
    labels:
      logtype: application
      clustername: tocp4s
```
**pipeline:**
+ application - logy kontejnerů generované uživatelskými aplikacemi běžícími v clusteru, vyjímkou jsou infrastrukturní logy 
+ infrastructure - logy kontejnerů běžící v namespacech openshift*, kube*, nebo default projects a journal logy pocházející filesystému jednotlivých nodů
+ audit - Audit generovány přez auditd, Kubernetes API server, OpenShift API server, a OVN network.
### 3.2 Custom labels 
```yaml
    labels:
      cluster_name: tocp4s
      environment: test
```
Tyto custom labely budou ve struktuře logu jako **.openshift.labels**

### 3.3 Log směrovaný do instance Loki 
```json
{
  "@timestamp": "2023-03-26T15:49:35.802233556+00:00",
  "message": "image-registry.openshift-image-registry.svc:5000",
  "docker": {
    "container_id": "af7e75f2224a44bee9dfe7ae6e62d967652b8d2fc93f0a9e6a666a597a7ad853"
  },
  "kubernetes": {
    "container_name": "node-ca",
    "namespace_name": "openshift-image-registry",
    "pod_name": "node-ca-pdcmn",
    "container_image": "quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:56dd1db2c4ae562d09a457e4a9c121a76cdb8835503b860996646e9d4460a0ce",
    "container_image_id": "quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:56dd1db2c4ae562d09a457e4a9c121a76cdb8835503b860996646e9d4460a0ce",
    "pod_id": "fe8191dc-449a-461b-9967-6c2693e406f9",
    "pod_ip": "10.88.56.70",
    "host": "infra01",
    "labels": {
      "controller-revision-hash": "649f4968fd",
      "name": "node-ca",
      "pod-template-generation": "18"
    },
    "master_url": "https://kubernetes.default.svc",
    "namespace_id": "7c4c2cad-62ee-4823-9ce9-df7249887717",
    "namespace_labels": {
      "kubernetes.io/metadata.name": "openshift-image-registry",
      "olm.operatorgroup.uid/d91045da-eef8-42ee-ba26-bcb6fc7a6a7a": "",
      "openshift.io/cluster-monitoring": "true",
      "pod-security.kubernetes.io/audit": "privileged",
      "pod-security.kubernetes.io/enforce": "privileged",
      "pod-security.kubernetes.io/warn": "privileged"
    },
    "flat_labels": [
      "controller-revision-hash=649f4968fd",
      "name=node-ca",
      "pod-template-generation=18"
    ]
  },
  "level": "unknown",
  "hostname": "infra01",
  "pipeline_metadata": {
    "collector": {
      "ipaddr4": "10.88.56.70",
      "inputname": "fluent-plugin-systemd",
      "name": "fluentd",
      "received_at": "2023-03-26T15:49:35.802497+00:00",
      "version": "1.14.6 1.6.0"
    }
  },
  "openshift": {
    "sequence": 404273,
    "cluster_id": "605219f2-ae45-4d06-a9a6-7903ec67c69d",
    "labels": {
      "cluster_name": "tocp4s",
      "log_type": "infrastructure"
    }
  },
  "viaq_msg_id": "ODM2NjFjZDUtMWE5Mi00ZmE5LTkxMzUtY2ZmN2ViNzMzOTZl",
  "log_type": "infrastructure"
}
```
### 3.4 Loki labels
Použité labelKeys které definují index

```yaml
labelKeys: [log_type, openshift.labels.logtype, kubernetes.namespace_name, kubernetes.pod_name, kubernetes_host, kubernetes.container_name ]
```

## 4. použité KOMPONENTY LOKI
[LOKI komponenty](https://grafana.com/docs/loki/latest/fundamentals/architecture/components/)   
+ Distributor  
+ Ingester  
+ Querier  
+ Query frontend  
+ Compactor  
+ Index Gateway  
+ Ruler  

{{< figure src="img/LOKIarchitektura.png" caption="LOKI architektura" width=500 >}}

## 5. Instalace LOKI 
Vycházíme z nemodifikovaného helmchartu pro loki distributed, service account **LOKI** a CRB na SCC anyuid je aplikován ručně
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-distributed -n loki -f values.yaml
```
```bash
# stav komponent v runtime
pod/loki-tocp4s-compactor-947cbb56f-l72zd
pod/loki-tocp4s-distributor-65766845f9-2849b
pod/loki-tocp4s-distributor-65766845f9-7wdbp
pod/loki-tocp4s-distributor-65766845f9-dr5jq
pod/loki-tocp4s-index-gateway-0
pod/loki-tocp4s-index-gateway-1
pod/loki-tocp4s-index-gateway-2
pod/loki-tocp4s-ingester-66b7c49d74-29jvh
pod/loki-tocp4s-ingester-66b7c49d74-64lpj
pod/loki-tocp4s-ingester-66b7c49d74-9bx66
pod/loki-tocp4s-ingester-66b7c49d74-mfcr7
pod/loki-tocp4s-ingester-66b7c49d74-rxqhp
pod/loki-tocp4s-querier-88c686cbc-2svzt
pod/loki-tocp4s-querier-88c686cbc-kvhcw
pod/loki-tocp4s-querier-88c686cbc-wzs8c
pod/loki-tocp4s-query-frontend-77db9468dc-z7mzh
pod/loki-tocp4s-ruler-5fc9c9fd4d-52k5l
```

## 6. Persistence
Zatím nepočítáme s žádnou persistencí přímo na Openshiftu, toto rozhodnutí muže to mít drobné dopady ale z testů se je nepodařilo ohalit.  
Z pohledu ztráty dat je nejcitlivější **Ingestor**, indexy které generuje nejsou okamžitě posílány na do S3 přez BoltDB shipper ale jsou po dobu 15 minut drženy na **Ingestoru**.   
Pro **Ingestor** ale používáme **Replication factor = 3** tzn stejná data jsou z **Distributoru** odeslána právě 3 Ingestorům a minimálně 2 potvrzení jsou vyžádány.
Data jsou tedy replikována, jejich zápis do S3 je ale proveden pouze jednou jelikož mají stejný hash. Vícero **Ingestorů** tak nebude zapisovat stejná data do S3 vícekát.
Zároveň se ale rozhodnutím nepoužívat persistence  omezujeme pro použití WAL(write ahead log) pro recovery scénář během rolloutu a restartu.

## 7. Retence dat
O odmazávání logů (chunků i indexů) se stará komponenta **Compactor** 
```yaml
    compactor:
      shared_store: s3
      retention_enabled: true
      retention_delete_delay: 2h
      retention_delete_worker_count: 150

    limits_config:
      retention_period: 240h # 10 dnů
```
Retence může být nastavena i selektivně s různými retenčními politikami pro různé labely. Zatím tohoto konceptu nevyužíváme.

## 8. Migrace Schema
Od verze Loki 2.8 je podporováno TSDB místo BoltDB
```yaml
#both schemas running at once
schemaConfig:
  configs:
  - from: 2023-01-01 # <----schema validity
    store: boltdb-shipper
    object_store: s3
    schema: v12
    index:
      prefix: loki_index_
      period: 24h
  - from: "2023-08-08" # <---- switch to tsdb
    object_store: s3
    schema: v12
    store: tsdb
    index:
      period: 24h
      prefix: loki_index_

# -- Check https://grafana.com/docs/loki/latest/configuration/#storage_config for more info on how to configure storages
storageConfig:
  boltdb_shipper:
    shared_store: s3
    active_index_directory: /var/loki/index
    cache_location: /var/loki/cache
    cache_ttl: 168h
    index_gateway_client:
      # only applicable if using microservices where index-gateways are independently deployed.
      server_address: dns:///loki-iocp4s-index-gateway.loki-iocp4s.svc.cluster.local:9095
  # New tsdb-shipper configuration
  tsdb_shipper:
    shared_store: s3
    active_index_directory: /var/loki/tsdb-index
    cache_location: /var/loki/tsdb-cache
    index_gateway_client:
      # only applicable if using microservices where index-gateways are independently deployed.
      server_address: dns:///loki-iocp4s-index-gateway.loki-iocp4s.svc.cluster.local:9095
  filesystem:
    directory: /var/loki/chunks
query_scheduler:
  # the TSDB index dispatches many more, but each individually smaller, requests.
  # We increase the pending request queue sizes to compensate.
  max_outstanding_requests_per_tenant: 32768

querier:
  # Each `querier` component process runs a number of parallel workers to process queries simultaneously.
  # You may want to adjust this up or down depending on your resource usage
  # (more available cpu and memory can tolerate higher values and vice versa),
  # but we find the most success running at around `16` with tsdb
  max_concurrent: 16
```
## 9. DOC

[komponenty loki detailně](https://grafana.com/docs/loki/latest/fundamentals/architecture/components/)  
[consistent hash ring - explanation, zajimal me tech pozadi](https://www.toptal.com/big-data/consistent-hashing)  
[consistent hashing](https://www.cs.princeton.edu/courses/archive/fall15/cos518/studpres/dynamo.pdf)  
[loki deep dive](https://taisho6339.gitbook.io/grafana-loki-deep-dive/)  
[from BoltDB to TSDB](https://grafana.com/docs/loki/latest/operations/storage/tsdb/)  
[TSDB explained](https://lokidex.com/posts/tsdb/)  
[medium popis performence optimalizace](https://medium.com/itnext/grafana-loki-performance-optimization-with-recording-rules-caching-and-parallel-queries-28b6ebba40c4)  
