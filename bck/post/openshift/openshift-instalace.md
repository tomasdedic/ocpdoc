---
title: Openshift Instalace 
date: 2020-03-30
author: Tomas Dedic
description: "konfigure AKS for DRMAx POC"
thumbnail: "img/4666.jpg" # Optional, thumbnail
lead: "working"
toc: false # Optional, enable Table of Contents for specific post
categories:
  - "OCP"
tags:
  - "OCP"
  - "AKS"
menu: side # Optional, add page to a menu. Options: main, side, footer
sidebar: true
---

![asi obrazek](img/4666.jpg)
https://api.oshi4.csas.elostech.cz:6443
https://console-openshift-console.apps.oshi4.csas.elostech.cz
kubeadmin, password: BkZN7-qwEyV-58R7j-3qfSH


### OpenShift components that fall into the infrastructure categorization include:
kubernetes and OpenShift control plane services ("masters")
router
container image registry
cluster metrics collection ("monitoring")
cluster aggregated logging
service brokers


---kontakty:
Marek Simer --->provoz Openshift msimer@csas.cz
Mirek Cihlar 
Petr Lipka --->architekt
Michal Dvorak --->provoz
Tomas Jenicek ---> provoz

ACR vytvorit dat secret a napushovat image
-----OPENSHIFT vyuziti v CSAS------
CICD Jenkins 
testovani + monitoring (monitoring problemy  --> nestastny monitorovat Openshift) ---> podivat se na rozdili mezi 3.11 na 4.3 ---> problem logovani podu a systemovych veci
---->korelace udalosti
cloud forms --> zrizeni namespace, vytvoreni developer Jenkins, pipeline pro Cloadforms neni
OVt
monitoring,Satalite 
jak je sakra ten Jenkins deploynutej vs namespace a projekty --->novy mechanismus pro CICD 
as is stav:
ACR a prenesene image
AzureDev Ops
OpenShift instalaci jenkins + nasazeni hello world

+ instalace Openshift samostatny cluster posledni daily build 4.2

-----jump box config-----
ssh ts@13.93.28.51
Sorasil2996#

yum install epel-release
yum -y install  https://centos7.iuscommunity.org/ius-release.rpm
yum install -y tmux2u
yum install git2u
fish shell install
curl -L https://get.oh-my.fish > install
fish install --path=~/.local/share/omf --config=~/.config/omf
omf install https://github.com/jethrokuan/fzf
omf install z
omf install bass
--nvim
yum install xsel #access clipboard
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y neovim python3-neovim
ln -s ~/.vimrc ~/.config/nvim/init.vim
ln -s ~/.vim ~/.local/share/nvim/site
--kubectl completition
mkdir -p ~/.config/fish/completions
cd ~/.config/fish
git clone https://github.com/evanlucas/fish-kubectl-completions
ln -s ../fish-kubectl-completions/completions/kubectl.fish completions/
--ack
curl https://beyondgrep.com/ack-v3.1.2 > ~/bin/ack && chmod 0755 ~/bin/ack
--k9s

## NETWORK
The ovs-multitenant plug-in provides project-level isolation for pods and services. Each project receives a unique Virtual Network ID (VNID) that identifies traffic from pods assigned to the project. Pods from different projects cannot send packets to or receive packets from pods and services of a different project.

## OPENSHIFT AZURE PREREQUISITIES
Deployment of OpenShift Container Platform (OCP) 4.2 is now supported in Azure via the Installer-Provisioned Infrastructure (IPI) model. The landing page for trying OpenShift 4 is try.openshift.com. To install OCP 4.2 in Azure, visit the Red Hat OpenShift Cluster Manager page. Red Hat credentials are required to access this site.

Notes
An Azure Active Directory (AAD) Service Principal (SP) is required to install and run OCP 4.x in Azure
The SP must be granted the API permission of Application.ReadWrite.OwnedBy for Azure Active Directory Graph
An AAD Tenant Administrator must grant Admin Consent for this API permission to take effect
The SP must be granted Contributor and User Access Administrator roles to the subscription
The installation model for OCP 4.x is different than 3.x and there are no Azure Resource Manager templates available for deploying OCP 4.x in Azure

+ Azure Account
+ CLI tools
+ Pull Secret
+ DNS domain in Azure account (delegated domain in our case)
	nslookup -type=SOA csas.elostech.cz

### PRETEST INSTALACE
https://console-openshift-console.apps.sandboxcs.csas.elostech.cz
kubeadmin
sErHu-xgkke-WYWhL-csHyH

