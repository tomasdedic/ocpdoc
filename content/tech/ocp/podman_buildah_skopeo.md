---
title: "Podman,buildah,skopeo"
date: 2020-02-21 
author: Tomas Dedic
description: "Podman, buildah, skopeo hands on"
lead: "working"
categories:
  - "Containers"
tags:
  - "Containers"
---
[Demos git repository](https://github.com/containers/Demos)
# PODMAN IMAGES
## enable podman
user namespaces must be enabled in kernel to run container rootless
```sh
sudo sysctl -w kernel.unprivileged_userns_clone=1
```
## PODMAN CLI
```sh
podman version
podman pull alpine
podman images

 # build container
cat ./Dockerfile.hello
	FROM alpine
	RUN apk add python3
	ADD HelloFromContainer.py /home
	WORKDIR HOME
	CMD ["python3","/home/HelloFromContainer.py"]
podman build -t hello -f ./Dockerfile.hello .
podman run --name helloctr hello
podman commit -q --author "John Smith" helloctr myhello
 # images
podman images
podman images -q #only ID
podman images --noheading
podman images --no-trunc #all
podman images --digests #digests
podman images --format "table {{.ID}} {{.Repository}} {{.Tag}}"
podman images --format json
podman images --filter reference=alpine #only aplpine images
podman images --sort size
 # clean
podman rm -a -f #containers
podman rmi -a -f #images
```
## PODMAN USAGE
```sh
 # run non-root as root
podman exec -it --user=root e0ab9b96579a /bin/bash
```
## PODMAN INSPECT
```sh
podman inspect -t image alpine | less
podman run --name=myctr alpine  ls /etc/network
podman inspect -t container myctr | less
podman inspect --latest | less #inspect latest container
podman inspect  -t container --format "imagename: {{.ImageName}}" myctr
podman inspect  -t container --format "table {{.GraphDriver.Name}}" myctr
podman inspect -t image --format "size: {{.Size}}" alpine
```

## PODMAN PAUSE UNPAUSE
```sh
 # Let's create and run an alpine container for 10 minutes.
podman run --detach --name alpinectr alpine sh -c 'while true ;do sleep 600 ; done'
 # Let's create and run a busybox container for 10 minutes.
podman run --detach --name busyboxctr busybox sh -c 'while true ;do sleep 600 ; done'
podman ps --all
podman pause busyboxctr
podman unpause busyboxctr
```
## BUILDAH
```sh
buildah version
buildah info
buildah pull alpine
buildah images
sudo buildah from docker.io/library/alpine
sudo buildah containers
 # Create an empty image from 'scratch'
newcontainer=$(sudo buildah from scratch)
 # Now mount the container saving the mount point
scratchmnt=$(sudo buildah mount $newcontainer)
echo scratchmnt
 # Install Fedora 29 bash and coreutils into the container from the host.                                                        
sudo dnf install --installroot $scratchmnt --release 29 bash coreutils --setopt install_weak_deps=false -y
 # Show /usr/local/bin inside of the container
sudo buildah run $newcontainer -- ls -alF /usr/local/bin
---
 # Display contents of runecho.sh
	cat ./runecho.sh
	#!/usr/bin/env bash
	for i in {1..9};
	do
	   echo "This is a new container from buildahdemo [" $i "]"
	done
---
 # Copy the script into the container
sudo buildah copy $newcontainer ./runecho.sh /usr/local/bin
 # Set the cmd of the container to the script
sudo buildah config --cmd /usr/local/bin/runecho.sh $newcontainer
 # Let's run the container which will run the script
sudo buildah run working-container /usr/local/bin/runecho.sh
 # Configure the container added created-by then author information
sudo buildah config --created-by "buildahdemo"  $newcontainer
sudo buildah config --author "buildahdemo" --label name=fedora29-bashecho $newcontainer
sudo buildah inspect $newcontainer
sudo buildah unmount $newcontainer
 # Commit the image that we've created
sudo buildah commit $newcontainer fedora-bashecho
sudo buildah rm $newcontainer
```
## SECURITY
```sh
 # Buildah from scratch - building minimal images
ctr=$(sudo buildah from scratch)
mnt=$(sudo buildah mount $ctr)
sudo dnf install -y --installroot=$mnt busybox --releasever=29 --disablerepo=* --enablerepo=fedora
sudo dnf clean all --installroot=$mnt
sudo buildah unmount $ctr
sudo buildah commit --rm $ctr minimal-image


 # Buildah inside a container
cat Dockerfile.buildah (built previously)
	FROM fedora
	RUN dnf -y install buildah; dnf -y clean all
	ENTRYPOINT ["/usr/bin/buildah"]
	WORKDIR /root
cat Dockerfile (used inside buildah-ctr)
	FROM ubi8-minimal
	ENV foo=bar
	LABEL colour=bright

sudo podman run --device=/dev/fuse --rm -v $PWD/myvol:/myvol:Z -v /var/lib/mycontainer:/var/lib/containers:Z buildah/stable buildah bud -t myimage /myvol
sudo podman run --rm -v /var/lib/mycontainer:/var/lib/containers:Z buildah/stable buildah images
sudo podman run --rm -v /var/lib/mycontainer:/var/lib/containers:Z buildah/stable buildah rmi --force --all
```

## Podman as rootless
```sh
podman images | grep ubi8-minimal
podman pull ubi8-minimal
 # non-privileged images
podman images
 # privileged images
sudo podman images
podman run --rm ubi8-minimal id && echo On the host I am not root && id

 # The demo will now unshare the usernamespace of a rootless container,
 # using the 'buildah unshare' command.

 # First outside of the container, we will cat /etc/subuid, and you should
 # see your username.  This indicates the UID map that is assigned to you.
 # When executing buildah unshare, it will map your UID to root within the container
 # and then map the range of UIDS in /etc/subuid starting at UID=1 within your container.
cat /etc/subuid

 # Explore your home directory to see what it looks like while in a user namespace.
 # 'cat /proc/self/uid_map' will show you the user namespace mapping.
 # 'ls -al' will show a file owned by root on the host system, by nfsnobody in the userns.
buildah unshare
 # Podman User Namespace Support
sudo podman run --uidmap 0:100000:5000 -d fedora:latest sleep 1000
sudo podman top --latest user huser | grep --color=auto -B 1 100000
ps -ef | grep -v grep | grep --color=auto 100000
sudo podman run --uidmap 0:200000:5000 -d fedora:latest sleep 1000
sudo podman top --latest user huser | grep --color=auto -B 1 200000
ps -ef | grep -v grep | grep --color=auto 200000
```
## PODMAN FORK/EXEC MODEL
```sh
cat /proc/self/loginuid
sudo podman run -ti --rm fedora:latest bash -c "cat /proc/self/loginuid; echo"
sudo docker run -ti --rm fedora:latest bash -c "cat /proc/self/loginuid; echo"
sudo auditctl -w /etc/shadow
sudo podman run --rm --privileged -v /:/host fedora:latest touch /host/etc/shadow
ausearch -m path -ts recent -i | grep touch | grep --color=auto 'auid=[^ ]*'
sudo docker run --rm --privileged -v /:/host fedora:latest touch /host/etc/shadow
ausearch -m path -ts recent -i | grep touch | grep --color=auto 'auid=[^ ]*'
```

## PODMAN TOP
```sh
sudo podman run -d fedora:latest sleep 1000
sudo podman top --latest pid hpid
sudo podman top --latest label
```
## SKOPEO 
```sh
skopeo inspect docker://docker.io/fedora
 # Copy images from docker storage to podman storage
sudo skopeo copy docker-daemon:ubuntu:latest containers-storage:localhost/ubuntu:demo
```

## UDICA SELINUX
```sh
apt install udica setools-console
getenforce
podman run -v /home:/home:rw -v /var/spool:/var/spool:ro -p 21:21 -d fedora sleep 1h
podman top -l label
sesearch -A -s container_t -t home_root_t -c dir -p read
sesearch -A -s container_t -t var_spool_t -c dir -p read
sesearch -A -s container_t -t port_type -c tcp_socket
podman ps
podman inspect -l | udica  my_container
semodule -i my_container.cil /usr/share/udica/templates/{base_container.cil,net_container.cil,home_container.cil}
podman stop -l
podman run --security-opt label=type:my_container.process -v /home:/home:rw -v /var/spool:/var/spool:ro -p 21:21 -d fedora sleep 1h
podman top -l label
sesearch -A -s my_container.process -t home_root_t -c dir -p read
sesearch -A -s my_container.process -t var_spool_t -c dir -p read
sesearch -A -s my_container.process -t port_type -c tcp_socket
```
