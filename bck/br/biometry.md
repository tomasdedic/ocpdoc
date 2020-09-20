---
title: deploy BIOMETRY on GKE
date: 2019-03-02
author: Tomas Dedic
description: "deploy Tomcat, MSSQL, prometheus operator a grafana"
thumbnail: "img/14.jpg" # Optional, thumbnail
lead: "working"
disable_comments: true # Optional, disable Disqus comments if true
authorbox: false # Optional, enable authorbox for specific post
toc: false # Optional, enable Table of Contents for specific post
mathjax: false # Optional, enable MathJax for specific post
categories:
  - "Google Cloud Engine"
tags:
  - "GCE"
  - "GKE"
  - "docker"
  - "prometheus"
menu: main # Optional, add page to a menu. Options: main, side, footer
sidebar: true
draft: false
---

Snažim se přesunout aplikaci Biometrie do GKE, v podstatě se v základu jedná o dvě části a to aplikční část běžící na Tomcat a databázová část na MSSQL.
Samotná aplikace běžící na Tomcatu by měla být dynamicky škálovatelná. Pro vizualizaci škálování bude použit Prometheus resp Prometheus operator a Grafana.



# DEPLOY TOMCAT a MSSQL GKE
## TOMCAT
![dasdsa]("-WM_strip_DK_20110504.jpg")
```bash
docker run -p 8889:8080 tomcat:8.5

#allow remote connection, coz by na produkci byt uplne nemelo ale pro zjednoduseni nechavam

Create a file named $CATALINA_HOME/conf/Catalina/localhost/manager.xml with the following content:

<Context privileged="true" antiResourceLocking="false"
docBase="${catalina.home}/webapps/manager">
<Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*$" />
</Context>

Create a file named $CATALINA_HOME/conf/Catalina/localhost/host-manager.xml with the following content:

<Context privileged="true" antiResourceLocking="false"
        docBase="${catalina.home}/webapps/host-manager">
<Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*$" />
</Context>

# Přidáme uživatele
$CATALINA_HOME/conf/tomcat-users.xml
<role rolename="admin"/>
<role rolename="admin-gui"/>
<role rolename="manager-gui"/>

<user username="test" password="135test136#" roles="admin-script,manager-gui,admin-gui,admin,tomcat,role1"/>
```

## MSSQL
nedari se mi ho zbuildovat na CENTOS image
!chyba v entrypointu -->potreba uvest celou cestu

```bash
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["postgres"]
nc -z -v -w5 127.0.0.1 1433
#heslo na SA jsem upravil 
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=password1234@' -p 1433:1433 -d -ti microsoft/mssql-server-linux:latest
sqlcmd -S IA-SQL01.trask.cz -U bcuser -P Password02 -d TRASK_USIGNDB
use TRASK_USIGNDB #asi se nemusi

select * from sys.objects where schema_id=SCHEMA_ID('dbo')
go
SELECT name FROM sys.schemas;
go
```
vytvoreni db:
```bash
sqlcmd -U SA -P password1234@ -d master

SELECT NAME FROM sys.sysdatabases
go
EXEC sp_configure 'CONTAINED DATABASE AUTHENTICATION'
EXEC sp_configure 'CONTAINED DATABASE AUTHENTICATION', 1
GO
RECONFIGURE
GO

create database TRASK_USIGNDB
USE [master]
GO
ALTER DATABASE [TRASK_USIGNDB] SET CONTAINMENT = PARTIAL
GO
use [TRASK_USIGNDB]
GO
CREATE USER bcuser with password= 'bcuser1234#';
ALTER USER bcuser with default_schema=dbo
ALTER ROLE db_owner add member bcuser

sqlcmd -U bcuser -P 'bcuser1234#' -d TRASK_USIGNDB
```
-- ted je otazka jak propojit mezi sebou 2 docker images?
-- OK odpoved je jedoducha 2 docker images na stejnem hostu se vidi takze NP, na gcloudu to udelame prez servis na kubernates

## DEPLOY NA GCP (GOOGLE CLOUD PLATFORM)
```bash
#konfig pro cluster /.kube/config
kubectl view config
kubectl config current-context              # Display the current-context
kubectl config use-context my-cluster-name  # set the default context to my-cluster-name
```
Bude potřeba vytvořit servis pro Tomcat jelikož ten budeme scalovat, NFS úložiště pro perzistující soubory. Databáze bude neškálovatelná pouze jako jeden pod, ne že bych jí nechtěl udělat škálovatelnou čiste pro test ale MSSQL vůbec neznám a nevím jak to s během na více nódech má. Dost že se jí podařilo rozběhat pod linuxem.