uprava identity provider a binding pro cluster-admin tak abychom nemuseli pouzivat kubeadmin
```bash
htpasswd  -B -b tdedic-passwd tdedic heslo
oc create secret generic htpass-oshi --from-file=htpasswd=oshipasswd -n openshift-config

oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: htpasswd_provider
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-oshi
EOF

oc adm policy add-cluster-role-to-user cluster-admin tdedic --rolebinding-name=cluster-admin
oc login -u
oc get clusterrolebinding cluster-admin -o yaml
```
###instalace
[instalace 4.2 on azure](https://blog.openshift.com/openshift-4-2-on-azure-preview/)
```bash
az login
az account show
#define service principals
az ad sp create-for-rbac --name td-oshi-sp
#add roles
az role assignment create --assignee "app id of service principal" --role Contributor --output none
az role assignment create --assignee "app id of service principal" --role "User Access Administrator" --output none
# service principal needs read write owned by app permisions azure AD graph
az ad app permission add --id "app id of service principal" \
-- api 00000002-0000-0000-c000-000000000000 \
-- api-permissions 824c81eb0e3f8-4ee6-8f6d-de7f50d565b7-Role
#subscription id
az account list --output table
#tenant id --> when create service principals
#service principal client id -->app id when created service principal
# service principal client secret -->output of service principal
# pull secret --> when downloading binary from redhat
openshif-install create cluster --dir ./ocp4/
oc get clusterversion
oc get nodes

```
### install http proxy
sudo yum install squid

### oc client and install
wget http://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/openshift-install-linux-4.2.0-0.nightly-2019-10-07-011045.tar.gz
wget http://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/openshift-client-linux-4.2.0-0.nightly-2019-10-07-011045.tar.gz
tar -xvf openshift-client-linux-4.2.0-0.nightly-2019-10-07-011045.tar.gz
tar -xvf openshift-install-linux-4.2.0-0.nightly-2019-10-07-011045.tar.gz

### az sub
cat ~/ocp4-install/az_sub.txt
7504de90-f639-4328-a5b6-fde85e0a7fd9
### redhat secret
vim ./ocp4-install/rh_secret
hostname --long
### proxy install
export https_proxy="https://ocp4proxy.csas.elostech.cz:8080"
export http_proxy="http://ocp4proxy.csas.elostech.cz:8080"
curl  -L http://google.com
curl -x http://ocp4proxy.csas.elostech.cz:8080  -L http://google.com -v
host ocp4proxy.csas.elostech.cz
telnet localhost 8080
curl  -L http://google.com -v
### login do azure ~/.azure
az login
az account show
### install openshift
openshift-install --help
./openshift-install create install-config
vim ./install-config.yaml
vim ./.azure/osServicePrincipal.json
curl -L https://login.microsoftonline.com/d2480fab-7029-4378-9e54-3b7a474eb327/oauth2/token?api-version=1.0 -v
vim ./.azure/accessTokens.json
ls -al  ./.azure/accessTokens.json
./openshift-install create install-config --log-level debug
cp ./install-config.yaml ./ocp4-install/.
vim ./auth/kubeconfig
host api.andboxcs.csas.elostech.cz
curl -L https://api.sandboxcs.csas.elostech.cz:6443/version?timeout=32s
curl -L https://api.sandboxcs.csas.elostech.cz:6443/version?timeout=32s -k
curl -L https://api.sandboxcs.csas.elostech.cz:64443
curl -L https://api.sandboxcs.csas.elostech.cz:6443
curl -L https://api.sandboxcs.csas.elostech.cz:6443 -k
curl -L https://api.sandboxcs.csas.elostech.cz:6443/version?timeout=32s -k
./oc --config ./auth/kubeconfig get co
./oc --config ./auth/kubeconfig get nodes
watch ./oc --config ./auth/kubeconfig get co
./oc --config ./auth/kubeconfig2 get co --insecure
./oc --config ./auth/kubeconfig2 --insecure get co
./oc  --config ./auth/kubeconfig2  --insecure   get logs
./oc login -u system:admin https://10.0.31.254:6443
./oc login -u kubeadmin https://10.0.31.254:6443
./oc  --config ./auth/kubeconfig2  get pods
vim ./auth/kubeconfig
./oc  --config ./auth/kubeconfig2  get pods
./oc  --config ./auth/kubeconfig2 status
./oc  --config ./auth/kubeconfig2 whoami
telnet 10.0.31.254 6443
export DISPLAY=localhost:10.0
echo $DISPLAY
sudo yum groupinstall "X Window System" -y
dig api.sandboxcs.csas.elostech.cz
telnet api.sandboxcs.csas.elostech.cz 443
telnet api.sandboxcs.csas.elostech.cz 6443
telnet console-openshift-console.apps.sandboxcs.csas.elostech.cz
telnet console-openshift-console.apps.sandboxcs.csas.elostech.cz 443
telnet api.sandboxcs.csas.elostech.cz 6443
./oc --config ./auth/kubeconfig login kubeadmin
./oc --config ./auth/kubeconfig get pods
./oc --config ./auth/kubeconfig get co
./oc --config ./auth/kubeconfig get nodes
./oc --config ./auth/kubeconfig describe node sandboxcs-g2xst-master-0
./oc login -u kubeadmin https://api.sandboxcs.csas.elostech.cz:6443
./oc --config ./auth/kubeconfig get csr | grep Pending  | awk '{print $1}'
for i  in `./oc --config ./auth/kubeconfig get csr | grep Pending  | awk '{print $1}'` ; do  ./oc --config ./auth/kubeconfig adm certificate approve $i; done
for i in `./oc --config ./auth/kubeconfig get nodes | awk '{print $1}'`; do echo $i; ./oc --config ./auth/kubeconfig describe node $1 | grep Unknown; done
./openshift-install destroy cluster
ssh sandboxcs-g2xst-worker-westeurope3-gvkx
ssh 10.0.0.5
./oc --config ./auth/kubeconfig describe clusterversion
./oc --config ./auth/kubeconfig get csr
./oc --config ./auth/kubeconfig apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: htpass-secret
  namespace: openshift-config
data:
  htpasswd: dGVzdDokYXByMSRxa0Zvb203dCRSWFIuNHhTV0lhL3h6dkRRUUFFUG8w
EOF
./oc --config ./auth/kubeconfig apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: htpassidp
    challenge: true
    login: true
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF

oc --config ./auth/kubeconfig adm must-gather
oc --config ./auth/kubeconfig get co
ssh kubeadmin@10.0.0.5
export KUBECONFIG=/home/ocp/auth/kubeconfig
./oc whoami
./oc create secret generic aadidp-secret --from-literal=clientSecret=05b154b3-afc3-42dd-bd53-746e6fa0d368 -n openshift-config
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: htpass-secret
  namespace: openshift-config
data:
  htpasswd: dGVzdDokYXByMSRxa0Zvb203dCRSWFIuNHhTV0lhL3h6dkRRUUFFUG8w
./oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: htpass-secret
  namespace: openshift-config
data:
  htpasswd: dGVzdDokYXByMSRxa0Zvb203dCRSWFIuNHhTV0lhL3h6dkRRUUFFUG8w
EOF
./oc apply -f ./AADProvider.yaml
./oc get OAuth -o yaml
vim AADProvider.yaml
vim .ttt.yaml
./oc --config ./auth/kubeconfig apply -f .ttt.yaml
vim .ttt.yaml
./oc --config ./auth/kubeconfig apply -f .ttt.yaml
mv .ttt.yaml ./AADProvider.yaml
./oc login
./oc login --token=HmeA18pZBJ3i1_tR4pOLcWcwkX6ZqdXvWw2ntoulQHA --server-https://api.sandboxcs.csas.elostech.cz:6443
./oc login --token=HmeA18pZBJ3i1_tR4pOLcWcwkX6ZqdXvWw2ntoulQHA --server=https://api.sandboxcs.csas.elostech.cz:6443
./oc project openshift-monitoring
./oc get pods -o wide
./oc get pods  -n openshift-monitoring
./oc get users
./oc describe rolebinding.rbac -n test-jirka1
./oc get users
./oc adm policy add-role-to-user admin h04JWyGUa_nioQMskw5Jmg1E2jWi7qKwYjgVhXanQWY -n jirka-test1
./oc adm policy add-role-to-user admin h04JWyGUa_nioQMskw5Jmg1E2jWi7qKwYjgVhXanQWY -n test-jirka1
./oc adm policy add-role-to-user developer h04JWyGUa_nioQMskw5Jmg1E2jWi7qKwYjgVhXanQWY -n test-jirka2
./oc adm policy add-role-to-user deployer h04JWyGUa_nioQMskw5Jmg1E2jWi7qKwYjgVhXanQWY -n test-jirka2
./oc describe rolebinding.rbac -n test-jirka1
./oc adm policy add-role-to-user system:deployer h04JWyGUa_nioQMskw5Jmg1E2jWi7qKwYjgVhXanQWY -n test-jirka2
./oc get users
./oc adm policy add-role-to-user system:deployer bvkbsD1Qx-0mFQM5HERRBgjniBGzudQgDo-Gdgaxc5I -n test-jirka1
./oc adm policy add-role-to-user admin bvkbsD1Qx-0mFQM5HERRBgjniBGzudQgDo-Gdgaxc5I -n test-jirka2
./oc get sa
echo "bvkbsD1Qx-0mFQM5HERRBgjniBGzudQgDo-Gdgaxc5I"| base64 -d

