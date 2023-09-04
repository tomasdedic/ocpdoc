# SYSTÉMOVÉ SECRETY a jejich správa

## 1. SYSTÉMOVÉ SECRETY
Systémové certifikáty jsou uloženy v SYS ARGO repozitáři daného clusteru v adresáři **secrets**.  
Ne všechny tyto certifikáty jsou zpracovávány GitOpsově. Řešíme často problém "slepice/vejce" takže některé secrets jsou aplikovány ručně po založení clusteru.
```bash
tree secrets/
├── api-certificate.yml             # Openshift api TLS certifikát
├── argocd-app                      # argocd app secrets
│   ├── argocd-secret.yml
│   ├── token-git-github-csas-ops.yml
│   ├── token-helm-artifactory-1.yml
│   └── token-helm-artifactory-2.yml
├── argocd-sys                      # argocd sys secrets
│   ├── argocd-cluster.yml
│   ├── token-git-bitbucket-ocp4.yml
│   ├── token-git-github-csas-ops.yml
│   ├── token-helm-artifactory-1.yml
│   └── token-helm-artifactory-2.yml
├── azure-auth.yml                  # OIDC setting for Azure Auth
├── azure-group-sync.yml            # Group sync operátor secret pro AAD group sync
├── backend-tprgnasbe02.yml         # Trident NFS
├── kafka-credentials.yaml          # kafka credentials pro logy
├── router-be-certificate.yml       # BE router TLS
├── router-default-certificate.yml  # default router TLS
├── router-dmz-certificate.yml      # dmz router TLS
├── router-fe-certificate.yml       # FE router TLS
└── sealed-secrets.yml              # Sealed secrets private KEY/CERT
```
Tyto secrets jsou ve standartní struktuře kind:Secrets a jsou zašifrovány pomocí 'Ansible vault'.

## 2. GITOPS zpracování 
Pro GITOPS zpracování secretů, Ansible vault secrety dešifrujeme, updatujeme a následně zašifrujeme certifikátem pro Kubeseal do adresáře **confidential-secrets**. Standartním procesem pak provedeme Gitops sync.
```bash
# secrety řízené GITOPS
tree secrets/
├── api-certificate.yml             # Openshift api TLS certifikát
├── azure-auth.yml                  # OIDC setting for Azure Auth
├── azure-group-sync.yml            # Group sync operátor secret pro AAD group sync
├── kafka-credentials.yaml          # kafka credentials pro logy
├── router-be-certificate.yml       # BE router TLS
├── router-default-certificate.yml  # default router TLS
├── router-dmz-certificate.yml      # dmz router TLS
└── router-fe-certificate.yml       # Sealed secrets private KEY/CERT
```
Provedení výměny secretů
```bash
#decrypt
ansible-vault decrypt $secret
# update obsahu secretu novými hodnotami
#encrypt
ansible-vault encrypt $secret
#pipe it through sealed-secrets
read ansible_vault_pass </dev/tty
#pokud chceme pouzit kubeseal certifikat lokalne
ansible-vault view $secret  --vault-password-file <(cat <<<"$ansible_vault_pass")|kubeseal --cert cert.pem --scope namespace-wide >confidential-secrets/$secret
#pokud chceme pouzit kubeseal certifikat ze serveru
ansible-vault view api-certificate.yml  --vault-password-file <(cat <<<"$ansible_vault_pass")|kubeseal --cert https://certificate-sealed-secrets.apps.<CLUSTER_NAME>.<BASE_DOMAIN>/v1/cert.pem --scope namespace-wide >confidential-secrets/$secret
# následuje standartní render a GIT commit/push 
```
## 3. Spracování neřízených GITOPS
Některé secrety jsou potřeba pro konfiguraci samotného clusteru a jeho komponent. Musí tedy být přítomny v clusteru ještě před jeho konfigurací a je tedy nutné je aplikovat ručně.
```bash
# secrety neřízené GITOPS
tree secrets/
├── argocd-app
│   ├── argocd-secret.yml
│   ├── token-git-github-csas-ops.yml
│   ├── token-helm-artifactory-1.yml
│   └── token-helm-artifactory-2.yml
├── argocd-sys
│   ├── argocd-cluster.yml
│   ├── token-git-bitbucket-ocp4.yml
│   ├── token-git-github-csas-ops.yml
│   ├── token-helm-artifactory-1.yml
│   └── token-helm-artifactory-2.yml
├── backend-tprgnasbe02.yml         # Trident NFS
└── sealed-secrets.yml              # Sealed secrets private KEY/CERT
```
```bash
## provadime update hodnot
#decrypt
ansible-vault decrypt $secret
# update obsahu secretu novými hodnotami
#encrypt
ansible-vault encrypt $secret

## aplikujeme nove nebo stavajici hodnoty
read ansible_vault_pass </dev/tty
ansible-vault view $secret  --vault-password-file <(cat <<<"$ansible_vault_pass")|oc apply -f -
```