### DATABASE MSSQL

*zajímavé je že nejde použít tag latest pro docker image*
kubectl create -f mssqldeployment.yaml
kubectl get services #najdeme public endpoint
telnet ENDPOINT 1500

problem je ten ze image ma prirazene volume:
```bash
docker inspect docker_image
```
a do image se nedá dělat commit
>Unfortunately, this feature is not available. It has been proposed many times but not accepted by the developers. The main resaon is portability; volumes are not supposed to be part of the image, and are stored outside the image.

```bash
Commit you container using the docker commit command.
Start a new dumy container that uses the volume from the container that you are trying to backup.
docker run -volumes-from <container-name> --name backup -it ubuntu bash
Once inside the container, tar the folder where the volume is mounted.
Copy the volume tar from the dummy container to your host using
docker cp backup: volume.tar
Now you have multiple options:
Create a new image using Dockerfile:

FROM commited-container-image
 COPY volume.tar .
 RUN tar -xf volume.tar -C path-to-volume-mount-point &&\
  rm -f volume.tar

Or Untar the volume backup and mount it as a bind mount on the new container created from the container-commit image
```

**ale pro google cloud je asi lepší použít**
--> moc se mi do toho nechce ale mám pocit že je to dost užitečná věc jí umět, možnost je taky nepoužít volume ale jen mít ty data v docker image jen v případě restartu se o ty data přijde což vnímám jako celkem problém konkrétně u databáze.

```bash
You can create data-folder on your GoogleCloud:

gcloud compute ssh <your cloud> <your zone>
mdkir data
```
Then create PersistentVolume:
[hostpth-pv.yml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/hostpth-pv.yml)
```bash
kubectl create -f hostpth-pv.yml
```

Create PersistentVolumeClaim:
[hostpath-pvc](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/hostpath-pvc.yml)
```bash
kubectl create -f hostpath-pvc.yml
```

And at last mount this PersistentVolumeClaim to your pod:

[mssqldeployment.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/mssqldeployment.yaml)
```yanl
...
      volumeMounts:
       - name: hostpath-pvc
         mountPath: /var/opt/mssql/data
         subPath: hostpath-pvc
  volumes:
    - name: hostpath-pvc
      persistentVolumeClaim:
        claimName: hostpath-pvc
And copy file to data-folder in GGloud:

  gcloud compute scp <your file> <your cloud>:/home/<user-name>/data/hostpath-pvc 
```
--> tohle je funkcni jen problem je ze ten persistent mount je vazany na konkretni nod pokud bychom pod scalovali a byl by spusten na druhem nodu tak to nebude funkcni, v tom pripade by se muselo pouzit nejake lepsi uloziste pro potřeby databáze je to ale v pořádku jelikož nepočítáme s horiznontálním škálováním

trochu problém dotatečný
> sqlservr: This program requires a machine with at least 2000 megabytes of memory.
**pouzijeme server n1-standard-1 (3.75 GB RAM)**
Nezkoumal jsem možnost upgrade stávajícího serveru. Ješte v rámci testu by bylo dobré mít to roztažené přez dvě lokality.

```bash
gcloud container clusters create bio-cluster \
--zone europe-west1-c \
--machine-type "n1-standard-1" \
--disk-type "pd-standard" \
--disk-size "10" \
--node-locations "europe-west1-c" \
--num-nodes 2 --enable-autoscaling --min-nodes 1 --max-nodes 2 --enable-cloud-monitoring --addons HorizontalPodAutoscaling,HttpLoadBalancing
```
```bash
kubectl describe deployments mssql-deployment
```
Vytvoříme lokální servis pro 1433 port:
[mssql-service.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/mssql-service.yaml)
Adresa pro připojení do service v rámci clusteru by měla být, zatím je to nakonfigurované natvrdo v property souboru Tomcatu. Ale bylo by fajn to udělat dynamicky v rámci deploy.
mssql-service.default.svc.cluster.local

### Deploy TOMCAT
To je celkem jednoduche ale ještě bych to rád rozšířil o NFS disk kam se budou ukládat jednotlivá pdf
[tomcat-deployment](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/tomcat-deployment.yaml)
[tomcat-service](tomcat-service.yaml)

