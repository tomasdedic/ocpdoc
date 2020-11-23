---
title: "Standalone Kubelet on Fedora 31"
date: 2020-11-23 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Openshift"
tags:
  - "Config"
---


## What is this about?

This gist describes how to set up standalone kubelet + CRI-O + CNI on Fedora Core 31. The goal is to place a Kubernetes Pod manifest on an single node and access the application from the network. This guide has been tested on x86-64 and armv7 deployments.

### Prepare the system

Make sure the system is up to date:

`dnf -y update`

On Fedora 31 [by default cgroup v2](https://www.redhat.com/sysadmin/fedora-31-control-group-v2) are used. However the kubelet does not seem to be compatible with this as of time of writing. Revert this by adding the `systemd.unified_cgroup_hierarchy=0` switch to the kernel command line in

**For x86-64 systems**, modify `/etc/default/grub` like below:

```diff
 GRUB_DEFAULT=saved
 GRUB_DISABLE_SUBMENU=true
 GRUB_TERMINAL_OUTPUT="console"
-GRUB_CMDLINE_LINUX="resume=/dev/mapper/fedora-swap rd.lvm.lv=fedora/root rd.lvm.lv=fedora/swap rhgb quiet"
+GRUB_CMDLINE_LINUX="resume=/dev/mapper/fedora-swap rd.lvm.lv=fedora/root rd.lvm.lv=fedora/swap rhgb quiet systemd.unified_cgroup_hierarchy=0"
 GRUB_DISABLE_RECOVERY="true"
 GRUB_ENABLE_BLSCFG=true
```

Regenerate your bootloader configuration using Grub2...

on a BIOS-based system install `grub2-mkconfig -o /boot/grub2/grub.cfg`

or on UEFI-based installs with `grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg`

**For armv7 based systems** which employ extlinux, modify `/boot/extlinux/extlinux.conf`:

```diff
default=Fedora-Minimal-armhfp-31-1.9 (5.3.7-301.fc31.armv7hl)
 label Fedora (5.4.17-200.fc31.armv7hl) 31 (Thirty One)
 	kernel /vmlinuz-5.4.17-200.fc31.armv7hl
-	append ro root=UUID=b0abeeb4-7c58-4b29-9c60-3377437cde8a rhgb quiet LANG=en_US.UTF-8
+	append ro root=UUID=b0abeeb4-7c58-4b29-9c60-3377437cde8a rhgb quiet LANG=en_US.UTF-8 systemd.unified_cgroup_hierarchy=0
 	fdtdir /dtb-5.4.17-200.fc31.armv7hl/
 	initrd /initramfs-5.4.17-200.fc31.armv7hl.img

 label Fedora-Minimal-armhfp-31-1.9 (5.3.7-301.fc31.armv7hl)
 	kernel /vmlinuz-5.3.7-301.fc31.armv7hl
-	append ro root=UUID=b0abeeb4-7c58-4b29-9c60-3377437cde8a rhgb quiet LANG=en_US.UTF-8
+	append ro root=UUID=b0abeeb4-7c58-4b29-9c60-3377437cde8a rhgb quiet LANG=en_US.UTF-8 systemd.unified_cgroup_hierarchy=0
 	fdtdir /dtb-5.3.7-301.fc31.armv7hl/
 	initrd /initramfs-5.3.7-301.fc31.armv7hl.img
```

Reboot the system.

`systemctl reboot`

### Install CRI-O

CRI-O is available as a DNF module stream. On FC31 be sure to install the latest version to circumvent this bug: https://bugzilla.redhat.com/show_bug.cgi?id=1754170

```
dnf -y module enable cri-o:1.16
dnf -y install crio
```

To interact with the CRI-O environment also install `critctl`

`dnf -y install cri-tools`

### Configure CNI

CNI will be responsible for connection containers launched through CRI-O to the hosts network. Portmapping (to enable use of `hostPort` in pod manifest) and firewall (to configure firewalld to permit traffic) will be used.

Delete the default CNI config:

```
rm /etc/cni/net.d/*.conf
```

Place the following file into `/etc/cni/net.d/100-crio-bridge.conflist`

```json
{
  "cniVersion": "0.4.0",
  "name": "bridge-firewalld",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "cni0",
      "isDefaultGateway": true,
      "isGateway": true,
      "ipMasq": true,
      "ipam": {
        "type": "host-local",
        "subnet": "10.88.0.0/16",
        "routes": [
          {
            "dst": "0.0.0.0/0"
          }
        ]
      }
    },
    { 
      "type": "portmap",
      "capabilities": {
	"portMappings": true
     }
    },
    {
      "type": "firewall"
    }
  ]
}
```

The above configuration will cause CNI to create Linux bridge `cni0` and attach veth-pairs between the host and the container. The containers will receive IPs in the `10.88.0.0/16` in the process. The bridge will act as gateway and IP masquerading will be configured to allow containers to networks external to the host (e.g. internet). Portmapping and firewalld rule manipulation will be conducted.

### Install Standalone kubelet

`dnf -y install kubernetes-node`


### Configure Standalone Kubelet

#### Disable Docker

You will notice that containerd and docker have been pulled in as a dependency. This is because by default the kubelet depends on Docker as the runtime. We will disable it and replace with CRI-O.

`systemctl mask docker`

We need to reconfigure the Kubelet systemd unit to not require docker but crio. Copy the unit file into the drop-in location:

`cp /usr/lib/systemd/system/kubelet.service /etc/systemd/system/kubelet.service`

Modify the unit file `/etc/systemd/system/kubelet.service` and replace the references to the docker unit with crio:

```diff
 [Unit]
 Description=Kubernetes Kubelet Server
 Documentation=https://github.com/GoogleCloudPlatform/kubernetes
-After=docker.service
-Requires=docker.service
+After=crio.service
+Requires=crio.service
 
 [Service]
 WorkingDirectory=/var/lib/kubelet
```

Notify systemd about these changes:

`systemctl daemon-reload`

#### Configure Kubelet

Remove the now obsolete flag `--allow-privileged` from `/etc/kubernetes/config` that would prevent the service from starting:

```diff
 KUBE_LOG_LEVEL="--v=0"
 
 # Should this cluster be allowed to run privileged docker containers
-KUBE_ALLOW_PRIV="--allow-privileged=true"
+KUBE_ALLOW_PRIV=""
 
 # How the controller-manager, scheduler, and proxy find the apiserver
 KUBE_MASTER="--master=http://127.0.0.1:8080"
```

Apply the below modifications to `/etc/kubernetes/kubelet` in order to:

* enable static pod manifests stored on disk
* enable the use of runc through CRIO as the container runtime ([details](https://github.com/cri-o/cri-o/blob/master/tutorials/kubernetes.md#preparing-kubelet))


```diff
 KUBELET_HOSTNAME="--hostname-override=127.0.0.1"
 
 # Add your own!
-KUBELET_ARGS="--cgroup-driver=systemd --fail-swap-on=false"
+KUBELET_ARGS="--cgroup-driver=systemd --fail-swap-on=false --pod-manifest-path=/etc/kubernetes/manifests --container-runtime=remote --container-runtime-endpoint=unix:///var/run/crio/crio.sock --runtime-request-timeout=10m"
```

Create the manifest directory:

`mkdir /etc/kubernetes/manifests`

Finally, enable and start the Kubelet.

`systemctl enable kubelet --now`

Verify the kubelet status

`systemctl status kubelet`

Verify the status of CRI-O

`systemctl status crio`

Verify that both the runtime and CNI are ready:

`crictl info`

You should see the following:

```json
{
  "status": {
    "conditions": [
      {
        "type": "RuntimeReady",
        "status": true,
        "reason": "",
        "message": ""
      },
      {
        "type": "NetworkReady",
        "status": true,
        "reason": "",
        "message": ""
      }
    ]
  }
}
```


When succcessful, place the following example pod manifest in `/etc/kubernetes/manifests/echoserver.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: echoserver
spec:
  containers:
    - name: echoserver
      image: gcr.io/google-containers/echoserver:1.10
      ports:
        - name: web
          containerPort: 8080
          hostPort: 9091
          protocol: TCP
      resources:
        limits:
          cpu: "100m"
          memory: "50Mi"
```

**Warning** Note that this container image is x86-64 only. Attempting to start it on a non-x86-64 platform will likely result in the container crashing (`exec format error`). If you are running on an ARM 32/64 bit platform, feel free to use `docker.io/dmesser/echoserver:1.10`. 

Verify that the pod is running:

`crictl ps -o table`

You should the pod running:

```
CONTAINER           IMAGE                                                              CREATED             STATE               NAME                ATTEMPT             POD ID
99cb17ca96800       365ec60129c5426b4cf160257c06f6ad062c709e0576c8b3d9a5dcc488f5252d   11 minutes ago      Running             echoserver          2                   adfbfd4a31754
```

Verify  that the firewall CNI plugin has created a rule to allow traffic to the container:

`firewall-cmd --info-zone=trusted`

You should see the IP address of the container/pod in the source list of the `trusted` zone:

```
trusted (active)
  target: ACCEPT
  icmp-block-inversion: no
  interfaces: 
  sources: 10.88.0.18/32
  services: 
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```

You should be able to `curl` the container on its container port:

`curl http://10.88.0.18:8080`

You should also be able to `curl` the container on its host port from another system:

`curl http://<host-ip>:9091`
 
