Cílem dokumentu je popsat stav "as is" logování na platformě Openshift 4.6, vydefinovat části které bude potřeba dořešit případně se jim více věnovat nebo s nimi počítat.
Logování je definováno Openshift Cluster Logging Operátorem a je poměrně utažené co se týká možností rekonfigurace a úprav.
Ke konkrétním bodům se dostaneme v dalších částech textu.  

## Architektura logování
### Komponenty
**Základní komponenty logováni jsou  Elasticsearch, Fluentd and Kibana.**

+ **logStore**: Úložiště logů, současná implementace je **Elasticsearch**.
+ **collection**: Sběr logů, jejich parsing a transformace a transport. Současná implementace **Fluentd**.
+ **visualization**: Současná implementace **Kibana**.
+ **curation**: Mazání indexů v logStore na základě retence. Současná implementace **Curator**. Ve verzi 4.6 je Curator nahrazen joby které řeší rollover indexů tak retenci. Původní Curator zůstává pouze pro zpětnou kompatibilitu.
+ **event routing**: Směřuje události generované API do logu podů v kterých události vznikly. Současná implementace je **EventRouter** 

{{< figure src="img/openshift-logging.png" caption="nákres logovacího stacku" >}}

### DEFINICE OPERÁTORŮ
Logovací stack se nasadí subskribováním se k  **cluster-logging** operátoru a **elasticsearch-operator** a následně definicí CRD pro logování. Operátor pak vytvoří potřebné objekty dle definice CRD (cluster-logging) a jejich topologii. 

Vytvořené objekty pak vypadají nějak takhle, pro představu uvádím část.
```sh
daemonset.apps/fluentd

deployment.apps/cluster-logging-operator
deployment.apps/elasticsearch-cdm-mexyxph8-1
deployment.apps/kibana

cronjob.batch/curator
cronjob.batch/elasticsearch-delete-app
cronjob.batch/elasticsearch-delete-audit
cronjob.batch/elasticsearch-delete-infra
cronjob.batch/elasticsearch-rollover-app
cronjob.batch/elasticsearch-rollover-audit
cronjob.batch/elasticsearch-rollover-infra

configmap/cluster-logging-operator-lock
configmap/curator
configmap/elasticsearch
configmap/fluentd
configmap/fluentd-trusted-ca-bundle
configmap/indexmanagement-scripts
configmap/kibana-trusted-ca-bundle
```
*V našem případě se o nasazení postará gitOPS řešení ArgoCD a dojde k vytvoření samostatného dedikovaného nódu na kterém poběží Elasticsearch a Kibana.*
  
Pro jakékoliv změny je v deploy objektech je potřeba převést operátor do stavu **unmanaged**.
> 	If you must perform configurations not described in the OpenShift Container Platform documentation, you must set your Cluster Logging Operator or Elasticsearch Operator to Unmanaged. An unmanaged cluster logging environment is not supported and does not receive updates until you return cluster logging to Managed.

