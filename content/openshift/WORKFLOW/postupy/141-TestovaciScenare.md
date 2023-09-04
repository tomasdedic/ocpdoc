## 141. Testovací scénáře

### 1. Výpadek master nodu v SRM poolu a jeho stěhování do druhé lokality
**Očekávaný stav:**  
    Nebude mít žádný dopad na funkčnost clusteru. Control plane bude stále v quoru.  
**Opravné kroky:**  
    Provedeme failover SRM poolu na druhou lokalitu. Zjistíme stav memberů v ETCD, tedy zda jsou skutečně 3 členové.  
**Akceptační kritéria:**  
    Počet master nodů=3, počet memberů v ETCD=3  
**Pracnost:**  
    S
  
**Výsledek:** Výpadek master nodu neměl žádný dopad na funkčnost clusteru. SRM failover nebyl testován

### 2. Výpadek jedné lokality
Jelikož master nody jsou mezi lokalitami rozděleny disproporčně, provedeme výpadek na straně majority master nodu.  
**Očekávný stav:**  
    Control plane přijde o quorum, API server se přepne do readonly nastavení. Jelikož je API server bez zápisu, nebude možné provést
    automatický rescheduling workloadu v postižené lokalitě na druhou lokalitu.  
**Opravné kroky:**  
    Provedeme failover SRM poolu na druhou lokalitu a/nebo vytvoříme v druhé lokalitě nový master nod a přidáme ho do poolu. Zjistíme stav memberů v ETCD, tedy zda jsou skutečně 3 členové.
    Worload by se měl začít schedulovat na workernody v druhé lokalitě dle svých priorityclass.
**Akceptační kritéria:**  
    Počet master nodů=3, počet memberů v ETCD=3, běžící workload do limitu zdrojů (nějaký workload může zůstat ve stavu "pending")
**Pracnost:**  
    S
  
**Výsledek:**  
Openshift API není funkční, ETCD není funkční jelikož má na sobě "proby" kontrolující majoritu (tedy nejede v jedné instanci). Samotné aplikace jedou DC1/DC2, pokud je v jejich logice volání OCP API budou failovat.  
Po nastartování master nodů došlo  ke spojení ETCD a získání  majority a nastartuje API.


### 3. Výpadek nodu s přidělenými více EgressIP
**Očekávný stav:**  
    Workload namespacu s definovaným Egress se nedostane po dobu failoveru na outbound, EgressIP bude automaticky přestěhována na dostupný nod.  
**Opravné kroky:**  
    Vše by se mělo provést automaticky, jde jen o zjištění doby trvání failoveru pro EgressIP a vyhodnocení dopadu.  
**Akceptační kritéria:**  
    Zjištění doby failoveru vícero egressIP adres na jiný nód.
    
**Poznámka:**  
    Otestovat myšlenku více egressIP pro jeden namespace, případně sdílení egressIP mezi vícero namespace(Openshift 4.12).  
**Pracnost:**  
    S
  
**Výsledek:**
Jakmile je nod labelován jako **k8s.ovn.org/egress-assignable**, EgressIP operator prezentován jako ovnkube-master pod bude periodicky kontrolovat zda je nod použitelný.
EgressIP adresy přidělené nodu který není dosažitelný jsou přesunuty na jiný dosažitelný nod.  
Periodická  kontrola dostupnosti egres nodu je definovana v kubernetes OVN na periodu 5 sekund.  
Aplikace používající egressIP z poolu vypnutého nodu budou mit packet lost pro outbound po dobu failoveru na jiný nód to je cca 10s.
Nepovedlo se dokázat že větší množství egressIP pro které je potřeba provést failover mají vazbu na délku failoveru samotného a tedy dopad na dostupnost aplikačního outboundu.

### 4. Znefunkčnění celého clusteru a jeho GITOPS obnova
**Očekávný stav:**  
    Nefunkční cluster  
**Opravné kroky:**  
    Vytvoření nového clusteru, připojení systémového a aplikačního ArgoCD a jeho všech zdrojů. Validace průběhu vytvoření všech původních objektů.  
**Akceptační kritéria:**  
  Množství řádků limitně se blížící nule.  
  ```bash
  oc get pods --field-selector status.phase!=Running,status.phase!=Succeeded  --all-namespaces
  ```
**Pracnost:**  
    S
      
**Výsledek:**  
Test proveden s dostatečným množstvím dummy aplikací na testovacím clusteru. Chybějící kroky dopsány do GITOPS sys flow, ArgoCD SYS bootstrap.

### 5. Výpadek "network" nodu ve vazbě na ingressControler
**Očekávný stav:**  
    Nefunkční network nod, pod pro ingressControler ve stavu pending  
**Opravné kroky:**  
    Funkční network nod  
**Akceptační kritéria:**  
    Trafic směřující z venku přez ingress kontroler nebyl omezen.  
**Pracnost:**  
    XS
  
