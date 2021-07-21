---
title: "Gracefull pod termination with lifecycle"
date: 2021-07-01
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Openshift"
tags:
  - "OCP"
---
## Kubernetes POD termination process
It’s important that your application handle termination gracefully so that there is minimal impact on the end user and the time-to-recovery is as fast as possible!
  
In practice, this means your application needs to handle the SIGTERM message and begin shutting down when it receives it. This means saving all data that needs to be saved, closing down network connections, finishing any work that is left, and other similar tasks.
  
Once Kubernetes has decided to terminate your pod, a series of events takes place. Let’s look at each step of the Kubernetes termination lifecycle.

**1. Pod is set to the “Terminating” State and removed from the endpoints list of all Services**  
At this point, the pod stops getting new traffic. Containers running in the pod will not be affected.
**2. preStop Hook is executed**
The preStop Hook is a special command or http request that is sent to the containers in the pod.
If your application doesn’t gracefully shut down when receiving a SIGTERM you can use this hook to trigger a graceful shutdown. Most programs gracefully shut down when receiving a SIGTERM, but if you are using third-party code or are managing a system you don’t have control over, the preStop hook is a great way to trigger a graceful shutdown without modifying the application.

**3 - SIGTERM signal is sent to the pod**
At this point, Kubernetes send a SIGTERM signal  to the main process (PID 1) in each container.
Your code should listen for this event and start shutting down cleanly at this point. This may include stopping any long-lived connections (like a database connection or WebSocket stream), saving the current state, or anything like that.

**Even if you are using the preStop hook, it is important that you test what happens to your application if you send it a SIGTERM signal, so you are not surprised in production!**

**4.  Kubernetes waits for a grace period**
At this point, Kubernetes waits for a specified time called the termination grace period. By default, this is 30 seconds. It’s important to note that this happens in parallel to the preStop hook and the SIGTERM signal. Kubernetes does not wait for the preStop hook to finish.
If your app finishes shutting down and exits before the terminationGracePeriod is done, Kubernetes moves to the next step immediately.

If your pod usually takes longer than 30 seconds to shut down, make sure you increase the grace period. You can do that by setting the terminationGracePeriodSeconds option in the Pod YAML.
