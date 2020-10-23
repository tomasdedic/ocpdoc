## Storage encryption
- **Managed disks**  
Vytvořené OSdisky jsou automaticky nastaveny jako encrypted-at-rest s Platform-managed keys (disky jsou šifrované klíči jejichž lifecycle řeší poskytovatel cloudu)

- **Storage accounts**  
Po instalaci jsou vytvořené dva storage accounts. Jeden obsahuje **VM bootdiagnostic a VHD pro coreos nódy**. Druhý slouží jako storage pro **interní container registry** s Platform-managed keys.

#### Možné změny
- Změna  Managed disků na SSE s Client-managed keys je možný ale zahrnuje **odpojení disku** (přiřazení do Encryption setu) od běžícího VM  (v tomto případě vypnutí VM jelikož všechny containery běží právě z tohoto disku). Pro automatizaci se jako možnost jeví úprava *teraform provision skriptů* použitých při IPI instalaci.  

- Změna storage accounts na Client-managed keys lze provést online. Zároveň storage accounts neobsahují v iniciální podobě žádná běhová data.

- Automatický storage provisioning. Zatím jsem nezkoumal možnosti OCP pri vytoření nového Storage (StorageClass, CSI) a jejich automatické přiřazení k Encryption setu, nastavení Client-managed keys.

- Azure DISK encryption (ADE dm-crypt) nelze v případě OS CoreOS použít jelikož **CoreOS není podporovaný OS**.

- CoreOS TPM2 (trusted platform module) není podporovaný v Azure 
  Default device mapper pro OSdisk z pohledu CoreOS
  ```sh
  dmsetup ls
    coreos-luks-root-nocrypt        (253:0)
  ```

{{< figure src="img/SSE-ADE.png" caption="SSE-ADE od Adama" >}}

## Etcd encryption
**Standartně, data ETCD nejsou šifrovaná.** Šifrování lze zapnout přímočarým procesem a dojde k vytvoření klíčů s týdení rotací.  
Šifrování se netýká celé ETCD databáze ale pouze následujících API zdrojů:
```sh
Secrets
ConfigMaps
Routes
OAuth access tokens
OAuth authorize tokens
```

### proces šifrování ETCD
```sh
# stav
oc get openshiftapiserver -o=jsonpath='{range .items[0].status.conditions[?(@.type=="Encrypted")]}{.reason}{"\n"}{.message}{"\n"}'
oc get kubeapiservers.operator.openshift.io -o=jsonpath='{range .items[0].status.conditions[?(@.type=="Encrypted")]}{.reason}{"\n"}{.message}{"\n"}'
```
```sh
APIServer holds configuration (like serving certificates, client CA and
CORS domains) shared by all API servers in the system, among them
especially kube-apiserver and openshift-apiserver.

oc edit apiserver
spec:
  encryption:
    type: aescbc 
    # The aescbc type means that AES-CBC with PKCS #7 padding and a 32 byte key is used to perform the encryption.
```

Použita je AES symetrická šifra a klíč je uložený v secret resourcu. 
```sh
 oc get secret -n openshift-etcd etcd-all-peer
 ```

## Hodnocení stavu
- Pro Šifrování samotných disků  a Storage accounts  SSE zajišťované přímo přez OCP by bylo vhodné změnit klíče pro na **Client-managed** dle definované policy a mít tak pod kontrolou celý lifecycle. Zárověn zajistit aby nově vytvářené objekty tuto policy přejímaly. 
- Použité OS aware šifrování (ADE -dm crypt, TPM2) není v tento okamžik na dané platformě možné, pokud by bylo požadované byla by potřeba provést širší analýza problému a pokusit se o nějaké POC řešení.  
- Šifrování ETCD nedává přímo smysl. Etcd databáze je sice "šifrovaná" v podstatě to však znamená že jsou šifrované její případné dumpy a zálohy. Zálohy ETCD se na OCP provádí spušťením backup skriptu, který na konktrétním nódu vytvoří dump (na nódu jsou dostupné i šifrovací klíče). Beru li v úvahu že pro celou administraci OCP je navrženo GITOPS řešení, je jednodušší varianta  provést reinstall clusteru a celou jeho konfiguraci natáhnout přez GITOPS pipeline než ohnovovat případnou zálohu ETCD.  
  Šifrování ETCD zároveň zpomaluje práci s poskytovaným API.  
  **Šifrování ETCD je tedy dle mého názoru vhodné pouze v případě že by byli prováděny její zálohy na "remote" úložiště.**

