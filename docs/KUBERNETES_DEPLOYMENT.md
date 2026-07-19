# NKS Kubernetes deployment

## Architecture

NKS Kubernetes 1.34 runs Envoy Gateway v1.8.2 in front of Spring Cloud Gateway. Kubernetes Services and DNS provide service discovery. Spring Cloud Gateway retains JWT authentication, Redis rate limiting, circuit breakers, fallbacks, and business filters.

## Required substitutions

Before Argo CD sync, replace these explicit tokens:

```text
REGISTRY_NAME.kr.ncr.ntruss.com/blue-bank-gateway
GIT_REPOSITORY_URL
prod-redis.example.internal
```

Use immutable NCR image tags instead of `dev` or `prod` for real releases.

## Bootstrap

1. Create an NKS Kubernetes 1.34 cluster and connect `kubectl`.
2. Install Argo CD in namespace `argocd`.
3. Create the application Secret outside Git:

```bash
kubectl create namespace blue-bank --dry-run=client -o yaml | kubectl apply -f -
kubectl -n blue-bank create secret generic blue-bank-gateway-secret \
  --from-literal=JWT_SECRET='replace-with-at-least-512-bits' \
  --from-literal=REDIS_PASSWORD='replace-with-a-strong-password'
```

4. Apply and wait for Envoy Gateway:

```bash
kubectl apply -f argocd/envoy-gateway-application.yaml
kubectl -n envoy-gateway-system rollout status deployment/envoy-gateway --timeout=5m
```

5. Apply the workload Application after replacing `GIT_REPOSITORY_URL`:

```bash
kubectl apply -f argocd/blue-bank-gateway-dev-application.yaml
```

## Image delivery

CI builds and pushes the image to NCR. Argo CD does not build images.

```bash
docker build -t REGISTRY_NAME.kr.ncr.ntruss.com/blue-bank-gateway:GIT_SHA .
docker push REGISTRY_NAME.kr.ncr.ntruss.com/blue-bank-gateway:GIT_SHA
```

Update `k8s/overlays/dev/kustomization.yaml` to the immutable tag and commit it. Argo CD then synchronizes the new version.

## Validation

```bash
kubectl kustomize k8s/overlays/dev
kubectl -n blue-bank get pods,svc,pvc
kubectl -n blue-bank get gateway,httproute
kubectl -n blue-bank describe gateway blue-bank
kubectl -n blue-bank get gateway blue-bank -o jsonpath='{.status.addresses[0].value}'
```

Once the Gateway has an external address:

```bash
curl "http://EXTERNAL_IP/actuator/health"
curl "http://EXTERNAL_IP/api/accounts"
```

Check Kubernetes Service DNS discovery:

```bash
kubectl -n blue-bank exec deploy/blue-bank-gateway -- getent hosts account deposit loan card redis
```

The business teams must deploy `account`, `deposit`, `loan`, and `card` Services into namespace `blue-bank` on ports 8100, 8200, 8300, and 8400 respectively.

## Production

The prod overlay excludes the development Redis StatefulSet and requires an external Redis endpoint. Replace `prod-redis.example.internal` before sync. Domain, TLS Secret, HTTPS Listener, and HTTP-to-HTTPS redirect are deferred until a domain is purchased.

## Rollback

Revert the Kustomize image tag commit and let Argo CD synchronize. For immediate rollback, use Argo CD history while also reverting Git so self-heal does not reapply the failed revision.
