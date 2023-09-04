## 28. Postup pro UPGRADE
[vizualizace možných update cest](https://access.redhat.com/labs/ocpupgradegraph/update_path) 

Obecně se postup pro upgrade clusteru skládá ze dvou částí
- **Cluster Version Operator (CVO) upgrade**
  Postupný upgrade všech podů které definují jednotlivé CVO pro systémovou část Openshiftu. Nad touto částí není možné mít žádnou deklarativní kontrolu a jakmile se spustí dojde k upgrade. Případné problémy se řeší na úrovni jednotlivých operátorů CVO.\
  Proto je vhodné upgrade nejdříve otestovat na nižších prostředích a zůstávat u **stable** upgrade kanálu.\
  V této fázi nedochází k restartu žádných nodů.
- **Machine Config Operator (MCO) node updates** 
  + Cordon and drain all the nodes
  + Update the operating system (OS)
  + Reboot the nodes
  + Uncordon all nodes and schedule workloads on the node\
  Default hodnota pro **maxUnaviable** je jedna takže v jeden okamžik bude updatován pouze jeden nod.
  
### Update channel
Jako update channel bude použit pro všechna prostředí kanál **stable**

### Prerekvizity
Vyřešené konflikty s životním cyklem API zdrojů dle dokumentace RedHat. 

### Časová náročnost upgrade
**Počítáme s množstvím worker nodů >10.
Nastavení MCP pro ".spec.maxUnavailable" bude dle následující tabulky:

| MCP role| maxUnavailable    |
|--------------- | --------------- |
| master   | 1   |
| worker  | 10%   |
| infra   | 1   |

Nód může být součástí maximálně jednoho poolu a nody z každého poolu se upgradují nezávisle, takže podle našeho nastavení se bude najednou updatovat 1 nod z master MCP, 10% z worker MCP a 1 nod z infra MCP.

Celkový čas pak bude odpovídat součtu času pro CVO(cca 60 minut) a maxima času ze všech poolu.
V testovacím clusteru který má 34 nodů (24 worker, 3 master,7 infra) bude tedy celkový čas:
```bash
CELKOVY_CAS = (60 + max((10*10),(3*10),(7*10)) ) + bufferzaokrouhlení ~ 200 minut
```

### Zajištění HA pro aplikace 
Aplikace které musí mít zajištěno HA během restartu, musí mít nastaven **podDistruptionBudget** například na **minAvailable=1** a musí běžet v replicaSetu > 1.\
Pro aplikace běžící v **RS=1** nejsme schopni zajistit HA v průběhu upgrade procesu.

### Canary Update
Pro upgrade kritických **worker** nodů lze použít canary update.\
Kritický worker nod je nakonfigurován a vlastní prostředky tak jak to ostatní nody nemají, není tedy jednoduše zastupitelný obecným nodem.
Zatím nejsou definovány kritické worker nody ale můžeme definovat kritický workload definujicí vlastně tento nód, jako deployment které mají **RS=1 nebo prostě nemohou v jeden okamžik běžet ve více replikách**. Případně to může být nód na kterém běží workload který vyžaduje velké množství resourců a nebylo by možné tento workload přeshedulovat na jiný nod.

Tento workload nebude stěhován na jiný nód automaticky(nod nebude automaticky update a tedy ani nebude potřeba auto drainu) ale proces přesunu vybraného workloadu bude řízen.

**Zároveň pokud nejsme schopni se vejít do servisního okna je vhodné rozdělit pooly na vícero částí a provést upgrade na částech spojitě.** \
Je ale potřeba brát v potaz že **upgrade** není dokončen dokud nejsou upradovány všechny nody.\
\
Nody které nechceme updatnout dáme do samostatného "canary MCP", tento MCO zapauzujeme
```bash
oc label node workernode node-role.kubernetes.io/workerpool-canary=
```

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: workerpool-canary 
spec:
  machineConfigSelector:
    matchExpressions: 
      - {
         key: machineconfiguration.openshift.io/role,
         operator: In,
         values: [worker,workerpool-canary]
        }
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/workerpool-canary: ""
```
V této chvíli MCP zapauzujeme a nody v něm obsažené nebudou updatovány
```bash
oc patch mcp/workerpool-canary --patch '{"spec":{"paused":true}}' --type=merge
```
Pustíme update a počkáme až se provede na všech nodech kromě zapauzovaných. \
Následně odpauzujeme MCP a update se začne provádět na nodech v tomto poolu
```bash
oc patch mcp/workerpool-canary --patch '{"spec":{"paused":false}}' --type=merge
```
Provedeme test aplikací které sjou vázány na tento kontrétní machineConfig (machineConfigPool).\
V případě chyb, provedeme drain a cordon nodů v poolu a donutíme tak aplikaci přesídlit se na jiný nód ve vazbě "taint/tolleration"\
Nod pak můžeme vrátit do původního MCP
```bash
 oc label node workernode node-role.kubernetes.io/workerpool-canary-
```

### EgressIP worker upgrade
Upgrade může být citlivý u nodů držících EgressIP. Nody držicí egressIP jsou v MCP **infra**. Při použití OVN Kubernetes CNI pluginu však dochází k automatickému failoveru
IP adress na jiný nód labelovaný jako **k8s.ovn.org/egress-assignable=""** v případě nedostupnosti nodů, tzn třeba jeho restart.

### Dosažitelnost EgressIP nodu 
Jakmile je nod labelován jako **k8s.ovn.org/egress-assignable**, EgressIP operator prezentován jako ovnkube-master pod bude periodicky kontrolovat zda je nod použitelný.\
EgressIP adresy přidělené nodu který není dosažitelný jsou přesunuty na jiný dosažitelný nod.
  

**Periodická  kontrola dostupnosti egres nodu je "hard coded" na periodu 5 sekund.**

### DR scénář
V případě že se Openshift dostane do stavu nepoužitenosti v rámci upgrade, bude použit DR scénář stejný jako běžný DR scénář popsaný výše v bodě 27.\
Tento stav by v rámci upgrade procesu neměl nastat, resp rozhodně to není běžný stav pokud budeme používat stabilní **stable upgrade channel**


