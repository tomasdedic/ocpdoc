## 27. Definice postupu pro DR 

### Obnova cestou GITOPS
Openshift cluster **se nebudeme snažit obnovovat ze zálohy, kompletní obnova spolu s obnovou ETCD by vyžadovala mít i stejnou hardware konvenci a i tak by byla obnova celé ETCD problematická.**\ Z tohoto pohledu se jeví jako jednodušší,a hlavně proveditelné, obnovit cluster tak že postavíme nový základ tedy controllplane a přidáme potřebný pool worker nodů. Samotný systémový a aplikační workload obnovíme z příslušných GIT repozitářů.\
Je tedy nutné aby aplikace běžící na Openshiftu tento princip dodržovali a všechny jejich definice byly v GITU obsažené.

#### Workflow v závislosti na Project/Application CRD
Openshift cluster používá applicationOperátor a projectOperátor pro automatické vytváření objektů pro jenotlivé aplikace. Všechny projekty pro cluster jsou uloženy v "projektovém repozitáři" a jsou synchronizovány přez Systémové argoCD do clusteru.

**Worflow na základě zjednodušených manifestů:**  
---> z projektového repozitáře, sync přez ArgoCD sys
```yaml
apiVersion: ops.csas.cz/v1
kind: Project
metadata:
  name: bokeh 
spec:
  environments:
    - name: lab
      type: lab
```
---> automaticky vytvořené přez projectOperator na základě project.ops.csas.cz
```yaml
apiVersion: ops.csas.cz/v1
kind: ProjectEnvironment
metadata:
  labels:
    ops.csas.cz/environment-name: lab
    ops.csas.cz/project: bokeh
  name: bokeh-lab
spec:
  applicationSource:
    path: .
    repoURL: https://github.com/csas-ops/bokeh-ocp4s-apps.git
    targetRevision: env/lab
```
---> automaticky vytvořené přez projectOperator na základě projectenvironment.ops.csas.cz
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  labels:
    ops.csas.cz/environment-name: lab
    ops.csas.cz/environment-type: lab
    ops.csas.cz/project: bokeh
  name: bokeh-lab
  namespace: csas-argocd-app
spec:
  destinations:
  - namespace: bokeh-lab
    server: https://kubernetes.default.svc
```
---> automaticky vytvořené přez projectOperator na základě projectenvironment.ops.csas.cz
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  labels:
    ops.csas.cz/environment-name: lab
    ops.csas.cz/project: bokeh
  name: bokeh-lab-apps
  namespace: csas-argocd-app
spec:
  destination:
    namespace: bokeh-lab
    server: https://kubernetes.default.svc
  project: bokeh-lab
  source:
    path: .
    repoURL: https://github.com/csas-ops/bokeh-ocp4s-apps.git
    targetRevision: env/lab
```
---> definováno v Aplikačním repozitáři na který ukazuje předchozí application.argoproj.io
```yaml
apiVersion: ops.csas.cz/v1
kind: Application
metadata:
  labels:
    argocd.argoproj.io/instance-app: bokeh-lab-apps
  name: deva-helloworld-be
  namespace: bokeh-lab
spec:
  source:
    chart: helloworld
    helm:
      values: |
        key: value1
    repoURL: https://artifactory.csin.cz/artifactory/api/helm/bokeh-helm-virtual
    targetRevision: 0.17.0
```
---> vytvořeno applicationOperatorem na základě application.ops.csas.cz
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  labels:
    application.ops.csas.cz/owner-name: deva-helloworld-be
    application.ops.csas.cz/owner-namespace: bokeh-lab
  name: bokeh-lab-deva-helloworld-be
  namespace: csas-argocd-app
spec:
  destination:
    namespace: bokeh-lab
    server: https://kubernetes.default.svc
  project: bokeh-lab
  source:
    chart: helloworld
    helm:
      values: |
        key: value1
    repoURL: https://artifactory.csin.cz/artifactory/api/helm/bokeh-helm-virtual
    targetRevision: 0.1.0

```
{{< figure src="img/gitops-diagram.png" caption="gitops diagram" >}}


#### Popis procesu obnovy
Celá obnova je postavena na principech GITOPS, pro systémovou část může dojít k aplikaci některých objektů v rámci BootStrap fáze. Bootstrap fáze je kompletně skriptovaná. 

- Odstranění původního clusteru. Dostačující je smazání dat disků pro jednotlivé VM například utilitou **dd**.
- Instalace nového clusteru 
  + použití Ansible playbook instalace
- Ověření stavu nově nainstalovaného clusteru (běžné ověření funkčnosti)
- BOOTSTRAPING 
  + rekonfigurace(reflektovat změny pro nový cluster, pokud bude znovupoužita stejná konfigurace infrastruktry nemusí se měnit nic)  + spuštění shell scriptu běžící proti API, dojde k vytvoření a konfiguraci ARGOCD SYS, které následně vytvoří applikace definované v GITHUB repository 
  + příprava a aplikace systémových "secrets" z bezpečného místa 
- ARGOCD SYS: vytvořeno během bootstrapu, aplikuje všechen infrastrukturní workload spolu s komponenty pro ArgoCDAPP
- ARGOCD APP: sledování procesu množícího se deploymentu v ArgoCD APP \
- kontrola běhu aplikací
  Dostačující je zevrubná kontrola běhu, založená na statusu aplikací oproti OC API.
  ```bash
  oc get pods --field-selector status.phase!=Running,status.phase!=Succeeded  --all-namespaces
  ```
  Bližší kontrola by měla být viditelná z metrik s vazbou na jednotlivé aplikace.

#### Časová náročnost
Celková náročnost se dá odhadnout na **2-3** hodiny