[Zároveň RH uvádí velké množství úprav které jou explicitně nepodporované](https://docs.openshift.com/container-platform/4.6/logging/config/cluster-logging-maintenance-support.html)  
V podstatě jsou nepodporované jakékoliv zásahy do jednotlivých objektů kromě úprav definovaných přez **CRD clusterlogging**.


## Defaultní Konfigurace

### FluentD
+ Logy kontejnerů (/var/log/containers/**)  
  Přijímány jsou logy ve 2 formátech a ty jsou pak dále modifikovány a obohaceny metadaty 
  ```sh
      # priklad kubelet pod logu:
      #2020-06-23T13:08:52.206419987+00:00 stderr F I0623 13:08:52.206374 1184379 proxier.go:368] userspace proxy : processing 0 service events
      #parsed jako
      #{"time":"2020-06-23T13:08:52.206419987+00:00","stream":"stderr","logtag":"F","message":"I0623 13:08:52.206374 1184379 proxier.go:368] userspace proxy : processing 0 service events"}
      format regexp
      expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
  ```
  ```sh
      format json
  ```

+ Json parsing těla zprávy  
  Není definovám a doporučen. Pokud bude tedy například field **log** obsahovat zprávu ve formátu JSON, nebude dále parsován. Dle mého názoru vychází z omezení pro ES dynamic mapping, kdy pro jeden index se doporučuje maximálně 1000 unikátních fieldů.

+ Multiline log  
  Není definován, typicky stack trace JAVY bude propagován jako každý řádek samostatná event jelikož první část zprávy je definovaná kubeletem. Je nutné omezit tento typ logování.

+ Dělení výstupních ES indexů  
  Výstup je směrován do 3 ES indexů **infra, app, audit**. Infra index obsahuje dokumenty z podů openshift-**, kubernetes-** a default. Audit index k8s-audit.log**, openshift-audit.log** a auditd na nodu. Infra index obsahuje zbytek.

+ Směrování parsovaných logů do systému třetích stran  
  Nutnost použití CR ClusterLogForwarder. FluentD na OCP 4.6 obsahuje plugin pro Kafku. 

### Elasticsearch
Elastic search má nadefinované templaty a mapping pro tři indexy **infra, app, audit**.  
Rollover a mazání indexů je prováděno voláním API z cronjob vytvořených při deploy CRD clusterlogging a řízeno definovanými parametry.  

>The index is older than the rollover.maxAge value in the Elasticsearch CR.  
>The index size is greater than 40 GB × the number of primary shards.  
>The index doc count is greater than 40960 KB × the number of primary shards.  
>Elasticsearch deletes the rolled-over indices are deleted based on the retention policy you configure.  
>If you do not create a retention policy for any of the log sources, logs are deleted after seven days by default.  

### Kibana 
TODO: Nemám dořešen RBAC a mapping rolí pro ES.

## Příklady parsovaných logů
### JSON log
raw log
```sh
{
  "level": "info",
  "ts": 1605441700.8959095,
  "logger": "klog",
  "msg": "Server rejected event ObjectMeta:v1.ObjectMeta{Name:\"ahoj-svete.16477d1d3ee12d4d\",, Reason:\"ProjectEnvironmentsUpdated\",
        FirstTimestamp:v1.Time{Time:time.Time{wall:0xbfe430eb2c4e754d, ext:61997781084, 'events \"ahoj-svete.16477d1d3ee12d4d\"
        is forbidden: User \"system:serviceaccount:csas-project-operator:csas-project-operator-manager\" 
        cannot patch resource \"events\" in API group \"\" in the namespace \"default\"' (will not retry!)"
}
```
log na uložen na nodu /var/log/containers/**
```sh
2020-11-23T22:42:52.352608403+00:00 stdout F {"level":"info","ts":1605441700.8959095,"logger":"klog","msg":"Server rejected event ObjectMeta:v1.ObjectMeta{Name:\"ahoj-svete.16477d1d3ee12d4d\",, Reason:\"ProjectEnvironmentsUpdated\", FirstTimestamp:v1.Time{Time:time.Time{wall:0xbfe430eb2c4e754d, ext:61997781084, 'events \"ahoj-svete.16477d1d3ee12d4d\" is forbidden: User \"system:serviceaccount:csas-project-operator:csas-project-operator-manager\" cannot patch resource \"events\" in API group \"\" in the namespace \"default\"' (will not retry!)"}
```
log po pruchodu fluentD a uložen v ES
{{< figure src="img/parsed_json_log.png" caption="json log v ES" >}}

### PLAIN log
raw log
```sh
proxier.go:368] userspace proxy : processing 0 service events a nic k tomu uz nepridam jen demonstrace REGEX match pro INPPUT
```
log na uložen na nodu /var/log/containers/**
```sh
2020-11-23T22:42:52.352761911+00:00 stdout F proxier.go:368] userspace proxy : processing 0 service events a nic k tomu uz nepridam jen demonstrace REGEX match pro INPPUT
```
log po pruchodu fluentD a uložen v ES
{{< figure src="img/parsed_plain_log.png" caption="plain log v ES" >}}
