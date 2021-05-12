---
title: "Is my ETCD backend fast enough, is ETCD encrypted, some notes around ETCD backup"
date: 2021-03-15 
author: Tomas Dedic
description: "Is my ETCD backend fast enough, is ETCD encrypted, some notes around ETCD backup"
lead: ""
categories:
  - "Openshift"
tags:
  - "SNIPPETS"
  - "ETCD"
---
[https://access.redhat.com/solutions/4770281](https://access.redhat.com/solutions/4770281)  
[https://docs.openshift.com/container-platform/4.7/scalability_and_performance/recommended-host-practices.html](https://docs.openshift.com/container-platform/4.7/scalability_and_performance/recommended-host-practices.html)  
[https://github.com/openshift/cluster-etcd-operator/blob/master/docs/etcd-tls-assets.md](https://github.com/openshift/cluster-etcd-operator/blob/master/docs/etcd-tls-assets.md)  
[https://www.ibm.com/cloud/blog/using-fio-to-tell-whether-your-storage-is-fast-enough-for-etcd](https://www.ibm.com/cloud/blog/using-fio-to-tell-whether-your-storage-is-fast-enough-for-etcd)  

## Using Fio to Tell Whether Your Storage is Fast Enough for Etcd
```sh
fio --rw=write --ioengine=sync --fdatasync=1 --directory=test-data --size=22m --bs=2300 --name=mytest
```
All you have to do then is look at the output and check if the 99th percentile of fdatasync durations is less than 10ms. If that is the case, then your storage is fast enough.  Here is an example output:
```sh
fsync/fdatasync/sync_file_range:
  sync (usec): min=534, max=15766, avg=1273.08, stdev=1084.70
  sync percentiles (usec):
   | 1.00th=[ 553], 5.00th=[ 578], 10.00th=[ 594], 20.00th=[ 627],
   | 30.00th=[ 709], 40.00th=[ 750], 50.00th=[ 783], 60.00th=[ 1549],
   | 70.00th=[ 1729], 80.00th=[ 1991], 90.00th=[ 2180], 95.00th=[ 2278],
   | 99.00th=[ 2376], 99.50th=[ 9634], 99.90th=[15795], 99.95th=[15795],
   | 99.99th=[15795]
```

The first thing we did was to use strace to examine the etcd server backing Kubernetes while the cluster was idling. This showed us that the WAL write sizes were very tightly grouped, almost all in the range 2200–2400 bytes. That’s why in the command at the top of this post there’s the flag --bs=2300 (bs is the size in bytes of each write fio makes). Notice that the size of the etcd writes might vary depending on etcdversion, deployment, parameters values, etc., and it affects fdatasync duration. If you have a similar use case, you should analyze your own etcd processes with strace to get meaningful numbers.  

Next, to get a clear and comprehensive view of the filesystem activities of etcd, we launched it under stracewith the -ffttT flags, meaning to examine the forked processes and write each one’s output in a separate file and also to give detailed reports of the start and elapsed time of each system call. We also used lsof to confirm our parsing of the strace output regarding which file descriptor was being used for which purpose. These led to the sort of strace output shown above. Doing statistics on the sync times confirmed that the wal_fsync_duration_seconds metric from etcd corresponds with the fdatasync calls with the WAL file descriptors.  

To get fio to generate a workload similar to etcd’s, we read the fio docs and developed parameters to serve our purpose. We confirmed the system calls and their timing by running fio from strace, as we did for etcd.  

We took care when setting the value of the --size parameter, which represents the total I/O fio generates. In our case, that’s the total number of bytes written to storage—which is directly proportional to the number of write (and fdatasync) system call invocations. For a given bs, the number of fdatasync invocations is size/bs. Since we were interested in a percentile, we wanted the number of samples to be high enough to be statistically relevant, and we found 10^4 (which makes up for a size of 22 MiB) to serve our purpose. Lower values of --size have more pronounced noise (e.g., few fdatasync invocations that take way longer than usual and affect the 99th percentile).  

## Test speed directly on Openshift node
```sh
oc debug node/<master_node>
chroot /host bash
podman run --volume /var/lib/etcd:/var/lib/etcd:Z quay.io/openshift-scale/etcd-perf
```

## USE external disk just for ETCD (faster disk)
jen je potreba upravit disk pro **/var/lib/etcd** (teda tam kde ma sidlo ETCD)
[https://access.redhat.com/solutions/4952011](https://access.redhat.com/solutions/4952011)

## ETCD Compact vs defrag
Compact se deje myslim kazdych 5 min ale nechava prazdna mista v DB ( v podstate maze stare verze klicu), defrag se deje pri kazdem rebootu nodu.
Da se to vynutit i manualnce prez ETCD ale asi bych to nedoporucoval.

## ETCD BACKUP
Backup are snapshots of database.  
Obnoveni je ok pokud bezi muj cluster, pokud ne a sli bychom cestou "disaster recovery" gitops pristup se jevi jako lepsi.

## ETCD Encryption
```sh
# check for encryption
oc get openshiftapiserver -o=jsonpath='{range .items[0].status.conditions[?(@.type=="Encrypted")]}{.reason}{"\n"}{.message}{"\n"}'
oc get kubeapiserver -o=jsonpath='{range .items[0].status.conditions[?(@.type=="Encrypted")]}{.reason}{"\n"}{.message}{"\n"}'
oc get authentication.operator.openshift.io -o=jsonpath='{range .items[0].status.conditions[?(@.type=="Encrypted")]}{.reason}{"\n"}{.message}{"\n"}'
```
```sh
# encrypt 
oc edit apiserver
spec:
  encryption:
    type: aescbc

# decrypt
spec:
  encryption:
    type: identity
```
