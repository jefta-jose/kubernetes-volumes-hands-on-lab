# Exercise 8 — Cross-Namespace Routing and `ReferenceGrant`

## What you will learn

This exercise connects resources owned by three different namespaces:

| Namespace | Resource | Likely owner |
| --- | --- | --- |
| `infra` | `Gateway/shared-gateway` | Platform team |
| `team-a` | `HTTPRoute/team-a-route` | Application team |
| `shared-services` | `Service/shared-api` | Shared-services team |

The finished request flow is:

```text
curl with Host: team-a.shared.gateway.local
                         |
                         v
              infra/shared-gateway
                         |
              team-a/team-a-route
                         |
                         v
       shared-services/shared-api:8080
                         |
                         v
                  shared-api Pod
```

Gateway API does not automatically trust references that cross namespace
boundaries. This exercise therefore has two independent permission checks.

| Cross-namespace relationship | Permission mechanism | Permission owner |
| --- | --- | --- |
| `team-a` Route attaches to the `infra` Gateway | `Gateway.spec.listeners[].allowedRoutes` | `infra` |
| `team-a` Route uses the `shared-services` backend | `ReferenceGrant` | `shared-services` |

These permissions are intentionally separate:

- `allowedRoutes` does not authorize access to a backend Service.
- `ReferenceGrant` does not authorize attachment to a Gateway.
- A cross-namespace Route-to-Gateway attachment does not use a
  `ReferenceGrant`; the Gateway listener controls that relationship.

## Before you begin

Run commands from this exercise directory:

```bash
cd /home/jeffndegwa/kubernetes-hands-on-lab/kubernetes-gateway-api-hands-on/exercises/08-cross-namespace-routing
```

Confirm that the required namespaces, GatewayClass, and shared backend exist:

```bash
kubectl get namespace infra team-a shared-services --show-labels
kubectl get gatewayclass eg
kubectl get service shared-api -n shared-services
kubectl get pods -n shared-services
```

The `team-a` namespace must have this label:

```text
gateway-access=allowed
```

It is already defined by `platform/namespaces.yaml`. If it is missing, restore
it with:

```bash
kubectl label namespace team-a gateway-access=allowed --overwrite
```

## Your task

Replace every `________` in:

```bash
cat exercise/route.yaml
cat exercise/referencegrant.yaml
```

You can list the remaining blanks at any time:

```bash
grep -R -n '________' exercise/
```

The Gateway manifest is already complete. Read it before changing the other
files:

```bash
cat exercise/gateway.yaml
```

## Step 1 — Understand the shared Gateway

The Gateway is named `shared-gateway` and lives in `infra`:

```yaml
metadata:
  name: shared-gateway
  namespace: infra
```

Its listener accepts:

- HTTP traffic on port `80`.
- Hostnames matching `*.shared.gateway.local`.
- Routes from namespaces with the label `gateway-access: allowed`.

The relevant listener configuration is:

```yaml
hostname: "*.shared.gateway.local"
allowedRoutes:
  namespaces:
    from: Selector
    selector:
      matchLabels:
        gateway-access: allowed
```

`team-a` has that label, so a Route in `team-a` may attach. An unlabelled
namespace would be rejected with `NotAllowedByListeners`.

## Step 2 — Complete the HTTPRoute

Open `exercise/route.yaml`. The Route lives in `team-a`, while both its parent
Gateway and backend Service live elsewhere.

Complete its fields using this mapping:

| Field | Value | Reason |
| --- | --- | --- |
| `parentRefs[].name` | `shared-gateway` | Name of the Gateway |
| `parentRefs[].namespace` | `infra` | Namespace containing the Gateway |
| `backendRefs[].name` | `shared-api` | Name of the backend Service |
| `backendRefs[].namespace` | `shared-services` | Namespace containing the Service |

The Route hostname is already:

```yaml
hostnames:
  - team-a.shared.gateway.local
```

It intersects with the Gateway listener hostname
`*.shared.gateway.local`. The Route therefore passes the hostname portion of
the attachment check.

At this point the Route asks for both relationships:

```text
team-a/team-a-route
    parentRef  -> infra/shared-gateway
    backendRef -> shared-services/shared-api
```

The Gateway allows the first relationship because `team-a` has the required
label. The second relationship is not permitted until the next step.

## Step 3 — Complete the ReferenceGrant

A `ReferenceGrant` must be created in the namespace containing the object being
referenced. Because the target Service is
`shared-services/shared-api`, set:

```yaml
metadata:
  namespace: shared-services
```

The grant reads from the target namespace's point of view:

```text
Allow this source                         to reference this target
--------------------------------------    ---------------------------
HTTPRoute resources from team-a           Service/shared-api here
```

Complete the remaining fields using:

| Field | Value | Meaning |
| --- | --- | --- |
| `from[].group` | `gateway.networking.k8s.io` | API group containing HTTPRoute |
| `from[].kind` | `HTTPRoute` | Kind allowed to make the reference |
| `from[].namespace` | `team-a` | Namespace allowed to make the reference |
| `to[].group` | `""` | Services belong to Kubernetes' core API group |
| `to[].kind` | `Service` | Kind that may be referenced |
| `to[].name` | `shared-api` | Only this Service name is allowed |

The grant does not allow arbitrary resources from arbitrary namespaces. It
allows HTTPRoutes in `team-a` to reference the specifically named
`shared-api` Service in `shared-services`.

## Step 4 — Observe the denied reference first

Applying the Route before the ReferenceGrant makes the security behavior
visible:

```bash
kubectl apply -f exercise/gateway.yaml
kubectl apply -f exercise/route.yaml
kubectl describe httproute team-a-route -n team-a
```

The Route should attach to the Gateway, but its status should include:

```text
Accepted=True
ResolvedRefs=False
Reason=RefNotPermitted
```

This is expected. It proves that the Gateway listener accepted the Route while
the cross-namespace backend reference was independently denied.

## Step 5 — Grant access to the backend

Apply the completed ReferenceGrant:

```bash
kubectl apply -f exercise/referencegrant.yaml
```

Wait a few seconds for Envoy Gateway to reconcile, then inspect the Route:

```bash
kubectl describe httproute team-a-route -n team-a
```

Both of these conditions should now be true:

```text
Accepted=True
ResolvedRefs=True
```

You can print only those conditions with:

```bash
kubectl get httproute team-a-route -n team-a \
  -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status} reason={.reason}{"\n"}{end}'
```

Also check that the Gateway counts the attached Route:

```bash
kubectl describe gateway shared-gateway -n infra
```

Look for `Attached Routes: 1` under the HTTP listener.

## Step 6 — Send a request

The Envoy data-plane Service is inside the cluster. The helper script finds the
Service created for `infra/shared-gateway` and forwards local port `8080` to its
port `80`:

```bash
../../scripts/forward-gateway.sh infra shared-gateway 8080:80
```

Send a request using the hostname expected by the Gateway and HTTPRoute:

```bash
curl -sS -H 'Host: team-a.shared.gateway.local' \
  http://127.0.0.1:8080/
```

The response should contain:

```text
"app":"shared-api"
```

Stop the port-forward when finished:

```bash
../../scripts/stop-forward.sh 8080
```

## Why the `Host` header matters

The connection goes to `127.0.0.1:8080`, but Envoy selects the Route using the
HTTP `Host` header:

```text
TCP destination: 127.0.0.1:8080
HTTP hostname:   team-a.shared.gateway.local
```

Without the matching header, the request reaches Envoy but does not match this
HTTPRoute and will normally receive a `404`.

## Troubleshooting

### `NotAllowedByListeners`

The Route has not been allowed to attach to the Gateway.

```bash
kubectl get namespace team-a --show-labels
kubectl get gateway shared-gateway -n infra -o yaml
kubectl describe httproute team-a-route -n team-a
```

Check that:

- `team-a` has `gateway-access=allowed`.
- The Route's `parentRefs[].namespace` is `infra`.
- The Route hostname intersects with `*.shared.gateway.local`.

### `RefNotPermitted`

The Gateway accepted the Route, but the target namespace has not authorized
the backend reference.

```bash
kubectl get referencegrant -n shared-services -o yaml
kubectl describe httproute team-a-route -n team-a
```

Check that:

- The ReferenceGrant itself is in `shared-services`, not `team-a`.
- `from` specifies `HTTPRoute` in `team-a`.
- `to` specifies the core API group (`group: ""`), kind `Service`, and name
  `shared-api`.

### `BackendNotFound`

The reference is authorized, but the named Service or port cannot be found.

```bash
kubectl get service shared-api -n shared-services -o yaml
kubectl get endpoints shared-api -n shared-services
```

Confirm that `shared-api` exposes Service port `8080`.

### `curl: (7) Failed to connect`

The local port-forward is not running:

```bash
../../scripts/forward-gateway.sh infra shared-gateway 8080:80
cat ../../.runtime/forward-8080.log
```

### The response is `404`

Confirm that the request includes the exact hostname:

```bash
curl -v -H 'Host: team-a.shared.gateway.local' \
  http://127.0.0.1:8080/
```

## Validate and compare

After your manual test passes:

```bash
./validate.sh
```

Compare your work with the completed manifests only after making your attempt:

```bash
diff -u exercise/gateway.yaml solution/gateway.yaml
diff -u exercise/route.yaml solution/route.yaml
diff -u exercise/referencegrant.yaml solution/referencegrant.yaml
```

## Further reading

- [Gateway API cross-namespace routing](https://gateway-api.sigs.k8s.io/guides/user-guides/multiple-ns/)
- [Gateway API HTTPRoute](https://gateway-api.sigs.k8s.io/reference/api-types/httproute/)
- [Gateway API ReferenceGrant](https://gateway-api.sigs.k8s.io/reference/api-types/referencegrant/)
