---
title: "KIND with metallb"
date: 2023-09-13
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Kubernetes"
tags:
  - "METALLB"
---
## 1. Install K8s Cluster using KIND

[Kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/) is a tool that allows you to create local Kubernetes clusters using Docker containers. It provides an environment to run Kubernetes clusters for development, testing, and experimentation purposes. 

The benefits of using Kind include easy setup and teardown of clusters, fast cluster creation, and the ability to simulate multi-node Kubernetes clusters on a single machine. It helps streamline the development and testing workflow by providing a lightweight and isolated environment that closely resembles a production Kubernetes cluster.

* Install Docker and ensure that the Docker service is enabled and running:

```
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce --nobest 
sudo systemctl enable --now docker
```

NOTE: also Podman can be used, but for certain parts of this blog post, Docker worked out of the box without further tweaks in KIND.


```
CLUSTER_NAME="seldon"
cat <<EOF | kind create cluster --name $CLUSTER_NAME --wait 200s --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

```md
kubectl cluster-info --context kind-seldon
```

## 2. Installing K8s Ingress Controller

Kubernetes Ingress is crucial for managing external access to services within a cluster, providing routing and load balancing capabilities. Nginx Ingress, as a popular Ingress controller, enables seamless traffic distribution, SSL termination, and routing based on hostnames or paths, enhancing scalability and security.

* Install the [Ingress Nginx adapted for Kind](https://kind.sigs.k8s.io/docs/user/ingress/):

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
```

The provided command installs Nginx Ingress, extending Kubernetes functionality by efficiently directing incoming external requests to appropriate services using defined rules and configurations. This optimizes resource utilization and simplifies external connectivity management.

## 3. MetalLB

Kubernetes lacks native support for network load balancers (LoadBalancer-type Services) in bare-metal clusters. The existing load balancer implementations in Kubernetes are essentially connectors to various IaaS platforms (GCP, AWS, Azure...). Because our setup doesn't match these supported IaaS platforms, newly created LoadBalancers will indefinitely stay in a "pending" state.

Because of that, with our Baremetal K8s clusters we have left with two suboptimal options to direct user traffic to our apps in the K8s clusters: "NodePort" and "externalIPs" services. Both choices have notable drawbacks for production use, "relegating" Baremetal clusters to a secondary position in the Kubernetes ecosystem.

MetalLB seeks to rectify this situation by providing a network load balancer solution that seamlessly integrates with standard network equipment. This approach ensures that external services function as smoothly as possible on Baremetal clusters, addressing the existing imbalance.

### 3.1 Install MetalLB 

* Since version 0.13.0, MetalLB is configured via CRs and the original way of configuring it via a ConfigMap based configuration is not working anymore:

```md
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
```

* Wait until the MetalLB pods (controller and speakers) are ready:

```md
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s
```

### 3.2  Setup address pool used by MetalLB Load Balancers in KIND

With MetalLB, Layer 2 mode is the simplest for us to configure: in many cases, we don't require any protocol-specific setup, only IP addresses.

In our Layer 2 mode, we don't need the IPs to be tied to our worker nodes' network interfaces. The system operates by directly responding to ARP requests on our local network, furnishing clients with the machine’s MAC address.

* To finalize the layer2 setup, we must provide to MetalLB with a designated IP address range under its control. Our intention is for this range that is within the docker Kind network:

```md
docker network inspect -f '{{.IPAM.Config}}' kind
```

NOTE: When using Docker on Linux (or KIND), it's possible to route traffic directly to the external IP of the load balancer, given that the IP range falls within the Docker IP space.

* The result will include a CIDR, like 172.19.0.0/16. Our aim is to allocate load balancer IP addresses from this specific subset. We can set up MetalLB, for example, to utilize the range from 172.19.255.200 to 172.19.255.250. This involves establishing an IPAddressPool and the associated L2Advertisement:

```
kubectl apply -f - << END
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
END
```

* To promote the IP originating from an IPAddressPool, an L2Advertisement instance needs to be linked with the respective IPAddressPool:

```
kubectl apply -f - << END
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
END
```

Setting no IPAddressPool selector in an L2Advertisement instance is interpreted as that instance being associated to all the IPAddressPools available.

### 3.3 Testing the MetalLB deployment

* In order to test our dummy app, we will deploy a dummy app and we will check if we can use the K8s LoadBalancer fueled by MetalLB to access to our app:  

```md
kubectl apply -f https://kind.sigs.k8s.io/examples/loadbalancer/usage.yaml
LB_IP=$(kubectl get svc/foo-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl ${LB_IP}:5678
```

## 4. ServiceMesh and Istio

A Service Mesh is an infrastructure layer added to modern distributed microservices applications, enhancing them with transparent capabilities like observability, traffic management, and security. It simplifies complex operational needs such as A/B testing, canary deployments, and access control.

Istio is an open source service mesh solution that seamlessly integrates with existing distributed applications. It provides centralized features like secure communication, load balancing, traffic control, access policies, and automatic metrics. Istio is adaptable, supporting Kubernetes deployments and extending to other clusters or endpoints.

Its control plane offers TLS encryption, strong authentication, load balancing, and fine-grained traffic control. Istio's ecosystem includes diverse contributors, partners, and integrations, making it versatile for various use cases. 

Let's install Istio in Kind!

### 4.1 Install Istio in KIND

* Download and install Istioctl latest version:

```md
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.17.2
chmod u+x istioctl
cp -pr istioctl /usr/local/bin/
```

* Install Istio in our K8s cluster using istioctl:

```md
istioctl install --set profile=demo -y

kubectl get service -n istio-system istio-ingressgateway
```

* Deploy the Bookinfo application to test the Service Mesh:

```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/platform/kube/bookinfo.yaml

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.17/samples/bookinfo/networking/bookinfo-gateway.yaml
```

* Retrieve and export the IP address of the Istio Ingress Gateway and the associated ports for HTTP and HTTPS services from the Kubernetes cluster's Istio system namespace:

```
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
```

* Test the Bookinfo ProductPage app using the Istio Ingress Gateway:  

```
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
curl -I http://$GATEWAY_URL/productpage
```