**Výsledek:**  
Ingress kontroler běží v RS=4, rozprostřeny přez všechny "network node" pro daný cluster. Ingresscontroller běží jako hostNetwork tedy na definovaném portu každého "network nodu". V případě pádu ingress nodu jde o to po jaké době F5 jako loadbalancer přestane na neodpovídající nod posílat requesty. Proby na F5 jsou pro tcp nastany na 5s a po 3 neúspěšných pokusech je member vyřazen, celková doba vyřazení memberu z LB je tedy **16s**.

### 6.Distribuce requestů mezi vícero ingress kontrolerů
**Očekávný stav:**  
    Requesty jsou dle nastavení F5 loadbalancer posílány na jednotlivé membery.  
**Akceptační kritéria:**  
    Prověření normálního rozložení requestů mezi jednotlivé ingresscontrolery.  
**Pracnost:**  
    XS
      
**Výsledek:**  
Ingress kontroler běží v RS=4, rozprostřeny přez všechny "network node" pro daný cluster. Ingresscontroller běží jako hostNetwork tedy na definovaném portu každého "network nodu". F5 na základě interních mechanismů odesílá střídavě requesty na jednotlivé membery. Pro tcp je použit **roundrobin**. 

### 7.Test alertingu pro kritické prvky infrastruktu
**Očekávný stav:**   
    Alerty jsou doručeny dle konfigurace alertManager  
**Akceptační kritéria:**  
    Alerty byli doručeny dle konfigurace alertManager  
**Pracnost:**  
    S
  
Výsledek: 

### 8.Jak se cluster zachová, když mu přetížíme jeden, dva X node. Jak rychle přestěhuje, jestli vůbec. Tady bych rád věděl, jak se cluster zachová, když v něm jeden nebo dva node (abych byl exaktní - cca 20% kapacity clusteru) vyžere výkon
**Očekávný stav:**  
    Nestane se nic, nový workload bude schedulován na nezatížené nódy.  
**Akceptační kritéria:**  
    Nestalo se nic, nový worload byl schedulován na nezatížené nódy.  
**Pracnost:**  
    S
  
**Výsledek:**  
Workload na nodu se sám stěhovat nebude. Další workload bude plánován na nezatížené nody dle hodnotících kritérií a samozřejmě nastevení deploymentu samotného, ale pokud nedojde k pádu aplikace nebude přestěhována z původních zatížených nodů. 

Scheduling na nod je v době deploymentu definován pouze na úrovni následujících váhových ohodnocení
```yaml
{"name" : "LeastRequestedPriority", "weight" : 1},
{"name" : "BalancedResourceAllocation", "weight" : 1},
{"name" : "ServiceSpreadingPriority", "weight" : 1},
{"name" : "NodePreferAvoidPodsPriority", "weight" : 1},
{"name" : "NodeAffinityPriority", "weight" : 1},
{"name" : "TaintTolerationPriority", "weight" : 1},
{"name" : "ImageLocalityPriority", "weight" : 1},
{"name" : "SelectorSpreadPriority", "weight" : 1},
{"name" : "InterPodAffinityPriority", "weight" : 1},
{"name" : "EqualPriority", "weight" : 1}
```
+ LeastRequestedPriority: The node is prioritized based on the fraction of the node that would be free if the new Pod were scheduled onto the node. (In other words, (capacity - sum of requests of all Pods already on the node - request of Pod that is being scheduled) / capacity). CPU and memory are equally weighted. The node with the highest free fraction is the most preferred. Note that this priority function has the effect of spreading Pods across the nodes with respect to resource consumption.

+ CalculateNodeLabelPriority: Prefer nodes that have the specified label.

+ BalancedResourceAllocation: This priority function tries to put the Pod on a node such that the CPU and Memory utilization rate is balanced after the Pod is deployed.

+ CalculateSpreadPriority: Spread Pods by minimizing the number of Pods belonging to the same service on the same node. If zone information is present on the nodes, the priority will be adjusted so that pods are spread across zones and nodes.

+ CalculateAntiAffinityPriority: Spread Pods by minimizing the number of Pods belonging to the same service on nodes with the same value for a particular label.

### 9.Zjištění limitů ingress nodu
Budeme testovat přetěžování ingress nodu v izolovaném prostředí kde bude jako ingresscontroler sloužit pouze jeden pod a distribuovat zátěž na několik aplikačních cílových podů.  
**Očekávný stav:**  
   Postupné zpomalování odpovědí, možné HTTP error.  
**Akceptační kritéria:**  
   Definice limitů pro ingress.  
**Pracnost:**  
    M
      
**Výsledek:**  
Testované maximum bylo 4000 kind:Ingress per jeden IngressClass. Při tomto maximu nebyly pozorovány problémy s routerem  pro danou IngressClass. Doporučená hodnota RH je 2000 kind:Ingress na jeden ingress controller.

## Vyhodnocovací nástroje
Pro vyhodnocení dopadu jednotlivých testovacich scénářů využijeme Cerberus (celkový pohled na cluster) a pak standartní monitorovací nástroje Prometheus/Grafana.

