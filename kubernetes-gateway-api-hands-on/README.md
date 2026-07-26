# Kubernetes Gateway API Hands-On Lab

A progressive, fill-in-the-blank project for practising Kubernetes Gateway API locally.

The project uses **Envoy Gateway v1.8.2** as the Gateway API implementation and deploys small HTTP echo applications that make routing decisions visible in responses and Pod logs.

## What you will practise

1. `GatewayClass` and `Gateway`
2. Basic `HTTPRoute` attachment
3. Path and header matching
4. Weighted traffic splitting
5. URL rewriting and request-header modification
6. Request mirroring
7. TLS termination at the Gateway
8. Cross-namespace routing and `ReferenceGrant`
9. A final challenge combining shared Gateways, TLS, redirects, routing, splitting, rewriting, mirroring, and cross-namespace authorization

## Project layout

```text
kubernetes-gateway-api-hands-on/
├── exercises/
│   ├── 00-environment-setup/
│   ├── 01-gatewayclass-and-gateway/
│   ├── 02-basic-httproute/
│   ├── 03-path-and-header-routing/
│   ├── 04-traffic-splitting/
│   ├── 05-request-filters/
│   ├── 06-request-mirroring/
│   ├── 07-tls-termination/
│   ├── 08-cross-namespace-routing/
│   └── 09-final-challenge/
├── platform/
├── scripts/
├── kind-config.yaml
├── Makefile
└── README.md
```

Every exercise contains:

```text
README.md              Explanation, task, commands, hints, expected results, troubleshooting
exercise/               Incomplete files containing ________ blanks
solution/               Completed, runnable manifests
validate.sh             Automated checks against the completed solution
```

## Prerequisites

Install the following tools:

- Docker
- `kubectl`
- Helm 3
- Either `kind` or Minikube
- `curl`
- OpenSSL
- Bash
- Optional: `jq`

The included setup defaults to Kubernetes `v1.35.0`. Envoy Gateway v1.8 supports Kubernetes v1.32 through v1.35 and uses Gateway API v1.5.1.

## Quick start with kind

```bash
unzip kubernetes-gateway-api-hands-on.zip
cd kubernetes-gateway-api-hands-on
make setup PROVIDER=kind
make status
```

## Quick start with Minikube

This option works well with Docker Desktop and WSL2:

```bash
make setup PROVIDER=minikube
make status
```

The Minikube setup creates one control-plane node and two worker nodes.

If you already have a cluster, do not run `make setup` until you have read
[Exercise 00](exercises/00-environment-setup/README.md). The default setup uses
the Minikube profile `gateway-api-lab`; Exercise 00 shows how to prepare the
currently selected cluster without accidentally creating another one.

## Work through an exercise

Start with Exercise 00 to prepare and verify the cluster:

```bash
cd exercises/00-environment-setup
cat README.md
```

After its validation passes, continue to Exercise 1.

Edit the files under `exercise/` and replace every:

```text
________
```

Apply your completed file:

```bash
kubectl apply -f exercise/
```

Compare it with the solution only after making your attempt:

```bash
diff -u exercise/gateway.yaml solution/gateway.yaml
```

Apply the completed solution when you need to recover:

```bash
kubectl apply -f solution/
```

Run the automated validation:

```bash
./validate.sh
```

## Generic Make targets

Apply any completed solution:

```bash
make apply-solution EX=02-basic-httproute
```

Validate an exercise:

```bash
make validate EX=02-basic-httproute
```

Start an HTTP port-forward to a Gateway:

```bash
make forward GATEWAY_NAMESPACE=gateway-lab GATEWAY_NAME=lab-gateway PORTS="8080:80"
```

Stop that port-forward:

```bash
make stop-forward PORT=8080
```

Reset all exercise resources while keeping the cluster and controller:

```bash
make reset
```

Remove lab resources and Envoy Gateway:

```bash
make cleanup
```

Delete the local cluster as well:

```bash
make destroy PROVIDER=kind
# or
make destroy PROVIDER=minikube
```

## How traffic reaches a local Gateway

A local kind or Minikube cluster may not assign a reachable external address to a `LoadBalancer` Service. The project therefore uses `kubectl port-forward`:

```text
curl localhost:8080
       |
       v
kubectl port-forward
       |
       v
Envoy Service created for the Gateway
       |
       v
Gateway listener -> HTTPRoute -> Service -> Pod
```

The `Host` header still controls hostname matching:

```bash
curl -H 'Host: basic.gateway.local' http://127.0.0.1:8080/
```

## Validation philosophy

The validation scripts check observable behavior, not only whether YAML was accepted. This distinction matters:

```text
Valid YAML
  != accepted Route
  != programmed Gateway
  != healthy backend
  != correct traffic behavior
```

Inspect resource status whenever traffic does not behave as expected:

```bash
kubectl get gateway -A
kubectl get httproute -A
kubectl describe gateway lab-gateway -n gateway-lab
kubectl describe httproute basic-route -n gateway-lab
kubectl get svc,endpoints,pods -A
```

## Important implementation note

Gateway API defines the Kubernetes resources and their semantics. Envoy Gateway is the controller and data-plane implementation used by this lab. Other implementations may create different supporting resources or support a different set of Extended features.

## Official references

- Gateway API overview: https://gateway-api.sigs.k8s.io/docs/concepts/api-overview/
- HTTP routing: https://gateway-api.sigs.k8s.io/guides/user-guides/http-routing/
- Traffic splitting: https://gateway-api.sigs.k8s.io/guides/user-guides/traffic-splitting/
- Request mirroring: https://gateway-api.sigs.k8s.io/guides/user-guides/http-request-mirroring/
- TLS: https://gateway-api.sigs.k8s.io/guides/user-guides/tls/
- ReferenceGrant: https://gateway-api.sigs.k8s.io/reference/api-types/referencegrant/
- Envoy Gateway quickstart: https://gateway.envoyproxy.io/v1.8/tasks/quickstart/
