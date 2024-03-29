---
title: "Základy síťování v kubernetesII - LB,Ingress,DNS [WOTW-5]"
date: 2021-07-28
author: Tomas Dedic
description: "Desc"
lead: "workshop"
categories:
  - "wotw"
---

## LoadBalancer a jak je to udělané
Implementace servisu typu LoadBalancer se může dost lišit mezi jednotlivými CLOUD providery a samozřejmě na onprem může být úplně jiná, třeba manuální.  
Podstatné je že servisa typu LoadBalancer umožňuje vytvořit externí přístup k jinak interní servise, většinou tak že vytvoří pro kubernetes cluster externí objekt typu LoadBalancer (může být samozřejmě baremetal) a z něj směřuje data na backend.  


K3D (K3S) používá [Service LoadBalancer klipper](https://rancher.com/docs/k3s/latest/en/networking/?query=servicelb)  
> How the Service LB Works
> K3s creates a controller that creates a Pod for the service load balancer, which is a Kubernetes object of kind Service.
> For each service load balancer, a DaemonSet is created. The DaemonSet creates a pod with the svc prefix on each node.
> The Service LB controller listens for other Kubernetes Services. After it finds a Service, it creates a proxy Pod for the service using a DaemonSet on all of the nodes. This Pod becomes a proxy to the other Service, so that for example, requests coming to port 8000 on a node could be routed to your workload on port 8888.
> If the Service LB runs on a node that has an external IP, it uses the external IP.
> If multiple Services are created, a separate DaemonSet is created for each Service.
> It is possible to run multiple Services on the same node, as long as they use different ports.
> If you try to create a Service LB that listens on port 80, the Service LB will try to find a free host in the cluster for port 80. If no host with that port is available, the LB will stay in Pending.

```yaml
#service typu LB ktera smeruje traffic to aplikace traefik 
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/instance: traefik
    app.kubernetes.io/name: traefik
  name: aabb
  namespace: kube-system
spec:
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: web
    nodePort: 32444
    port: 800
    targetPort: web
  - name: websecure
    nodePort: 30747
    port: 900
    targetPort: websecure
  selector:
    app.kubernetes.io/instance: traefik
    app.kubernetes.io/name: traefik
  type: LoadBalancer
```
```sh
➤ oc get svc -n kube-system aabb
NAME   TYPE           CLUSTER-IP      EXTERNAL-IP                        PORT(S)                       AGE
aabb   LoadBalancer   10.43.134.203   172.21.0.2,172.21.0.3,172.21.0.4   800:32444/TCP,900:30747/TCP   12m

➤ kb get endpoints aabb -n kube-system
NAME   ENDPOINTS                       AGE
aabb   10.42.2.3:8000,10.42.2.3:8443   15m
```
Kubeproxy nám na nodech vytvořila nová pravidla tak se na ně trochu podíváme.
```sh
➤ /usr/bin/docker ps
➤ /usr/bin/docker exec -it 37aa041af08d sh
/ # iptables-save >ss
```
teď trochu prozkoumáme IPTABLES  
[https://www.sudlice.org/openshift/linux/iptables/](https://www.sudlice.org/openshift/linux/iptables/)
```sh
# vznikla pravidlo pro cluster servis ty teď nejsou důležité
-A KUBE-SERVICES ! -s 10.42.0.0/16 -d 10.43.134.203/32 -p tcp -m comment --comment "kube-system/aabb:web cluster IP" -m tcp --dport 800 -j KUBE-MARK-MASQ
-A KUBE-SERVICES -d 10.43.134.203/32 -p tcp -m comment --comment "kube-system/aabb:web cluster IP" -m tcp --dport 800 -j KUBE-SVC-RVAFSEPDPUT7VZG7

#pokud přijde trafic na vnější adresu nodu 
-A KUBE-SERVICES -d 172.21.0.2/32 -p tcp -m comment --comment "kube-system/aabb:web loadbalancer IP" -m tcp --dport 800 -j KUBE-FW-RVAFSEPDPUT7VZG7
-A KUBE-SERVICES -d 172.21.0.3/32 -p tcp -m comment --comment "kube-system/aabb:web loadbalancer IP" -m tcp --dport 800 -j KUBE-FW-RVAFSEPDPUT7VZG7
-A KUBE-SERVICES -d 172.21.0.4/32 -p tcp -m comment --comment "kube-system/aabb:web loadbalancer IP" -m tcp --dport 800 -j KUBE-FW-RVAFSEPDPUT7VZG7

# první pravidla označí packet pro pro pozdější MASQUARADING tedy SNAT (aplikace v podu tak neuvidí naší reálnou IP adresu)
# druhé pošle na pravidlo pro SVC
# třetí dropne všechno co nematchujeme
-A KUBE-FW-RVAFSEPDPUT7VZG7 -m comment --comment "kube-system/aabb:web loadbalancer IP" -j KUBE-MARK-MASQ
-A KUBE-FW-RVAFSEPDPUT7VZG7 -m comment --comment "kube-system/aabb:web loadbalancer IP" -j KUBE-SVC-RVAFSEPDPUT7VZG7
-A KUBE-FW-RVAFSEPDPUT7VZG7 -m comment --comment "kube-system/aabb:web loadbalancer IP" -j KUBE-MARK-DROP

# jump na service endpoint
-A KUBE-SVC-RVAFSEPDPUT7VZG7 -m comment --comment "kube-system/aabb:web" -j KUBE-SEP-HJ3ILSU6YG25RESJ
# SNAT traffic který se vrací
-A KUBE-SEP-HJ3ILSU6YG25RESJ -s 10.42.2.3/32 -m comment --comment "kube-system/aabb:web" -j KUBE-MARK-MASQ
# DNAT na pod konrétní pod který je schován v endpointu (kb get endpoints)
-A KUBE-SEP-HJ3ILSU6YG25RESJ -p tcp -m comment --comment "kube-system/aabb:web" -m tcp -j DNAT --to-destination 10.42.2.3:8000

# podobné pravidlo je vytvořeno pro NODEPORT
-A KUBE-NODEPORTS -p tcp -m comment --comment "kube-system/aabb:web" -m tcp --dport 32444 -j KUBE-MARK-MASQ
-A KUBE-NODEPORTS -p tcp -m comment --comment "kube-system/aabb:web" -m tcp --dport 32444 -j KUBE-SVC-RVAFSEPDPUT7VZG7
```

## Ingress controller
[https://kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/)  
[https://traefik.io/blog/kubernetes-ingress-service-api-demystified/](https://traefik.io/blog/kubernetes-ingress-service-api-demystified/)  
K3D používá jako ingress controller traefik a vlastně ingres kontroler není nic jiného než kontroler který sedí v kubernetes a pokud uděláte objekt typu ingress tak on ho promítne do svojí konfigurace.  
V předchozí části jsme si ukázali LB a představte si traffic flow jako LB na jehož konci je traefik a ten dál pokračuje v cestě na základě svojí definice.  
Takže 
```sh
➤ oc get pods -n kube-system traefik-97b44b794-s9n8n -o yaml|neat|vim -


➤ kb create namespace ing
➤ kb create deployment nginx --image=nginx -n ing
➤ kb create service clusterip nginx --tcp=80:80 -n ing

```
```ing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
    # traefik.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: ingress
    http:
      paths:
      - path: /absent
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
```
```sh
➤ curl http://ingress/absent/
```
[https://doc.traefik.io/traefik/v2.4/configuration/backends/kubernetes/](https://doc.traefik.io/traefik/v2.4/configuration/backends/kubernetes/)  

##  DNS
možná jsme to měli vzít dřív ale nějak sem nevěděl kam to zařadit  
[https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)  

## DOMÁCÍ PRÁCE
Na Traefiku v k3d nefunguje z nejakeho duvodu **rewrite-target** annotace.  
Vytořte tedy libovolnou aplikaci (klidně statickou html stránku) a skuste k ní nakonfigurovat přístup přez Ingress.
Skuste přijít na to proč anotace nefunguje (já to nevím), případně nainstalujte jiný ingress kontroler než traefik (třeba NGINX) a testněte zda rewrite-target funguje zde.


{{< figure src="img/rewritetarget-ingress.png" caption="rewrite-target" >}}

### ŘEŠENÍ

```sh
#nainstaluju cisty cluster
k3d cluster create deadless -a 2
kb create namespace app
kb config set-context --current --namespace app
kb create deployment nginxapp --image=nginx 
kb create service clusterip nginxapp --tcp=80:80 
# /usr/share/nginx/html/index.html na nginx containeru upravim 
kb exec nginxapp-74c8bd997c-4brpg -- bash -c "echo Hello NgINXapp >  /usr/share/nginx/html/index.html"

```
```yaml
#create ingress resource
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginxapp
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
    traefik.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: nginxapp.k3d.local
    http:
      paths:
      - path: /absent
        pathType: Prefix
        backend:
          service:
            name: nginxapp
            port:
              number: 80
# tato definice nam rika, pokud prijde nekdo na host  http://nginxapp.k3d.local/absent nasmeruj ho na servisu nginxapp a vsechno co je za
# / smaz (rewrite-target)
```
```sh
# jenze to nefunguje
curl http://nginxapp.k3d.local/absent
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.21.1</center>
</body>
</html>

#koukneme na logy
kb logs nginxapp-74c8bd997c-4brpg
2021/08/03 14:04:00 [error] 33#33: *1 open() "/usr/share/nginx/html/absent" failed (2: No such file or directory), client: 10.42.1.2, server: localhost, request: "GET /absent HTTP/1.1", host: "nginxapp.k3d.local"
# ok porad to smeruje na /absent
```
Nechtelo se mi uplne patrat kde je problem v traeffiku ktery by jako ingress controller mel tenhle problem resit a misto toho pouzijeme jako controller NGINX
```sh
# install nginx controleru 
kubectl create namespace ingress-external
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install  nginx-ingress-external ingress-nginx/ingress-nginx -n ingress-external --set controller.ingressClass=nginx-external --set --enable-ssl-passthrough=true
```
```sh
kb get pods -n ingress-external
kb describe pod -n ingress-external svclb-nginx-ingress-external-ingress-nginx-controller-4pqlq
#neni mozne mit soubeh dvou podu na stejnem portu (80,443) - klipper
#ok smazeme traefik lb service
kb delete svc -n kube-system traefik
# a vytvorime novy ingress controller s pouzitou ingress class
```
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginxapp
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /
    kubernetes.io/ingress.class: "nginx-external"
spec:
  rules:
  - host: nginxapp.k3d.local
    http:
      paths:
      - path: /absent
        pathType: Prefix
        backend:
          service:
            name: nginxapp
            port:
              number: 80
```
```sh
#test
curl http://nginxapp.k3d.local/absent
Hello NgINXapp
```
Na Nginx ingress controleru je taky krasne videt injektnuti CR Ing do konfigurace
```sh
kb exec -n ingress-external nginx-ingress-external-ingress-nginx-controller-5976cfbfff4shrl -- bash -c "cat /etc/nginx/nginx.conf"
```
