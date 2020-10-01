Pro instalaci a používání OCP v privátní síti bude jako zdroj všech kontejnerů využita Artifactory. Všechny remote repository (vnější) budou whitelistovány přez ní a bude pro ně vytvořena konfigurace.

## Artifactory facts
[Artifactory link](https://artifactory.csas.elostech.cz/ui/login/) -- adresa se může do budoucna lišit udávám jen z důvodu reference

repository: 
+ artifactory.csas.elostech.cz/docker-quay (remote repositoru directed to  **quay.io**)
+ artifactory.csas.elostech.cz/docker-quay-local (local repository for mirroring)

Na artifactory je potřeba konfiguraci typu remote repository vytvořit. Zatím nejsou standartizovány názvy. Obrázek níže je informativního charakteru.
{{< figure src="img/remote_repository_settings.png" caption="artifactory remote repository settings" >}}

## Použití "remote repository" při instalaci OCP (QUAY.IO repository)
Jediný dostupný "container registry" bude pro instalaci v privátní síti "artifactory container registry" proto z instalátoru **install-config.yaml** odstraníme všechny ostatní pull secrety a nahradíme ho pouze pull secretem artifactory. Provedeme konfigurace CRD ImageContentSourcePolicy tak aby místo repozitáře "quay.io" použil artifactory.

**Trusted TLS cert must be used for docker registry, there is no option to use insecure container repo during install.**

### Vytvoření a test "remote repository pro QUAY.IO" na Artifactory 
Quay.io vyžaduje autorizaci pro přihlášení, použijeme tedy identitu vygenerovanou v pull-secret.txt from [Redhat pull secret pull-secret.txt](https://cloud.redhat.com/openshift/install/azure/installer-provisioned)
```sh
# repository for images
oc adm release info --image-for=machine-os-content quay.io/openshift-release-dev/ocp-release@sha256:ea7ac3ad42169b39fce07e5e53403a028644810bee9a212e7456074894df40f3                                                                                                                     
 > quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:be4802b6fe6343053d9f5668acecd68dfb38c4be364a9a3c06e818d56ed61ad1
 # decode Redhat quay.io pull secret:
cat pull-secret.txt|jq -r '.auths."quay.io".auth'|base64 -d
 > openshift-release-dev+dedtomrund93wu0v54cs60osj6x1sk5i:Z56AATkk2OIGKV9OJVTKP8T3G357329ECKAUX0LBRHIGUGJ4H3UGOLHSIJPNHK4N
 # it is a robot login
docker login -u firstpart_decoded -p secondpart_decoded quay.io
 # test quay.io pull
podman pull quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:8a752dfed8c27a60d13f3dc578a1ea15efb2800041810204dd7b3bb79eedee04
```

do install-config.yaml přidáme konfiguraci pro repository mirror.

```yaml
 # artifactory.csas.elostech.cz/docker-quay is remote repository
imageContentSources:
- mirrors:
  - artifactory.csas.elostech.cz/docker-quay/openshift-release-dev/ocp-release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - artifactory.csas.elostech.cz/docker-quay/openshift-release-dev/ocp-v4.0-art-dev
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

**On artifactory UI page go to Remote registry, enable Token Authentication and in Advanced tab--> Remote Authentication add
username and password from**
```sh
 cat pull-secret.txt|jq -r '.auths."quay.io".auth'|base64 -d
```

{{< figure src="img/artifactory.png" caption="artifactory remote authentication settings" >}}
and test it
```sh
docker pull artifactory.csas.elostech.cz/docker-quay/openshift-release-dev/ocp-v4.0-art-dev@sha256:8a752dfed8c27a60d13f3dc578a1ea15efb2800041810204dd7b3bb79eedee04
```

### CREATE Artifactory PULL SECRET FILE for install-config.yaml
Vložíme **pullsecret pro Artifactory** do instalačního souboru **install-config.yaml** a nahradíme tak původní pullSecret.

```sh
 # original pull secret is redhat for quay.io repository usage
 # auth string
export encode_pass=echo -n 'usernametoartifactory:password'|base64 -w0
 # inplace change
yq write -i install-config.yaml pullSecret $(jq -Rnc '.auths = {"artifactory.csas.elostech.cz": {"auth":env.encode_pass ","email": "dedtom@gmail.com"}}')
```

## Prezentace imageContentSourcepolicy CRD na nodech
imageContentSourcepolicy ---> Machineconfig ---> **/etc/containers/registries.conf** 

```sh
oc get machineconfig|grep registries
 > 99-master-c8f3919a-ee7b-4c98-a1f7-96f7bdbb3747-registries   
 > 99-worker-72f09b45-8b75-4609-9071-b2c50143f309-registries

oc get imeagecontentsourcepolicy
```
```sh
 # zkraceno
oc get machineconfig 99-master-c8f3919a-ee7b-4c98-a1f7-96f7bdbb3747-registries -o yaml

apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain,unqualified-search-registries%20%3D%20%5B%22registry.access.redhat.com%22%2C%20%22docker.io%22%5D%0A%0A%5B%5Bregistry%5D%5D%0A%20%20prefix%20%3D%20%22%22%0A%20%20location%20%3D%20%22quay.io%2Fopenshift-release-dev%2Focp-release%22%0A%20%20mirror-by-digest-only%20%3D%20true%0A%0A%20%20%5B%5Bregistry.mirror%5D%5D%0A%20%20%20%20location%20%3D%20%22artifactory.csas.elostech.cz%2Fdocker-quay%2Fopenshift-release-dev%2Focp-release%22%0A%0A%5B%5Bregistry%5D%5D%0A%20%20prefix%20%3D%20%22%22%0A%20%20location%20%3D%20%22quay.io%2Fopenshift-release-dev%2Focp-v4.0-art-dev%22%0A%20%20mirror-by-digest-only%20%3D%20true%0A%0A%20%20%5B%5Bregistry.mirror%5D%5D%0A%20%20%20%20location%20%3D%20%22artifactory.csas.elostech.cz%2Fdocker-quay%2Fopenshift-release-dev%2Focp-v4.0-art-dev%22%0A
        filesystem: root
        mode: 420
        path: /etc/containers/registries.conf
```
O zapis  se  tedy stara **coreOS ignition**.  

## Použití remote repository pro ostatní "image repository" (registry.redhat.io, docker.io ... )
**Problém je že imageContentSourcepolicy tedy vytvoří Machineconfig a následně soubor registries.conf ale vždy obsahuje parametr mirror-by-digest-only=true** zároveň nelze upravovat na přímo ostatní parametry.  
CRD imageContentSourcepolicy tak  jen pro instalaci a upgrade kde se odkazujeme digestem.
```sh
 # example
oc explain Imagecontentsourcepolicy --recursive
```
Přez machineconfig vytvoříme  soubory v /etc/containers/registries.conf.d/ které budou obsahovat upravenou konfiguraci pro jednotlivé registry.  
příklad konfigurace:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-csas-mirror-registry
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,W1tyZWdpc3RyeV1dCiAgcHJlZml4ID0gIiIKICBsb2NhdGlvbiA9ICJkb2NrZXIucGtnLmdpdGh1Yi5jb20iCiAgbWlycm9yLWJ5LWRpZ2VzdC1vbmx5ID0gZmFsc2UKCiAgW1tyZWdpc3RyeS5taXJyb3JdXQogICAgbG9jYXRpb24gPSAiYXJ0aWZhY3RvcnkuY3Nhcy5lbG9zdGVjaC5jejo0NDMvZG9j
a2VyIgoKW1tyZWdpc3RyeV1dCiAgcHJlZml4ID0gIiIKICBsb2NhdGlvbiA9ICJkb2NrZXIuaW8iCiAgbWlycm9yLWJ5LWRpZ2VzdC1vbmx5ID0gZmFsc2UKCiAgW1tyZWdpc3RyeS5taXJyb3JdXQogICAgbG9jYXRpb24gPSAiYXJ0aWZhY3RvcnkuY3Nhcy5lbG9zdGVjaC5jejo0NDMvZG9ja2VyIgo=
        filesystem: root
        path: /etc/containers/registries.conf.d/csas-mirror-registry.conf
```
příklad konfigurace, remote repository musí být na artifactory nakonfigurovány:
```sh
 echo 'W1tyZWdpc3RyeV1dCiAgcHJlZml4ID0gIiIKICBsb2NhdGlvbiA9ICJkb2NrZXIucGtnLmdpdGh1Yi5jb20iCiAgbWlycm9yLWJ5LWRpZ2VzdC1vbmx5ID0gZmFsc2UKCiAgW1tyZWdpc3RyeS5taXJyb3JdXQogICAgbG9jYXRpb24gPSAiYXJ0aWZhY3RvcnkuY3Nhcy5lbG9zdGVjaC5jejo0NDMvZG9j
a2VyIgoKW1tyZWdpc3RyeV1dCiAgcHJlZml4ID0gIiIKICBsb2NhdGlvbiA9ICJkb2NrZXIuaW8iCiAgbWlycm9yLWJ5LWRpZ2VzdC1vbmx5ID0gZmFsc2UKCiAgW1tyZWdpc3RyeS5taXJyb3JdXQogICAgbG9jYXRpb24gPSAiYXJ0aWZhY3RvcnkuY3Nhcy5lbG9zdGVjaC5jejo0NDMvZG9ja2VyIgo='|base64 -d
[[registry]]
  prefix = ""
  location = "docker.pkg.github.com"
  mirror-by-digest-only = false

  [[registry.mirror]]
    location = "artifactory.csas.elostech.cz:443/docker"

[[registry]]
  prefix = ""
  location = "docker.io"
  mirror-by-digest-only = false

  [[registry.mirror]]
    location = "artifactory.csas.elostech.cz:443/docker"
```

## Změna pull secret pro repository 
Content of .pullSecret is stored in **MachineConfig** and as a secret in 
```sh
oc get machineconfig 00-master -o yaml|grep artifactory -A4
oc get machineconfig 00-worker -o yaml|grep artifactory -A4
 # nebo si vsechny hodnoty muzeme vytahnout z renderconfigu
```
Machineconfig odkazuje na soubor **/var/lib/kubelet/config.json**  ktery obsahuje pull secrety pro container registry. Neni potreba ho menit prez machineconfig ale pokud upravime
**secret openshift-config/pull-secret** tak se jeho hodnoty propisi sem rime

```sh
 # get all cluster-wide pull secrets
oc get secret -n openshift-config pull-secret -o json |jq -r '.data[]'|base64 -d
 # a pridani hodnot pro novou artifactory repository
 echo -n 'username:password'|base64 -w0
 # pridani nove hodnoty do stavajicich pull-secretu
 oc get secret -n openshift-config pull-secret -o json |jq -r '.data[]'|base64 -d|jq '.auths += {"artifactory.csas.elostech.cz":{"auth":"b2NwOlRyZTVaaXpxbEdKT1NZdzhCUVZ5ZGFXbjk0eVZNZg==","email":"dedtom@gmail.com"}}' >pull-secret.json
 oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=pull-secret.json
 # dojde k postupnemu restartu vsech nodu
```
**!HAPPY GUNNING!**
