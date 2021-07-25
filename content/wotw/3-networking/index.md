---
title: "Základy síťování v kubernetes [WOTW-3]"
date: 2021-07-21 
author: Tomas Dedic
description: "Desc"
lead: "workshop"
categories:
  - "wotw"
---
## KUBERNETES NETWORKING
Dneska se podíváme na základy síťování v kubernetes. Zběžně to proběhneme, bude asi více potřeba se ve volném čase zaměřit na studijní materiály
ale pokud se nějak rozumně vejdeme do času tak část probereme a základní koncepty probereme. Pro ty z vás kdo se těšil na LoadBalancer a Ingress tak ty zklamu tam se
dnes nedostaneme.  

[services-networking](https://kubernetes.io/docs/concepts/services-networking/)  

Zde je popis názornější, ale stejně bych doporučil přečíst si vícekrát a případně se na problematická pasáže zeptal:  
[pods-networking](https://medium.com/google-cloud/understanding-kubernetes-networking-pods-7117dd28727)  
[services-networking](https://medium.com/google-cloud/understanding-kubernetes-networking-services-f0cb48e4cc82)  
[nodeport-loadbalancer-ingress-networking](https://medium.com/google-cloud/understanding-kubernetes-networking-ingress-1bc341c84078)  
[network-namespaces](https://blog.scottlowe.org/2013/09/04/introducing-linux-network-namespaces/)  

Pár obrázků které celkem slušně definují celý koncept:
{{< figure src="img/pod_networking.png" caption="pod-networking" >}}
{{< figure src="img/overlay-network.png" caption="overlay-network" >}}
{{< figure src="img/service_networking.png" caption="service-network" >}}
{{< figure src="img/kube_proxy.png" caption="kube-proxy" >}}
{{< figure src="img/nodeport.png" caption="nodeport" >}}

Nechci vás úplně odradit, síťování není uplně složité jak se zdá, stačí pochopit pár základních konceptů.
  
## DOMÁCÍ ÚKOL [240 XP]
  1. **Vytvořte kontejner s programem (programovým vybavením) který vypisuje jeden náhodný řádek ze souboru (podobně jako v minulém úkolu, jen nyní bude řádek publikován jako HTTP na portu jaký definujete) a  tento řádek publikuje jako http response na http request.**
  Opět je jedno jaký programovací jazyk použijete.  
    
    hinty:
    - pro python třeba simpleHTTP
    - pro golang net/http package
    - pro shell třeba netcat:  while true; do { echo -e 'HTTP/1.1 200 OK\r\n'; cat file;.... } | nc -l 8080; done  
  soubor pro načtení: 
```sh
cat <<EOF >filetoranderize
"We can't possibly have a summer love.
So many people have tried that the name's become proverbial. 
Summer is only the unfulfilled promise of spring, a charlatan in place of the warm balmy nights I dream of in April.
It's a sad season of life without growth...It has no day."
- F. Scott Fitzgerald

"Everyone tries to make his life a work of art. 
We want love to last and we know that it does not last; even if, by some miracle, it were to last a whole lifetime, it would still be incomplete. 
Perhaps, in this insatiable need for perpetuation, we should better understand human suffering, if we knew that it was eternal. 
It appears that great minds are, sometimes, less horrified by suffering than by the fact that it does not endure. 
In default of inexhaustible happiness, eternal suffering would at least give us a destiny. 
But we do not even have that consolation, and our worst agonies come to an end one day. 
One morning, after many dark nights of despair, an irrepressible longing to live will announce to us the fact that all is finished and that suffering has no more meaning than happiness.”
- Albert Camus

I’m already my future corpse. 
Only a dream links me to myself —
The hazy and belated dream 
Of what I should have been — a wall 
Around my abandoned garden. 
Take me, passing waves, 
To the oblivion of the sea 
Bequeath me to what I won’t be —
I, who raised a scaffold 
Around the house I never built. 
- Fernando Pessoa
EOF
```

  2. **kontejner nahrajte do vaší container repository container repository**
  3. **vytvořte servisu typu ClusterIP která bude bude port na PODu referencovat (selector)**
  4. **pro kontejner vytvořte Deployment v k3d a nějakým způsobem se na port pro servisu připojte (curl http://service-name:port)**
  
    hinty:
    - IP adresa podu by měla být v kubectl get endpoints
    - pokud se chcete připojit ze svého localhostu je potřeba port forwardovat k vám (kb port-forward)
    - možnost je vytvořit si kontejner obsahující curl na tento kontejner se připojit (kubectl exec ... a spustit curl ale pozor na adresu pro SVC)
 5. **pro ten samý kontejner vytvořte servisu typu NodePort**
 6. **testněte přístup ze svého localhostu**
 7. **podívejte se na váš k3d cluster a zjistěte mi rozsahy sítí pro PODY (pod CIDR), rozsah sítí pro nody (node CIDR) a rozsah sítí pro servisy (service CIDR)**
