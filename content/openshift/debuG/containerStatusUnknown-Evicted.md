---
title: "Evicted Pods/ContainerStatusUnknown "
date: 2023-08-07
author: Tomas Dedic
description: "Evicted  pods, what is going on - thanos compactor"
lead: "DEBUG"
categories:
  - "Openshift"
tags:
  - "OCP"
  - "DEBUG"
---

```sh
➤ oc get pods
NAME                                       READY   STATUS                   RESTARTS   AGE
thanos-iocp4s-bucketweb-668f4dc7bc-9tnnx   1/1     Running                  0          5d17h
thanos-iocp4s-compactor-28186440-9n5x7     0/1     Evicted                  0          2d14h
thanos-iocp4s-compactor-28186440-9sb6r     0/1     ContainerStatusUnknown   0          2d14h
thanos-iocp4s-compactor-28186440-cp7xj     0/1     ContainerStatusUnknown   0          2d14h
thanos-iocp4s-compactor-28186440-d6vqm     0/1     Evicted                  0          2d14h
thanos-iocp4s-compactor-28186440-f5hlj     0/1     ContainerStatusUnknown   1          2d14h
thanos-iocp4s-compactor-28186440-fvdwj     0/1     ContainerStatusUnknown   0          2d14h
thanos-iocp4s-compactor-28186440-hmwwj     0/1     ContainerStatusUnknown   0          2d14h
thanos-iocp4s-compactor-28189320-nphjb     0/1     Completed                0          14h
thanos-iocp4s-compactor-28189680-6jkzm     0/1     Completed                0          8h
thanos-iocp4s-compactor-28190040-wrkrl     0/1     Completed                0          179m
thanos-iocp4s-receive-0                    1/1     Running                  0          5d17h
thanos-iocp4s-storegateway-0               1/1     Running                  0          5d17h
thanos-iocp4s-storegateway-1               1/1     Running                  0          5d17h
```
Problem is that thanos compactor is allocating too much diskspace for compaction and since no PV is used, it is evicted by kubelet.
```sh
oc describe pod thanos-iocp4s-compactor-28186440-d6vqm|grep -A 2 Status
Status:         Failed
Reason:         Evicted
Message:        Pod The node had condition: [DiskPressure].
# strange message from events
The node was low on resource: ephemeral-storage. Container compactor was using 20Ki, which exceeds its request of 0.
```