### Přidání uživatele do IAM GKE
Pro vizualizaci potřebuji nakonfigurovat Prometheus a Grafanu, ani jedna neni přímo součástí GCE takže bude potřeba uďelat samostatný deploy a provázat
> Prometheus is an optional monitoring tool often used with Kubernetes. If you configure Stackdriver Kubernetes Monitoring with Prometheus support, then services that expose metrics in the Prometheus data model can be exported from the cluster and made visible as external metrics in Stackdriver.

+ install gcloud SDK [install_SDK] (https://cloud.google.com/sdk/install)
+ vytvoříme účet na cloudu (dtsrcow@gmail/KDC377$$26)
+ v IAM GUI GKE přidáme do projektu s rolí editor
+ přihlásíme se:
	gcloud config set account dtsrcow@gmail.com
	gcloud auth login
	gcloud container clusters get-credentials bio-cluster --zone europe-west1-c --project challangelabgce

### Kubernetes dashboard
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
```
>Error from server (Forbidden): error when creating "https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml": roles.rbac.authorization.k8s.io is forbidden: User "dtsrcow@gmail.com" cannot create roles.rbac.authorization.k8s.io in the namespace "kube-system": Required "container.roles.create" permission.
```bash
kubectl port-forward service/kubernetes-dashboard 5000:443 -n kube-system
```
**! vyřešit autorizaci !**
Trochu mi uniká model RBAC, resp každý namespace má serviceaccount default by default. Jen nevim jak přiřadit roli konkrétnímu uživateli
[RBAC model](https://github.com/kubernetes/dashboard/wiki/Access-control#kubeconfig)
máme tedy dvě možnosti:
+ kubeconfig 
Ten default co je v ~/.kube/config nejde použít jelikož chybí direktiva --authentication-mode
+ token pro service account  
 In example every Service Account has a Secret with valid Bearer Token that can be used to log in to Dashboard.

[dashboard-admin.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/kube_dashboard/dashboard-admin.yaml)
```bash
kubectl describe serviceaccounts kubernetes-dashboard -n kube-system
kubectl describe secret kubernetes-dashboard-token-svsl8 -n kube-system
```
a token použít pro autorizaci do Dashboardu

token vypada takto:
eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC10b2tlbi1zdnNsOCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6ImYyYjNlZjliLTM1MTctMTFlOS05NjJiLTQyMDEwYTg0MDA0MSIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTprdWJlcm5ldGVzLWRhc2hib2FyZCJ9.TOiKA8YvQGPujg_kvFViZJChmaOeqeCv1UvIR2YHcF1bRwZHBMQ6AUPOR1ym0J0o0QCqwalKAPj9esKlBavLiBX6FhCr6WST5VNl4bJQFHMpZqU1QWNfYYx1b4eduQPivZEig-ky0yXWNqmhp_jIQjxnA4UzXd2vVTK_7BOy01_xmSDuKi2hZnJZJBOdIkhw89-3pX3ePWYvA2Pa_CiJQVPvs1SpJJudnWCEpR_Kw8fW1t4T1y176-NgYu6bSDg9hDP4wEr9KSh9mBc-XaJYRF7bIT0ymcLA5fWpTBrMzQz7KZZh3iPsU9vFmAOUOU-5vSMB7ofIfPddpIe7VJJMkQ

### Instalace Prometheus do GKE
#### Privilege to create cluster role:
```bash
ACCOUNT=$(gcloud info --format='value(config.account)')
kubectl create clusterrolebinding owner-cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $ACCOUNT
```
```bash
kubectl create namespace monitoring
```
#### Vytvoření role
You need to assign cluster reader permission to this namespace so that Prometheus can fetch the metrics from kubernetes API’s.

[clusterRole.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/prometheus/clusterRole.yaml)
```bash
kubectl create -f clusterRole.yaml
--pro případné smazání
kubectl delete clusterrolebindings.rbac.authorization.k8s.io prometheus
kubectl delete clusterrole.rbac.authorization.k8s.io prometheus
```

#### Config map
Create a config map with all the prometheus scrape config and alerting rules, which will be mounted to the Prometheus container in **/etc/prometheus** as prometheus.yaml and prometheus.rules files.
**prometheus.yaml** - all the configuration to dynamically discover pods and services running in the kubernetes cluster.
**prometheus.rules** - contain all the alert rules for sending alerts to alert manager.

[config-map.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/prometheus/config-map.yaml)
```bash
kubectl create -f config-map.yaml -n monitoring
```

#### Deploy
[prometheus-deployment.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/prometheus/prometheus-deployment.yaml)
```bash
kubectl create  -f prometheus-deployment.yaml --namespace=monitoring
kubectl get deployments --namespace=monitoring
kubectl get pods --all-namespaces
kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}"

  jsonpath elementy:
  .items[*]: for each returned value
  .spec: get the spec
  .containers[*]: for each container
  .image: get the image
