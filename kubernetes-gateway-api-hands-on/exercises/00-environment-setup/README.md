# Exercise 00 — Prepare an Existing Cluster

## Apparently when you deploy a gateway it automatically deploys a service 
so the flow then becomes 
the gateway has a hostname and a listener on a set port,
then you define a httproute whose parent ref is the gateway above and then backend ref is a service to a deployment stable

and the way that you connect is 
(port forward acts as a local load balancer)
so open a port to the svc in the namespace `envoy-gateway-system` the service will match your listener port on the gateway
so open 8080 locally and target 80 on the envoy service
then on a seperate shell you can hit that opened port and routing will automatically take place

## 1. Goal

Prepare the Kubernetes cluster that is already selected by `kubectl`, then
verify that it is ready before Exercise 1.

The required order is:

```text
running Kubernetes cluster
  -> Envoy Gateway controller and Gateway API CRDs
  -> lab namespaces, Deployments, and Services
  -> readiness validation
  -> Exercise 1
```

Do **not** apply anything from Exercise 1 yet. Creating the `GatewayClass` and
`Gateway` is the task in that exercise.

## 2. Select the intended Minikube cluster

List the profiles and inspect the current kubectl context:

```bash
minikube profile list
kubectl config current-context
```

If your profile is named `multinode`, select it explicitly:

```bash
minikube profile multinode
kubectl config use-context multinode
```

Confirm that all three nodes are `Ready`:

```bash
kubectl get nodes
```

> `make setup PROVIDER=minikube` defaults to a different profile named
> `gateway-api-lab`. Do not use that command for an existing profile unless
> you deliberately set `CLUSTER_NAME`, for example
> `make setup PROVIDER=minikube CLUSTER_NAME=multinode`.

## 3. Install Envoy Gateway

Gateway API resources need a controller implementation. The platform manifests
only create namespaces and backend applications; they do not install the
controller.

From the project root, run:

```bash
cd /home/jeffndegwa/kubernetes-hands-on-lab/kubernetes-gateway-api-hands-on
./scripts/install-envoy-gateway.sh
```

This idempotent Helm installation creates:

- Envoy Gateway in `envoy-gateway-system`.
- The Gateway API CRDs used by the exercises.

Running it again is safe because the script uses `helm upgrade --install`.
The lab pins the published Envoy Gateway chart version `v1.8.2`. You can
override it explicitly with `ENVOY_GATEWAY_VERSION` when testing another
published version.

## 4. Deploy the lab platform

Apply the namespaces first and the applications second by using the provided
script:

```bash
./scripts/deploy-lab-apps.sh
```

This is also safe if you previously ran `kubectl apply -f platform/`; the
resources are declarative and will be reconciled to the same manifests.

## 5. About the TLS Secret

The TLS Secret is **not required for Exercises 1–6**. Exercise 7 tells you when
to create it and its validation script can create it automatically.

If you already ran this command, leave the Secret in place; it does not affect
the earlier exercises:

```bash
./scripts/create-tls-secret.sh
```

## 6. Validate readiness

Run the Exercise 00 validation:

```bash
./exercises/00-environment-setup/validate.sh
```

It verifies the current context, ready nodes, Envoy Gateway, required CRDs,
namespaces, backend Deployments, and Services. It does not change the cluster.

For a more detailed status display, also run:

```bash
make status
```

## 7. Continue to Exercise 1

Only after validation prints `PASS`, begin the first configuration exercise:

```bash
cd exercises/01-gatewayclass-and-gateway
cat README.md
```

Complete the blanks in `exercise/gateway.yaml`, apply it, and run that
exercise's validator.

## Troubleshooting

### The Gateway API resource type is unknown

Envoy Gateway or its CRDs have not been installed. Run:

```bash
./scripts/install-envoy-gateway.sh
```

### The applications are missing

Run:

```bash
./scripts/deploy-lab-apps.sh
```

### kubectl is connected to the wrong cluster

Stop before applying anything. Select the intended Minikube profile and context,
then rerun the validation:

```bash
minikube profile multinode
kubectl config use-context multinode
```
