---
title: "USING PODMAN instead DOCKER in Azure Runners"
date: 2023-09-06
author: Tomas Dedic
description: "Desc"
lead: "using podman in Azure Runners for ADO, pipeline pitfalls"
categories:
  - "AZURE"
tags:
  - "AZUREDEVOPS"
  - "PODMAN"
---

# USING PODMAN instead DOCKER in Azure Runners

## Why to use PODMAN
If I skip that Podman is more secure then Docker because it does not require a separate daemon to run containers with root privileges. It also offers huge ecosystem (https://github.com/containers) and also offers some features like Image Trust(https://docs.podman.io/en/latest/markdown/podman-image-trust.1.html) and Image Content source policy (https://www.redhat.com/sysadmin/manage-container-registries). 
In fact right now we don't have any specific solution how to block some registries/repositories and force to use our private ACR for image pull.
**Podman has an Docker API compatibility layer. Docker API is compatible with Podman v4 and higher.**

Problem with Podman is that it is pretty new, not fully supported by ADO and allow too many customizations. 

## 1. Requirements 
I have made a lits of requirements we have for the solution

+ customize ADO agent runner to run podman
+ run podman as docker (some pipelines and ado tasks are using docker command, redirect it to podman with all the arguments), no changes are necessary in source code (Dockerfile) 
+ start podman socket/service automaticaly for AzDevOps user and emulate docker socket (for templates)
+ forward Container Registries requests to private ACR
+ whitelist allowed registries/repository/tags, deny all other
+ test build speed of podman container, podman in build speed should be >= docker build
+ docker API compatibility

## 2. Flow
{{< figure src="/img/podman/podman_graph.png" caption="podman policy flow" >}}

## 3. Solutions with ADO runner perspective
### 3.1. customize ADO agent runner to run podman
- Since we want to stay with ubuntu, the usable version is 22.04, this version of Ubuntu supports only podman 3.4 from official repository. Podman 3.4 is pretty old and full of bugs. Move it to version 4.5.1 with kubic repositoty.
```bash
#kubic repository
#install podman,buildah,skopeo
install_packages=(podman buildah skopeo)
REPO_URL="https://download.opensuse.org/repositories/devel:kubic:libcontainers:unstable/xUbuntu_$(lsb_release -rs)"
mkdir -p /etc/apt/keyrings
curl -fsSL $REPO_URL/Release.key \
| gpg --dearmor \| tee /etc/apt/keyrings/devel_kubic_libcontainers_unstable.gpg > /dev/null
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/devel_kubic_libcontainers_unstable.gpg]\
    $REPO_URL/ /" \
| tee /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list > /dev/null
apt-get update -qq
apt-get -qq -y install ${install_packages[@]}
mkdir -p /etc/container
```
- ADO agent is using user AzDevOps as a target, we will provision this user in advance and linger it to be able to run systemd units automatically, agent is using (https://vstsagenttools.blob.core.windows.net/tools/ElasticPools/Linux/14/enableagent.sh)
```bash
#!/usr/bin/env bash
# set -euo pipefail
#uid=1001(AzDevOps) gid=1001(AzDevOps) groups=1001(AzDevOps),4(adm),27(sudo)
useradd -m -u 1001 AzDevOps
# usermod -a -G docker AzDevOps
usermod -a -G adm AzDevOps
usermod -a -G sudo AzDevOps
chmod -R +r /home
setfacl -Rdm "u:AzDevOps:rwX" /home
setfacl -Rb /home/AzDevOps
echo 'AzDevOps ALL=NOPASSWD: ALL' >> /etc/sudoers
loginctl enable-linger AzDevOps
echo "linger enabled"
ls -la /var/lib/systemd/linger
```

```bash
#set XDG dir for AzDevOps user
cat <<EOF > /etc/profile.d/agent_env_vars.sh"
XDG_RUNTIME_DIR="/run/user/1001"
EOF
```

### 3.2. run podman as docker (some pipelines and ado tasks are using docker command, redirect it to podman with all the arguments), no changes are necessary in source code (Dockerfile) 
```bash
#!/bin/bash -e

cat <<EOF > /usr/bin/docker && chmod +x /usr/bin/docker
#!/bin/sh
[ -f /etc/containers/nodocker ] || \
echo "Emulate Docker CLI using podman. Create /etc/containers/nodocker to quiet msg." >&2
exec /usr/bin/podman "\$@"
EOF
touch /etc/containers/nodocker
```


### 3.3. Start podman socket/service automaticaly for AzDevOps user and emulate docker socket (for templates)

Podman API is 99.9% compatible with Docker API. So Docker API can be simulated by creating symbolic link 
```sh
cat /usr/lib/systemd/user/podman.socket
[Unit]
Description=Podman API Socket
Documentation=man:podman-system-service(1)

[Socket]
ListenStream=%t/podman/podman.sock
SocketMode=0660

[Install]
WantedBy=sockets.target
```
```sh
#enable user units for podman and start them
systemctl enable --user podman.socket
systemctl enable --user podman.service
systemctl start --user podman.socket
systemctl start --user podman.service

```
```sh
#test socket
curl --unix-socket /run/user/1001/podman/podman.sock -v 'http://d/v4.5.1/libpod/images/json'

```

```sh
#create symblolic link in well known destination
cat <<EOF >/usr/lib/tmpfiles.d/podman-docker.conf
L+  /run/docker.sock   -    -    -     -   /run/user/1001/podman/podman.sock
EOF
```
```
#test socket
curl --unix-socket /run/docker.sock -v 'http://d/v4.5.1/libpod/images/json'

#call docker api from inside container 
podman run -v /var/run/docker.sock:/var/run/docker.sock  quay.io/podman/stable curl -s --unix-socket /var/run/docker.sock http://d/4.5.1/libpod/info
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp registry.aquasec.com/scanner:2302.13.13 scan --local testimage:0.1.212 --no-verify 
```

```sh
#azureRunner profile, setup ENV variables
cat <<EOF > /etc/profile.d/agent_env_vars.sh
export XDG_RUNTIME_DIR="/run/user/1001"
export DOCKER_HOST="unix:///run/user/1001/podman/podman.sock"
export DOCKER_SOCK="/run/user/1001/podman/podman.sock"
EOF
```


### 3.4. forward Container Registries requests to private ACR
All request pointing to the selected registers will be redirected to private ACR with some naming convention.
```toml
cat <<EOF > /etc/containers/registries.conf
unqualified-search-registries = ['docker.io', 'quay.io', 'gcr.io' ]

[[registry]]
prefix="quay.io"
location="devopsbasecr.azurecr.io/quay"

[[registry]]
prefix="docker.io"
location="devopsbasecr.azurecr.io/docker"

[[registry]]
prefix="gcr.io"
location="devopsbasecr.azurecr.io/gcr"

[[registry]]
prefix="mcr.microsoft.com"
location="devopsbasecr.azurecr.io/ms"
EOF
```

### 3.5. whitelist allowed registries/repository/tags, deny all other
Block all registries except the ones that will be redirected, private one  and some special registries.
```json
cat <<EOF > /etc/containers/policy.json 
{
    "default": [
        {
            "type": "reject"
        }
    ],
    "transports": {
        "containers-storage": {
            "": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        },
        "docker": {
            "registry.aquasec.com": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "devopscr.azurecr.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "prdopscr.azurecr.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "devappcr.azurecr.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "prdappcr.azurecr.io": [
                {
                    "type": "insecureAcceptAnything"
                            ],
            "devopsbasecr.azurecr.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "prdopsbasecr.azurecr.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "docker.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "gcr.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "quay.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "mcr.microsoft.com": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        },
        "docker-daemon": {
            "": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        }
    }
}
```
### 3.6. test build speed of podman container, podman in build speed should be >= docker build
Concerns about speed compared to Docker were not confirmed and Podman is just as fast, in some cases faster than Docker. Important part is that podman need to run with overlayFS
```sh
  graphDriverName: overlay
```
## 3.7 Docker API compatibility with PODMAN (mitigation of DockerInstaller@0 task)
We can still use dockerCLI with podman server because of compatibility in docker API. So the drift towards podman should be seamless as possible.
```sh
#simulate docker API call
cat <<EOF >createcontainer
{
"Name": "abrakadabra",
"Image": "tst:1"
}
EOF
curl --unix-socket /run/user/1001/podman/podman.sock -H content-type:application/json  -X POST "http://localhost/v1.43/containers/create" -d @createcontainer

#the same with libpod
#simulate libpod APIcall (podman native)
curl -XPOST --unix-socket /run/user/${UID}/podman/podman.sock \
    -H content-type:application/json \
    http://d/v4.5.1/libpod/containers/create -d @createcontainer

```

**In HEQ pipelines task DockerInstaller@0 is widely used**
```yaml
- task: DockerInstaller@0
  inputs:
    dockerVersion: '19.03.4'
```
with  dockerVersion as variable, this task will install dockerCLI and prepand its binary PATH to $PATH. The next task calling "docker" will use modified $PATH so it will use installed docker:
```sh
#DockerInstaller@0 flow
Caching tool: docker-stable 19.3.4 x64
Prepending PATH environment variable with directory: /opt/hostedtoolcache/docker-stable/19.3.4/x64
Verifying docker installation...
/opt/hostedtoolcache/docker-stable/19.3.4/x64/docker --version

PATH=/opt/hostedtoolcache/docker-stable/19.3.4/x64:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
```
Setup now looks like:
```sh
Client: Docker Engine - Community
 Version:           19.03.4
 API version:       1.40
 Go version:        go1.12.10
 Git commit:        9013bf583a
 Built:             Fri Oct 18 15:49:05 2019
 OS/Arch:           linux/amd64
 Experimental:      false

Server: linux/amd64/ubuntu-22.04
 Podman Engine:
  Version:          4.5.1
  APIVersion:       4.5.1
  Arch:             amd64
  BuildTime:        1970-01-01T00:00:00Z
  Experimental:     false
  GitCommit:
  GoVersion:        go1.18.1
  KernelVersion:    5.15.0-1041-azure
  MinAPIVersion:    4.0.0
  Os:               linux
 Conmon:
  Version:          conmon version 2.1.7, commit:
  Package:          conmon_2:2.1.7-0ubuntu22.04+obs15.52_amd64
 OCI Runtime (crun):
  Version:          crun version 1.8.4
commit: 5a8fa99a5e41facba2eda4af12fa26313918805b
rundir: /run/user/1001/crun
spec: 1.0.0
+SYSTEMD +SELINUX +APPARMOR +CAP +SECCOMP +EBPF +YAJL
  Package:          crun_101:1.8.4-0ubuntu22.04+obs55.14_amd64
 Engine:
  Version:          4.5.1
  API version:      1.41 (minimum version 1.24)
  Go version:       go1.18.1
  Git commit:
  Built:            Thu Jan  1 00:00:00 1970
  OS/Arch:          linux/amd64
  Experimental:     false
```
In this particular example *docker build will fail* with
```sh
level=error msg="failed to dial gRPC: unable to upgrade to h2c, received 404"
```
Problem is in dockerCLI version, in API incompatibility, docker API should be in version >=1.41 it means version of dockerCLI need to be >20
```sh
#tested docker CLI versions
#all DockerInstaller@0 task need to be upgraded to higher dockerVersion
dockerVersion: '20.10.0'
dockerVersion: '24.0.0'
```
**Effectively docker Client will use podman Engine as backend and all the requirements defined earlier will be kept.**  
I have tried also other solutions to migitage posibility of install "unsupported" docker CLI but from ADO perspective it is unreal.  

Without usage of DockerInstaller@0 task , setup will stay only with podman
```sh
Client:       Podman Engine
Version:      4.5.1
API Version:  4.5.1
Go Version:   go1.18.1
Built:        Thu Jan  1 00:00:00 1970
OS/Arch:      linux/amd64
```

**Recomandation is to remove DockerInstaller@0  task from all the pipelines or change dockerCLI in this tasks to higher(tested) version.**


## 4. Azure DevOPS pools
As Azure DevOps runners we are using pools from "Ubuntu 18.04". We are also using Azure [Dependancy Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/agents-overview#supported-operating-systems) for monitoring.
Runner was upgraded to Ubuntu 22.04 with Azure Monitor(https://learn.microsoft.com/en-us/azure/virtual-machines/monitor-vm) extension.

## Podman configuration
```sh
#some tweaks for limits
cat <<EOF > /etc/containers/containers.conf
 [containers]
 default_ulimits = [
   "nofile=10000:20000",
 ]
```
```sh
#podman info
host:
  arch: amd64
  buildahVersion: 1.30.0
  cgroupControllers:
  - memory
  - pids
  cgroupManager: systemd
  cgroupVersion: v2
  conmon:
    package: conmon_2:2.1.7-0ubuntu22.04+obs15.50_amd64
    path: /usr/bin/conmon
    version: 'conmon version 2.1.7, commit: '
  cpuUtilization:
    idlePercent: 98.16
    systemPercent: 0.61
    userPercent: 1.23
  cpus: 4
  databaseBackend: boltdb
  distribution:
    codename: jammy
    distribution: ubuntu
    version: "22.04"
  eventLogger: journald
  hostname: C1-PLT-DEV-OPS-rst-vmss00000P
  idMappings:
    gidmap:
    - container_id: 0
      host_id: 1001
      size: 1
    - container_id: 1
      host_id: 165536
      size: 65536
    uidmap:
    - container_id: 0
      host_id: 1001
      size: 1
    - container_id: 1
      host_id: 165536
      size: 65536
  kernel: 5.15.0-1041-azure
  linkmode: dynamic
  logDriver: journald
  memFree: 13892984832
  memTotal: 16767574016
  networkBackend: netavark
  ociRuntime:
    name: crun
    package: crun_101:1.8.4-0ubuntu22.04+obs55.14_amd64
    path: /usr/bin/crun
    version: |-
      crun version 1.8.4
      commit: 5a8fa99a5e41facba2eda4af12fa26313918805b
      rundir: /run/user/1001/crun
      spec: 1.0.0
      +SYSTEMD +SELINUX +APPARMOR +CAP +SECCOMP +EBPF +YAJL
  os: linux
  remoteSocket:
    path: /run/user/1001/podman/podman.sock
  security:
    apparmorEnabled: false
    capabilities: CAP_CHOWN,CAP_DAC_OVERRIDE,CAP_FOWNER,CAP_FSETID,CAP_KILL,CAP_NET_BIND_SERVICE,CAP_SETFCAP,CAP_SETGID,CAP_SETPCAP,CAP_SETUID,CAP_SYS_CHROOT
    rootless: true
    seccompEnabled: true
    seccompProfilePath: /usr/share/containers/seccomp.json
    selinuxEnabled: false
  serviceIsRemote: false
  slirp4netns:
    executable: /usr/bin/slirp4netns
    package: slirp4netns_1.2.0-0ubuntu22.04+obs10.87_amd64
    version: |-
      slirp4netns version 1.2.0
      commit: 656041d45cfca7a4176f6b7eed9e4fe6c11e8383
      libslirp: 4.6.1
      SLIRP_CONFIG_VERSION_MAX: 3
      libseccomp: 2.5.3
  swapFree: 4294963200
  swapTotal: 4294963200
  uptime: 0h 13m 6.00s
plugins:
  authorization: null
  log:
  - k8s-file
  - none
  - passthrough
  - journald
  network:
  - bridge
  - macvlan
  - ipvlan
  volume:
  - local
registries: {}
store:
  configFile: $HOME/.config/containers/storage.conf
  containerStore:
    number: 0
    paused: 0
    running: 0
    stopped: 0
  graphDriverName: overlay
  graphOptions: {}
  graphRoot: /home/AzDevOps/.local/share/containers/storage
  graphRootAllocated: 103865303040
  graphRootUsed: 25445507072
  graphStatus:
    Backing Filesystem: extfs
    Native Overlay Diff: "true"
    Supports d_type: "true"
    Using metacopy: "false"
  imageCopyTmpDir: /var/tmp
  imageStore:
    number: 9
  runRoot: /tmp/containers-user-1001/containers
  transientStore: false
  volumePath: /home/AzDevOps/.local/share/containers/storage/volumes
version:
  APIVersion: 4.5.1
  Built: 0
  BuiltTime: Thu Jan  1 00:00:00 1970
  GitCommit: ""
  GoVersion: go1.18.1
  Os: linux
  OsArch: linux/amd64
  Version: 4.5.1
```


## PROBLEMS
### 1. MSBUILD (SOLVED - disable /proc mount)
We are hitting problems with MSBuild for dotnet, some of our containers (AzureFunctions) need rebuild and they are using MSBuild where no other runtime then docker is supported. Now I don't have a solution for such a case when using podman.
https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild?view=vs-2022
```sh
#code that will fail
dotnet publish -v q /p:BuildNumber=$BUILD_NUMBER /p:CommitHash=$HOST_COMMIT src/WebJobs.Script.WebHost/WebJobs.Script.WebHost.csproj -c Release --output /azure-functions-host --runtime linux-x64 && \

Unhandled exception: System.NullReferenceException: Object reference not set to an instance of an object.
   at Microsoft.DotNet.Cli.Utils.Muxer..ctor()
   at Microsoft.DotNet.Cli.Utils.MSBuildForwardingAppWithoutLogging..ctor(IEnumerable`1 argsToForward, String msbuildPath)
   at Microsoft.DotNet.Tools.MSBuild.MSBuildForwardingApp..ctor(IEnumerable`1 argsToForward, String msbuildPath)
   at Microsoft.DotNet.Tools.RestoringCommand..ctor(IEnumerable`1 msbuildArgs, Boolean noRestore, String msbuildPath, String userProfileDir, Boolean advertiseWorkloadUpdates)
   at Microsoft.DotNet.Tools.Publish.PublishCommand.FromParseResult(ParseResult parseResult, String msbuildPath)
   at Microsoft.DotNet.Tools.Publish.PublishCommand.Run(ParseResult parseResult)
   at Microsoft.DotNet.Cli.ParseResultCommandHandler.Invoke(InvocationContext context)
   at System.CommandLine.Invocation.InvocationPipeline.<>c__DisplayClass4_0.<<BuildInvocationChain>b__0>d.MoveNext()
--- End of stack trace from previous location ---
   at System.CommandLine.CommandLineBuilderExtensions.<>c__DisplayClass12_0.<<UseHelp>b__0>d.MoveNext()
--- End of stack trace from previous location ---
   at System.CommandLine.CommandLineBuilderExtensions.<>c.<<UseSuggestDirective>b__18_0>d.MoveNext()
--- End of stack trace from previous location ---
   at System.CommandLine.CommandLineBuilderExtensions.<>c__DisplayClass16_0.<<UseParseDirective>b__0>d.MoveNext()
--- End of stack trace from previous location ---
   at System.CommandLine.CommandLineBuilderExtensions.<>c__DisplayClass8_0.<<UseExceptionHandler>b__0>d.MoveNext()

```
### 2. LOCAL transport when using policy (SOLVED)
```yaml
        "containers-storage": {
            "": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        },
```

I made an issue where whole problem is described
https://github.com/containers/podman/issues/19128