```

#### Connecting to Prometheus
+ Using Kubectl port forwarding
+ Exposing the Prometheus deployment as a service with NodePort or a Load Balancer.

##### Port Forwarding
```bash
kubectl get pods --namespace=monitoring
kubectl port-forward prometheus-deployment-55544b4954-t5gzk 8080:9090 -n monitoring
```

#### Expose service
We will expose Prometheus on all kubernetes node IP’s on port 30000. Na GCE můžeme pro přístup z venku použít typ LoadBalancer
[prometheus-service](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/prometheus/prometheus-service.yaml)
```bash
kubectl create -f prometheus-service.yaml --namespace=monitoring
```

#### Alert manager
TODO

### Instal GRaFANA do GKE
[grafana-deployment.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/grafana/grafana-deployment.yaml)

[grafana-service.yaml](~/git_repositories/work/gce-kubernetes/TMCMSSQL/kubernetes/grafana/grafana-service.yaml)
```bash
kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name --all-namespaces
kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name --namespace=monitoring
```
po deploy se toci ve smycce CrashLoopBackOff
diagnoza: 
```bash
přez gcloud compute ssh #na nod kde běží pod
docker logs container_id
```
>mkdir: cannot create directory '/var/lib/grafana/plugins': Permission denied
>GF_PATHS_DATA='/var/lib/grafana' is not writable.
problém je tedy v persistence claimu
user_id=472
```yml
    spec:
      securityContext:
        fsGroup: 472
```
### KONFIGURE PROMETHEUS to MONITOR GKE
An **Operator** is an application-specific controller that extends the Kubernetes API to create, configure, and manage instances of complex stateful applications on behalf of a Kubernetes user. It builds upon the basic Kubernetes resource and controller concepts but includes domain or application-specific knowledge to automate common tasks.
When you deploy a new version of your app, k8s creates a new pod (container) and after the pod is ready k8s destroy the old one. Prometheus is on a constant vigil, watching the k8s api and when detects a change it creates a new Prometheus configuration, based on the services (pods) changes.

#### použijeme PROMETHEUS operator
[prometheus-operator](~/git_repositories/moje/mantab/img/1_6KI8wlyWwLwPYgt_SP1CCA.png)
When you deploy a new version of your app, k8s creates a new pod (container) and after the pod is ready k8s destroy the old one. Prometheus is on a constant vigil, watching the k8s api and when detects a change it creates a new Prometheus configuration, based on the services (pods) changes.

tady je potřeba nainstalovat HELM, což je instalator baličku do kubernetes
```
helm install stable/prometheus-operator --name prometheus-operator --namespace monitoring
```

>r: customresourcedefinitions.apiextensions.k8s.io "alertmanagers.monitoring.coreos.com" is forbidden: User "system:serviceaccount:kube-system:default" cannot delete customresourcedefinitions.apiextensions.k8s.io at the cluster scope

!takže zásek!
**SOLVED:**
```bash
helm reset --force
kubectl -n kube-system create sa tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

kubectl auth can-i delete customresourcedefinitions
yes
kubectl auth can-i delete customresourcedefinitions --all-namespaces
yes
```
OH YES:
```bash
kubectl --namespace monitoring get pods -l "release=prometheus-operator"
kubectl port-forward -n monitoring prometheus-prometheus-operator-prometheus-0 9090
```
GRAFANA TEST:
```bash
kubectl port-forward prometheus-operator-grafana-7d7784645b-4k8gt -n monitoring 10000:3000
```

zajimave je ze se poprve dostavam k architekture ze jeden pod obsahuje vice kontejneru:
```bash
kubectl get pods prometheus-prometheus-operator-prometheus-0 -n monitoring -o jsonpath='{.spec.containers[*].name}' 
prometheus prometheus-config-reloader rules-configmap-reloader
```

#### SERVICE MONITOR
Prometheus-operator uses a Custom Resource Definition (CRD), named ServiceMonitor, to abstract the configuration to target.

Tzn pro každou servisu dle labelu je potřeba nakonfigutovat servis monitor a asi i Exporter

