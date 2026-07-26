# Final Challenge — Production-Style Shared Gateway

## 1. Concept

The final challenge combines infrastructure ownership, application-owned Routes, TLS termination, HTTP-to-HTTPS redirects, cross-namespace authorization, header routing, weighted rollout, URL rewriting, and request mirroring.

## 2. Task

Build the following platform:

```text
                         +------------------+
HTTP :80 --------------> | 301 HTTPS redirect|
                         +------------------+

HTTPS :443
    |
    +-- X-Release: canary ---------> gateway-lab/canary
    |
    +-- /api ----------------------> stable 90 / canary 10
    |                                  |
    |                                  +--> mirror copy
    |
    +-- /legacy/... --rewrite /api/...-> gateway-lab/stable
    |
    +-- everything else ------------> shared-services/shared-api
```

Architecture requirements:

- `infra/production-gateway` owns HTTP and HTTPS listeners.
- `team-a` owns both HTTPRoutes.
- `app.final.gateway.local` is the hostname.
- HTTP redirects to HTTPS with status 301.
- The HTTPS listener terminates TLS using the existing
  `gateway-lab/gateway-lab-tls` Secret.
- Cross-namespace backend access is authorized with least-privilege ReferenceGrants.

## 3. Incomplete files

```bash
find exercise -type f -maxdepth 1 -print
```

The exercise reuses `gateway-lab/gateway-lab-tls`. Because the Gateway and
Secret are in different namespaces, the certificate reference includes the
Secret namespace and a dedicated `ReferenceGrant` authorizes it.

## 4. Run and test

```bash
kubectl apply -f exercise/
../../scripts/forward-gateway.sh infra production-gateway 8090:80 9443:443
```

Test the redirect:

```bash
curl -si -H 'Host: app.final.gateway.local' http://127.0.0.1:8090/
```

Test the default HTTPS backend:

```bash
curl -sk --resolve app.final.gateway.local:9443:127.0.0.1 \
  https://app.final.gateway.local:9443/
```

Test the forced canary route:

```bash
curl -sk --resolve app.final.gateway.local:9443:127.0.0.1 \
  -H 'X-Release: canary' \
  https://app.final.gateway.local:9443/api/users
```

Test the rewrite:

```bash
curl -sk --resolve app.final.gateway.local:9443:127.0.0.1 \
  https://app.final.gateway.local:9443/legacy/users
```

Inspect mirrored traffic:

```bash
kubectl logs deployment/mirror -n gateway-lab --since=5m
```

## 5. Progressive hints

**Hint 1:** Create separate HTTPRoutes for HTTP redirect and HTTPS application traffic. Attach them using listener `sectionName` values.

**Hint 2:** Every cross-namespace backend reference needs permission from the target namespace.

**Hint 3:** Match both `/api` and `X-Release: canary` in the forced-canary rule. It is then more specific than the normal `/api` rule.

**Hint 4:** `RequestMirror` is a filter on the weighted `/api` rule; it does not become another normal backend.

**Hint 5:** Use `ReplacePrefixMatch` for `/legacy` so the suffix remains intact.

## 6. Expected result

- HTTP returns `301` with an HTTPS location.
- Default HTTPS traffic reaches `shared-api`.
- `X-Release: canary` always reaches `canary`.
- `/api` normally splits across stable and canary.
- `/legacy/users` reaches stable as `/api/users`.
- `/api` requests appear in the mirror logs.
- All Route status references resolve successfully.

## 7. Common errors and troubleshooting

### HTTP returns 404 instead of redirect

Check that the redirect Route attaches to `sectionName: http` and that its hostname matches the listener.

### HTTPS handshake fails

```bash
kubectl get secret gateway-lab-tls -n gateway-lab
kubectl describe gateway production-gateway -n infra
```

### `RefNotPermitted`

Inspect both target namespaces:

```bash
kubectl get referencegrant -n gateway-lab -o yaml
kubectl get referencegrant -n shared-services -o yaml
```

### Header traffic is still split

Verify the header rule has its own single backend and that the request uses the exact header value.

### Mirror logs are empty

Only `/api` traffic is mirrored in this design. Send a new `/api` request and inspect recent logs.

## 8. Completed solution

```bash
kubectl apply -f solution/
./validate.sh
```

After finishing, explain the trust boundaries in your own words:

1. Who owns the Gateway?
2. Who owns the Routes?
3. Which namespace authorizes backend access?
4. Which behavior belongs to Core Gateway API, and which features should be checked against implementation conformance?
