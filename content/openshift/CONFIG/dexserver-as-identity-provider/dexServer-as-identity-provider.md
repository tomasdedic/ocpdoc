
**AFAIK there is no builtin native OIDC provider for Openshift AuthN (using Openshift groups/users directly).** For Openshift API AUTHN, external OIDC providers (identity providers) are widely used (AAD, Google, Git ...).  
I would like to have "system applications" to authenticate directly againts **Openshift OAUTH server.**  
  
[We will try configure Dex Server as identity provider with AUTHN againts Openshift.](https://dexidp.io/docs/connectors/openshift/)  

[Very good illustrative guide](https://developer.okta.com/blog/2019/10/21/illustrated-guide-to-oauth-and-oidc)  
{{< figure src="oidc-authflow.jpg" caption="oidc-auth-flow" >}}

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: dex
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: dex
  name: dex
  namespace: dex
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dex
  template:
    metadata:
      labels:
        app: dex
    spec:
      serviceAccountName: dex-server # This is created below
      containers:
      - image: ghcr.io/dexidp/dex:v2.30.0
        name: dex
        command: ["/usr/local/bin/dex", "serve", "/etc/dex/cfg/config.yaml"]
        ports:
        - containerPort: 5556 #http port
        - containerPort: 5557
        - containerPort: 5558
        volumeMounts:
        - name: config
          mountPath: /etc/dex/cfg
      volumes:
      - name: config
        configMap:
          name: dex
          items:
          - key: config.yaml
            path: config.yaml
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: dex-server
  namespace: dex
spec:
  host: dex.apps.lab1.ocp4
  port:
    targetPort: http
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: edge
  to:
    kind: Service
    name: dex
    weight: 100
  wildcardPolicy: None
---
kind: Service
apiVersion: v1
metadata:
  name: dex
  namespace: dex
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 5556
  - name: grpc
    port: 5557
  - name: metrics
    port: 5558
  selector:
    app: dex
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dex-server
  namespace: dex
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: dex-server
subjects:
- kind: ServiceAccount
  name: dex-server
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dex-server
  namespace: dex
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  - configmaps
  verbs:
  - get
  - list
  - watch
---
# service account will be used as oauth-client
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    serviceaccounts.openshift.io/oauth-redirecturi.dex: https://dex.apps.lab1.ocp4/dex/callback
  name: dex-server
  namespace: dex
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: dex
  namespace: dex
data:
  config.yaml: |
    connectors:
    - id: openshift
      name: OpenShift
      type: openshift
      config:
        clientID: system:serviceaccount:dex:dex-server
        # service account token
        # oc serviceaccounts get-token dex-server -n dex
        clientSecret: eyJhbGciOiJSUzI1NiIsImtpZCI6InJackRndDB6emVXZVBKdDc2VmszUV9KeHpmeV83RURWeU42RV9Qc2JkWjgifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZXgiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlY3JldC5uYW1lIjoiZGV4LXNlcnZlci10b2tlbi10NHI4ZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJkZXgtc2VydmVyIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiODFjOTVhZDYtNTZlMS00OTlmLWE0MGMtM2Q2NTNhMzUxMDVjIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRleDpkZXgtc2VydmVyIn0.sj_SQLBQ1UaElSkigisNypmeAmpgnH3hvFFHaCG7ZR4DBfXY-MbdQxr4BmVNwar99WUcnI6ZMjuEIN_MIdeYog0dkSVXb5s5Zu1dv_d0nPNpuSmCwaCaRkgE_R_8FtVUp7OfdX2Pw8fYVGakD6FtrI6rRuncTNyFhQDmkiAgbRHFwkW-SVP305X8330UIvA0YMUNW5C6s0S4ULaSufv4Ug0IL_0WRyqQ-9pCv7KAYk7TRHrCsDhw7jrndIBNQ1k6A-1vwDpPT57lBEzHZ8xNBWkumed7OUEvT3enLkPCH_UlpHgR-eDxiPX36xivYHISj3Gp1T-IgC272zduJE8ANKn0Dfz0L5-PxjRXaojUdtkqKKtxbRLD_tRt5zZAlr4msVMCARTAvK6GV-cuU7kBQtqp7qevKDHP6Ht6i-NbuXjnM0apWGWLYVCdpNz6nlEeD6Esv-7BJ77fZ6h1oxnkswetQ3KhPqTCJ1F9SIrgKdhJ16sY_7mEsPKaEV13IgyNIY4GOWyqe6kVCjwCG-j9Oa9rJZ5tfP-wu6MLG7WaMN4eMQA5ZlBcjYlAHLxa-SaRmo6qVPKlbuqcEPIZwuqvU58dlzDSp1ONe5Owp3c9U_tpi49I55O3PLNddh_fNjzAfv3xzEXf_WfXCO3_U_suXBdsu3ZIZ3iYT1XfRFYfLNU
        insecureCA: true
        # openshift api
        issuer: https://api.lab1.ocp4:6443
        #redirect oauth back to dex
        redirectURI: https://dex.apps.lab1.ocp4/dex/callback
    grpc:
      addr: 0.0.0.0:5557
    issuer: https://dex.apps.lab1.ocp4/dex
    oauth2:
      skipApprovalScreen: false
      #define oidc clients
    staticClients:
    - id: exdex
      name: 'EXDEX'
      redirectURIs:
        - 'https://exdex.apps.lab1.ocp4/callback'
      secret: dohodnuteheslo
    storage:
      type: memory
    telemetry:
      http: 0.0.0.0:5558
    web:
      http: 0.0.0.0:5556
```

As a client we will use [example oidc client](https://github.com/dexidp/dex/tree/master/examples/example-app)
```bash
#build
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ex

#dockerfile
cat <<EOF >Dockerfile
FROM alpine:edge

LABEL name="exdex"
LABEL authors="dedtom@gmail.com"
LABEL version="0.1.0"

RUN apk --update --no-cache add bash grep curl
RUN adduser -D lsf
ADD ex /ex
RUN chmod a+x /ex
USER lsf
CMD ["/ex"]
EOF

#build image
podman build -f Dockerfile
#tag it and push to local openshift repository
podman tag f5cd20d7f0a9 ocr.apps.lab1.ocp4/dex/exdex:v01
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: dex
  creationTimestamp: null
  labels:
    app: exdex
  name: exdex
spec:
  replicas: 1
  selector:
    matchLabels:
      app: exdex
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: exdex
    spec:
      containers:
      - image: image-registry.openshift-image-registry.svc:5000/dex/exdex:v01
        name: exdex
        # config must match with configuration on dex ConfigMap
        command: ["sh","-c","/ex --issuer https://dex.apps.lab1.ocp4/dex --client-id exdex --client-secret dohodnuteheslo --debug --issuer-root-ca /var/run/secrets/kubernetes.io/serviceaccount/ca.crt --listen http://0.0.0.0:5555  --redirect-uri https://exdex.apps.lab1.ocp4/callback"]
        resources: {}
        ports:
          - containerPort: 5555
status: {}
---
kind: Service
apiVersion: v1
metadata:
  name: exdex
  namespace: dex
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 5555
  selector:
    app: exdex
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: exdex
  namespace: dex
spec:
  host: exdex.apps.lab1.ocp4
  port:
    targetPort: http
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: edge
  to:
    kind: Service
    name: exdex
    weight: 100
  wildcardPolicy: None
```
connect to Route host adress and pres NEXT
