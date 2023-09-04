# ONBOARDING TLDR 
  
# 1. Od SASU k Openshift aplikaci
{{< figure src="wizard.jpg" width=600 >}}

## 1.1 ŽÁDOST O SAS (SAS v příkladu je MOJEAPP)
**SAS_MOJEAPP** je duležitý jak bude vidět dále.
pozn: Použití znaků  '\_' a '-' je trochu chaotické, konkrétně to vypadne z kontextu, někde '\-_' jsou zakázané znaky.

**Po získání SAS id je potřeba si na základě SASu zažádat o projekt na platformě Openshift.**

## 1.2 GIT repozitáře

tento repozitář vznikne automaticky v rámci flow:
- **(CD část) https://github.com/csas-ops/mojeapp-ocp4s-apps**

tento repozitář je potřeba zažádat:
- **(CI část) https://github.com/csas-dev/mojeapp-komponent-app**

  [ServiceNow Ticket](https://csasprod.service-now.com/sp?id=sc_cat_item&sys_id=a74a1c89db6fa0502493d6a2f3961958)
  A protože je to jiná organizace v githubu, tak budou nové skupiny a o ty si musí v Redimu požádat. Vytvoří se ale až po založení toho repa.
  >Pro členství v týmu je potřeba si požádat o Windows skupinu v Redimu, která je ve formátu GHB_{ORG}_{CMDB_ID}_{ROLE}, kde {ORG} je zkratka organizace (DEV/SEC/OPS/OSS), {CMDB_ID} je "SAS" aplikace (bez prefixu "SAS_"), která tým reprezentuje a {ROLE} je jedna z [ADM, WRITE, READ]. Tyto skupiny vytvoří DevTools při zakládání týmu.
```sh
NAME OF THE REPOSITORY  : komponent-app
APPLICATION SYSTEM      : MOJEAPP (SAS_MOJEAPP)
GITHUB ORGANIZATION     : csas-dev
FINAL REPOSITORY URL    : https://github.com/csas-dev/mojeapp-komponent-app
```
  role v redimu: **GHB_DEV_MOJEAPP_WRITE v případě potřeby admina pak GHB_DEV_MOJEAPP_ADMIN**

  Role "write" do Artifactory ma jen organizace **csas-dev**

{{< figure src="artifactory-CSAS.png" caption="flow" width=200  >}}

## 1.3 AUTOMATICKY VZNIKLÉ OBJEKTY V OCP
Na OCP se nám na základě žádosti vzniknou následující objekty které definují projekt
```yaml
# základní definice projektu
➤ oc get projects.ops.csas.cz mojeapp
NAME      AGE
mojeapp   54d

# definice projektu pro argoCD
# jednotliva prostredi dev,int,prs jsou definovana pro konkretni cluster, jiny cluster muze mit prostredi jina
➤ oc get appprojects.argoproj.io -n csas-argocd-app|grep mojeapp
mojeapp-dev        54d
mojeapp-int        54d
mojeapp-prs        54d

➤ oc get appprojects.argoproj.io -n csas-argocd-app mojeapp-dev -o yaml|neat
#shortened
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: mojeapp-dev
  namespace: csas-argocd-app
  roles:
  - groups:
    - OCP_MOJEAPP_DEV
    - OCP_MOJEAPP_OPS
  - groups:
    - OCP_MOJEAPP_USR
    name: view
  sourceRepos:
  - git@github.com:csas-ops/mojeapp-*.git
  - https://github.com/csas-ops/mojeapp-*.git
  - https://artifactory.csin.cz/artifactory/mojeapp-helm
  - https://artifactory.csin.cz:443/artifactory/mojeapp-helm

# definice aplikace pro argoCD
➤ oc get applications.argoproj.io --namespace csas-argocd-app mojeapp-dev-apps -o yaml|neat
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mojeapp-dev-apps
  namespace: csas-argocd-app
spec:
  destination:
    namespace: mojeapp-dev #pozor na prostredi
    server: https://kubernetes.default.svc
  info:
  - name: description
    value: System Application used for synchronization of user provided Application
      objects
  - name: project
    value: mojeapp
  - name: environment-name
    value: dev
  - name: environment-type
    value: dev
  project: mojeapp-dev #pozor na prostredi
  source:
    path: .
    repoURL: https://github.com/csas-ops/mojeapp-ocp4s-apps.git
    targetRevision: env/dev  #pozor na prostředí
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
Jelikož jsme v příkladu v  prostředí **dev** budeme pouzivat Namespace **mojeapp-dev**

## 1.4 BUILD APLIKACE/HELMCHARTU GITHUB ACTIONS

[CI git repo](git@csas_github.com:csas-dev/mojeapp-komponent-app)
```sh
#napriklad jen jednoduchy byild Dockerfile
#containerFile really simple
FROM alpine:3.15.5
RUN apk --update add bash gawk
```

Github actions snippet:
```yaml
#GHA env snippet nastaveni repozitaru
env:
  ARTIFACTORY_URL: artifactory.csin.cz
  CHART_REPOSITORY: https://artifactory.csin.cz:443/artifactory/mojeapp-helm-local
  IMAGE_REPOSITORY: artifactory.csin.cz/mojeapp-docker-local/mojeapp
```
image se pushne s generovanym tagem:
**0.0.0-master.0c64f524-expire2208221434**

## 1.5 ARGOCD DEPLOYMENT
(CD git repo) git@csas_github.com:csas-ops/mojeapp-ocp4s-apps.git  

vytvorime csas application v branch **env/dev** s values pro HELM chart (redis subchart referencujeme jeho aliasem tedy "redis")
```yaml
apiVersion: ops.csas.cz/v1
kind: Application
metadata:
  name: mojeappkomponent
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  source:
    repoURL: https://artifactory.csin.cz/artifactory/mojeapp-helm
    chart: komponent-app
    targetRevision: 0.0.0-master.0c64f524-expire2208221434
    helm:
      values: |
        myvalues: {}
```
**Application.ops.csas.cz operator se postará o transformaci a uložení v podobě CRD **application.argoproj.io**  do NS csas-argocd-app a následne tak vznikne argoCD aplikace kontrolující námi definovanou aplikaci**

# 2. Ingress Controllers walkthrough
## 2.1 Výběr Ingress pro aplikaci (jakým způsobem se do mojí aplikace dostanou data z "venku")
Každý cluster s vyjímkou LAB clusteru má několik typu ingressControlleru (F5 VIP + HAProxy PODu).
Každý controller obsluhuje konkretní sadu routes v Openshiftu na základě labelingu těchto **rout**.

**Systémové routery:**
Při vytváření objektu je možné nechat doménu (Hostname) vygenerovat a není nutné ji specifikovat (platí pouze pro Route, nikoliv pro Ingress) Tento router není určený pro aplikační workload (pouze pro systémový).

|jméno   |  router label  | doména    | popis    |
|------- | ------------- | --------- | -------- |
| default| ingress-router: default |*.apps.<CLUSTER_NAME>.<BASE_DOMAIN> | Routy, které jsou standardně v openshiftu a nejsou aplikacemi ČS a.s. Běžně například GUI konzole, interní kibana, ArgoCD atd.    |

**Aplikační routery:**
Při vytváření objektu do těchto routerů, je nutné vždy uvést celou doménu (Hostname). Bez toho by doména byla vygenerována ve špatném tvaru a aplikace by nefungovala. Je to známá chyba v OCP a momentálně to řeší RedHat. **Tyto routery jsou určeny pro aplikační workload.**

|jméno   |  router label  | doména    | popis    |
|------- | ------------- | --------- | -------- |
| fe| ingress-router: fe |*.fe.<CLUSTER_NAME>.<BASE_DOMAIN> | Aplikace ČS a.s., které jsou dostupné pro koncového zákazníka z interní sítě. |
| be| ingress-router: be |*.be.<CLUSTER_NAME>.<BASE_DOMAIN> | Aplikace ČS a.s., které jsou dostupné z datového centra a aplikace je určena jako backend komponenta. |
| dmz| ingress-router: dmz |*.dmz.<CLUSTER_NAME>.<BASE_DOMAIN> | Aplikace ČS a.s., které mají být umístěny v DMZ |

```yaml
# example ingress manifest with ignress-router: fe
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    route.openshift.io/termination: edge
  generation: 2
  labels:
    ingress-router: fe
spec: {}

```

## 2.2 TLS certifikáty
### 2.2.1 Použiji defaultní certifikát routeru
Není potřeba se starat o TLS certifikát, ingres bude zabezpečen defaulním certifikátem routeru.
Bude použit * certifikát dle typu routeru tedy *.apps.<CLUSTER_NAME>.<BASE_DOMAIN>,*.fe.<CLUSTER_NAME>.<BASE_DOMAIN>,*.be.<CLUSTER_NAME>.<BASE_DOMAIN>,*.dmz.<CLUSTER_NAME>.<BASE_DOMAIN>
```yaml
# Pouze anotujeme typ terminace na routeru na  edge
# pro fe router například
kind: Ingress
metadata:
  annotations:
    route.openshift.io/termination: edge
  labels:
      ingress-ruter: fe
spec: {}

```

### 2.2.2 Použiji vlastní TLS certifikát/klíč

```shell
# vytvoreni secretu, nezapomenout kubeseal
oc create secret tls tlscert  --key=host.key --cert=host.crt -o yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  labels:
    ingress-router: fe
spec:
  rules:
  - host: hosttls.csint.cz
    http:
      paths:
      - backend:
          service:
            name: service
            port:
              number: 8080
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - hosttls.csint.cz
    secretName: tlscert
```

# 3. Sealed secrets (jakým způsobem uložit secrets v GITU tak aby nebyli v plaintextu)
V GitOps je nutne dorucovat Secrets do clusteru v zasifrovane podobe. Samostatne Secrets nesmi lezet v GITu z duvodu jejich jednoducheho precteni (neni v zasifrovane podobe, ale pouze v base64 formatu). K tomuto zasifrovani a naslednemu rozsifrovani az v clusteru je vyuzito komponenty Sealed Secrets., ktera je v kazdem clusteru instalovana. V pripade pouzivani multiclusteroveho reseni maji clustery patrici k sobe stejne klice k rozsifrovani tajemstvi.

**Neukladejte do GITu objekty typu Secret, ale pouze objekty typu SealedSecret.**


## 3.1 Příprava objektu SealedSecret z původního Secret
[kubeseal download](https://github.com/bitnami-labs/sealed-secrets/releases)

Varianta 1: pouziti sifrovaciho certifikatu z URL
```shell
kubeseal --scope namespace-wide --cert https://certificate-sealed-secrets.apps.<CLUSTER_NAME>.<BASE_DOMAIN>/v1/cert.pem < secret.yaml > sealedsecret.yaml
```

Varianta 2: pouziti sifrovaciho certifikatu v souboru
```shell
#certifikat lze ziskat jako
kubeseal --fetch-cert --controller-name sealed-secrets --controller-namespace sealed-secrets > cert.pem

kubeseal --scope namespace-wide --cert cert.pem < secret.yaml > sealedsecret.yaml
```

Kubeseal je použit ve scope **namespace-wide**, což znamená, že při dešifrování musí odpovídat jméno namespace. Default (pokud scope neuvedete) je strict, kdy navic musi odpovidat i jmeno secretu. Scope namespace-wide je dostatečně bezpečný v prostředí ČS a zároveň má vyšší míru komfortu při použití než scope strict. Navíc scope namespace-wide odpovídá CI/CD sample aplikacím.

Misto souboru cert.pem, lze vyuzit URL odkaz k certifikatu (nefunguje pokud se pouziva proxy server). URL adresu k certifikatu je mozne ziskat na strance vseobecne informace k jednotlivym clusterum (kazdy cluster ma vlastni prostor).

## 3.2 Bezpečnostní omezení
Vytvořený SealedSecret objekt je svázán se jménem namespace, do kterého ma Secret patřit. To znamená, že pokud měl Secret definován *metadata.namespace: example*. Sealovany objekt SealedSecret musí být založen v *namespace jménem example*. V případě, že bude zalozen do namespace jiného jména, nebude jeho rozšifrování možné a nikdy nevznikne objekt Secret.

Pokud již existuje v daném namespace nějaký Secret stejného jména jako vkládaný SealedSecret, **původní secret nebude přepsán a SealedSecret v popisu vrátí chybu. Pokud takto chcete učinit, musíte nejdříve původni Secret z namespace odstranit**.

# 4. Zajištění HA pro mojí aplikaci (PDB=pod distruption budget)
Nebudu zde rozepisovat přesnou fukncionalitu PDB ([dokumentace](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) ).
Pro aplikace v openshiftu není nijak defaultně definová distrupce, v tomto případě to může znamenat že i v případě pokud aplikace běži v ReplicaSetu >1 a klidně je rozprostřená přez vícero nodů tak při restartu těchto nodů, například při upgrade, nebude nijak zaručeno že aplikace alespoň v definovaném množství replik poběží.
Právě pro tyto účely je tu PDB který definuje maximální přípustnou distrupci aplikace.

```yaml
# distributor běží v RS=3
# definujeme maximální množství povolené distrupce na 2, což bude znamenat že minimální množství podů bude=1
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: loki-iocp4s-distributor
  namespace: loki-iocp4s
spec:
  maxUnavailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/component: distributor
      app.kubernetes.io/instance: loki-iocp4s
      app.kubernetes.io/name: loki-iocp4s

```

```yaml
# definujeme minimální běžící množství replik=1
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  labels:
    argocd.argoproj.io/instance-sys: csas-application-operator
    control-plane: controller-manager
  name: controller-manager
  namespace: csas-application-operator
spec:
  minAvailable: 1
  selector:
    matchLabels:
      control-plane: controller-manager
```
Pozor je potřeba brát v úvahu **vazbu mezi Replikami a PDB**, není vhodné používat PDB pokud mám RS=1. Další příklad nefunkčního stavu je pokud mám třeba RS=2 a minAvailable=2 a podobně.
**Tato konfigurace úspěšně zastaví upgrade a je jí pak potřeba ručně opravit.**


# 5. Integrace na centralni trustStore
Jak dostat potřebné certifikáty do mojí aplikace.
**Pozor umístění TLS certifikátů ve vaší aplikaci může být různé dle použitého baseImage containeru. Ověřte si prosím s dokumentací.**

Potřebné CA certifikáty ve formátu PEM, JKS a jejich provisioning směrem k workloadu:

## 5.1 custom CA trust (X509)
Konfigurace openshiftu s certifikáty pro CA trust vloženy do CM
```yaml
apiVersion: v1
data:
  ca-bundle.crt: |
    # CAIR3 CSAS
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----

    #CAIMS2
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----

    #CAIMST2
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----

    #CAIRT3
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----
kind: ConfigMap
metadata:
  name: user-ca-bundle
  namespace: openshift-config
```

Injekce certifikátu do ConfigMapy pro použití aplikací:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca
  namespace: appnamespace
  labels:
    config.openshift.io/inject-trusted-cabundle: "true"
```
**Takto labelovaná configmapa bude obsahovat jak náš custom trust tak i obecný RH CA trust**

Reference v aplikaci:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-example-custom-ca-deployment
  namespace: my-example-custom-ca-ns
spec:
  ...
    spec:
      containers:
        - name: my-container-that-needs-custom-ca
          volumeMounts:
          - name: trusted-ca
            mountPath: /etc/pki/ca-trust/extracted/pem
            readOnly: true
      volumes:
      - name: trusted-ca
        configMap:
          name: trusted-ca
          items:
            - key: ca-bundle.crt
              path: tls-ca-bundle.pem
```
## 5.2 JKS trust
Pro vytvoření JKS trustu z CA trust bundlu využijeme funkcionalitu **cert-utils-operatoru** který přez interní keystore vytvoří JKS trust z CA trust bundlu a injektne zpátky do configmapy.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca
  namespace: appnamespace
  labels:
    config.openshift.io/inject-trusted-cabundle: "true"
  annotations:
    cert-utils-operator.redhat-cop.io/generate-java-truststore: "true"
```

Configmapa pak vypadá:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca
  namespace: appnamespace
  labels:
    config.openshift.io/inject-trusted-cabundle: "true"
  annotations:
    cert-utils-operator.redhat-cop.io/generate-java-truststore: "true"
binaryData:
  truststore.jks: ...
data:
  ca-bundle.crt: ...

```

Reference v aplikaci pak může vypadat jako:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-example-custom-ca-deployment
  namespace: my-example-custom-ca-ns
spec:
  ...
    spec:
      containers:
        - name: my-container-that-needs-custom-ca
          volumeMounts:
          - name: trusted-ca
            mountPath: /etc/pki/ca-trust/extracted/pem
            readOnly: true
          - mountPath: /etc/pki/ca-trust/extracted/java
            name: jks-trust
            readOnly: true
      volumes:
      - name: trusted-ca
        configMap:
          name: trusted-ca
          items:
            - key: ca-bundle.crt
              path: tls-ca-bundle.pem
      - name: jks-trust
        configMap:
          name: trusted-ca
          items:
            - key: truststore.jks
              path: cacerts
```
Defaultní heslo pro keystore je **changeit**. Dá se změnit přez anotaci konfigmapy
```yaml
annotation:
  cert-utils-operator.redhat-cop.io/java-keystore-password: heslo
```
Alias pro certifikáty v keystoru je **alias**.


# 6. Openshift Network Policy
Každý aplikační namespace má definované Network policy následovně:
```yaml
allow-from-openshift-ingress
allow-from-openshift-user-workload-monitoring
allow-same-namespace
```
Názvy jsou dostatečně samopopisné (přístup z venku přez ingres, push do metrik, stejný namespace). Pokud projekt potřebuje mít prostupy jiné je potřeba Administrátorský zásah.

