
## What was wrong in the original manifest

You had:

```yaml
type: UrlRewrite
```

The correct filter type is case-sensitive:

```yaml
type: URLRewrite
```

You also had:

```yaml
path:
  type: /api/user
  replacePrefixMatch: true
```

That reverses the meaning of the fields. `type` specifies the rewrite strategy, while `replacePrefixMatch` contains the replacement path:

```yaml
path:
  type: ReplacePrefixMatch
  replacePrefixMatch: /api
```

## Why the match is `/legacy`

The request is:

```text
/legacy/users
```

You want the backend to receive:

```text
/api/users
```

The route splits the path conceptually into:

```text
matched prefix:    /legacy
remaining suffix:  /users
```

It replaces the matched prefix:

```text
/api + /users = /api/users
```

That is what `ReplacePrefixMatch` means.

Had you matched `/legacy/users`, the whole matched prefix would be replaced:

```text
/legacy/users -> /api
```

The `/users` portion would no longer remain.

## Request flow

The client sends:

```http
GET /legacy/users
Host: filters.gateway.local
```

Envoy processes it like this:

```text
1. Hostname matches filters.gateway.local

2. PathPrefix /legacy matches /legacy/users

3. URLRewrite changes:
   /legacy/users
   -> /api/users

4. RequestHeaderModifier sets:
   X-Gateway-Lab: rewritten

5. Request is forwarded to:
   Service stable, port 8080
```

The backend receives something equivalent to:

```http
GET /api/users
X-Gateway-Lab: rewritten
```

## Why `set` is used

The header modifier supports operations such as `add`, `set`, and `remove`.

Using:

```yaml
set:
  - name: X-Gateway-Lab
    value: rewritten
```

means:

> Ensure this header has exactly this value, replacing an existing value when necessary.

That makes the transformation deterministic.