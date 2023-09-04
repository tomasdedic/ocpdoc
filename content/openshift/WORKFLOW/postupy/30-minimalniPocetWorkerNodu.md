## 30. Minimální počet worker nodu pro zajištění HA aplikací během upgrade
Minimální počet worker nodu se dá definovat jako 3 , rozprostřeny přez mezi dvěma lokalitami.\
Při tomto malém počtu nodů je potřeba při HA upgrade počítat s minimálním množstvím volných resourců jako **1/počet_nodu z celkové kapacity worker poolu** (jak CPU tak RAM). Zároveň je potřeba počítat s možností že nějaký workload může vyžadovat velké množství zdrojů které sice v celkovém součtu jsou ale nejsme schopni tento workload naschedulovat na jeden konkrétní nód. Podobný scénář bude vyžadovat servisní zásah a přesun některého workloadu tak aby byl požadované množství zdrojů na jednom nodu uvolněno.

| počet worker nodu   |  maxUnavailable   | volná kapacita |
|--------------- | --------------- | ------------------ |
| 3 - 9       | 1   |        1/počet_worker_nodu z celkové kapacity worker poolu |
| >10        | 10%   |                  1/10 celkové kapacity worker poolu |

Dá se však říci že pro clutery vyšších prostředí bude vždy **množství worker nodů >10** a dále s tím tak budeme počítat.

Upgrade probíhá s nastavením **"maxUnavailable=10%"** tzn v jeden okamžik bude nedostupný maximálně 10% worker nodů. Zároveň v průběhu upgrade je proveden cordon a drain, tedy je zastaveno schedulování na postižený nody a aplikace jsou bezpečně terminovány a přesunuty na nod jiný.\
HA pro aplikace jsme schopni udržet pouze pokud mají nastaven **podDistruptionBudget** například na **minAvailable=1** a musí běžet v replicaSetu > 1.\
Pro aplikace běžící v **RS=1** nejsme schopni zajistit HA v průběhu upgrade procesu.

Z pohledu upgrade je vhodné držet minimální množství volných zdrojů tak aby byla možnost provést reschedule workloadu na ostatní běžící worker nody v průběhu upgrade. Tzn volná kapacita při stejné velikosti worker nodu by měla být > 10% (vhodnější je spíše 20%) jak pro CPU tak pro paměť.

Pro samotné applikace bude použit defaultně **PodTopologySpread** scheduler plugin.
```yaml
defaultConstraints:
  - maxSkew: 3
    topologyKey: "kubernetes.io/hostname"
    whenUnsatisfiable: ScheduleAnyway
  - maxSkew: 5
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: ScheduleAnyway
```

Aplikace si mohou zároveň definovat vlastní **spreadTopologyConstraints** na úrovni podAPI, tak aby repliky byly "rovnoměrně" rozprostřeny mezi lokalitami. Pokud má aplikace tento spec nastaven bude mít prioritu před defaultním nastavením scheduleru.\
Je třeba říci že je vhodnější pokud by si aplikace nastavovali tento parametr sami jelikož chování scheduler pluginu je značně benevoletní.
```yaml
kind: Pod
apiVersion: v1
metadata:
  name: mypod
  labels:
    app: part1
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone 
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: part1
```

