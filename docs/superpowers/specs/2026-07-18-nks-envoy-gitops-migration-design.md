# NKS, Envoy Gateway, and Argo CD migration design

## Goal

Migrate Blue Bank Gateway from Docker Compose and Eureka discovery to Naver Cloud NKS, Kubernetes Service/DNS, Envoy Gateway, and Argo CD GitOps while preserving Spring Cloud Gateway JWT authentication, circuit breaking, Redis rate limiting, and business routing filters.

## Fixed decisions

- Cloud: Naver Cloud Ncloud Kubernetes Service (NKS)
- Kubernetes: 1.34
- Edge: Envoy Gateway v1.8.2 using Gateway API
- GitOps: Argo CD
- Packaging: Kustomize base with dev/prod overlays
- Development ingress: HTTP on the NKS LoadBalancer public IP; no domain or TLS yet
- Image registry: Naver Cloud Container Registry, using the explicit substitution token `REGISTRY_NAME.kr.ncr.ntruss.com/blue-bank-gateway` until the registry name is known
- Secrets: an out-of-band `blue-bank-gateway-secret`; no secret values in Git
- Redis: included as a single-replica StatefulSet and persistent volume for development; production overlay consumes an external Redis endpoint
- Business services: independently deployed Kubernetes Services named `account`, `deposit`, `loan`, and `card` in namespace `blue-bank`

## Architecture

```text
Internet
  -> NKS LoadBalancer Service
  -> Envoy Proxy managed by Envoy Gateway
  -> Gateway API HTTPRoute
  -> blue-bank-gateway ClusterIP Service :8080
  -> Spring Cloud Gateway
       -> account.blue-bank.svc.cluster.local:8100
       -> deposit.blue-bank.svc.cluster.local:8200
       -> loan.blue-bank.svc.cluster.local:8300
       -> card.blue-bank.svc.cluster.local:8400

Spring Cloud Gateway
  -> redis.blue-bank.svc.cluster.local:6379
```

Envoy owns north-south entry, the public LoadBalancer, and Gateway API routing to the Spring application. Spring Cloud Gateway continues to own JWT authentication, circuit breakers, Redis-backed request rate limiting, fallbacks, and business-specific filters. Nginx is not deployed to Kubernetes.

## Application migration

Remove `spring-cloud-starter-netflix-eureka-client` and all `eureka.*` configuration. Replace every `lb://SERVICE` target with configurable HTTP service URLs whose Kubernetes defaults use short in-namespace DNS names:

```text
ACCOUNT_SERVICE_URL=http://account:8100
DEPOSIT_SERVICE_URL=http://deposit:8200
LOAN_SERVICE_URL=http://loan:8300
CARD_SERVICE_URL=http://card:8400
```

The route configuration reads these properties, preserving current route IDs, paths, filters, circuit breakers, and fallback behavior. The obsolete Eureka-specific `lb` route configuration is removed to prevent duplicate route beans and accidental fallback to `lb://` discovery.

Kubernetes health probes use Spring Boot actuator probe groups. Development uses `/actuator/health/liveness` and `/actuator/health/readiness`. Production currently moves actuator under `/management`, so the prod overlay uses `/management/health/liveness` and `/management/health/readiness`.

## Kubernetes resources

`k8s/base` contains:

- `Namespace` named `blue-bank`
- Gateway `Deployment` with two replicas, rolling update, non-root security context, resource requests/limits, topology spread, and probes
- Gateway `Service` of type `ClusterIP`
- Redis `StatefulSet`, headless/ClusterIP service as needed, PVC, password sourced from the existing Secret, and readiness/liveness probes
- `ConfigMap` for non-secret service URLs and Spring profile defaults
- `PodDisruptionBudget` requiring at least one Gateway pod
- `HorizontalPodAutoscaler` scaling Gateway on CPU
- `GatewayClass`, HTTP `Gateway`, and `HTTPRoute` sending all paths to the Gateway Service
- Kustomization metadata and common labels

The dev overlay selects the NCR development image substitution token, `dev` Spring profile, in-cluster Redis, and public HTTP Gateway. The prod overlay selects the production image token, `prod` profile, greater replicas/resources, production probe paths, and an external Redis hostname supplied as a non-secret ConfigMap value. TLS and hostname are intentionally deferred until a domain is purchased.

The base requires `blue-bank-gateway-secret` keys `JWT_SECRET` and `REDIS_PASSWORD`. A documented `kubectl create secret generic` command creates it outside Git.

## Argo CD ownership

Two Applications separate cluster infrastructure from the workload:

1. `envoy-gateway`: installs the pinned Envoy Gateway v1.8.2 OCI Helm chart and its required CRDs into `envoy-gateway-system`.
2. `blue-bank-gateway-dev`: syncs `k8s/overlays/dev` into `blue-bank` with automated prune and self-heal.

The infrastructure Application must become healthy before the workload Gateway API resources are expected to reconcile. Documentation provides bootstrap order and health checks. Argo CD does not build images; CI builds the Docker image, pushes an immutable tag to NCR, and updates the Kustomize image tag in Git.

## Repository layout

```text
k8s/
  base/
  overlays/dev/
  overlays/prod/
argocd/
  envoy-gateway-application.yaml
  blue-bank-gateway-dev-application.yaml
docs/
  KUBERNETES_DEPLOYMENT.md
```

Docker Compose files remain available for local transition and rollback but are no longer the NKS deployment mechanism.

## Failure handling and operational safeguards

- Missing Secret prevents pods from starting instead of injecting insecure defaults.
- Missing business Services makes readiness remain meaningful for the Gateway process while requests fail through existing circuit-breaker fallbacks; deployment documentation includes DNS and endpoint checks.
- Redis readiness gates Gateway health through Spring health indicators and the Redis pod has its own probe.
- PDB, two Gateway replicas, rolling update, and HPA reduce planned disruption and load spikes.
- Argo CD prune/self-heal corrects manifest drift; immutable image tags prevent ambiguous rollbacks.
- The Gateway and Redis containers run as non-root and drop Linux capabilities.

## Verification

- Unit tests assert configured Kubernetes service URLs and confirm no `lb://` routes remain.
- `./gradlew clean test build` must succeed after Eureka removal.
- `docker build` must succeed for the Gateway image.
- `kubectl kustomize k8s/overlays/dev` and `prod` must render successfully.
- Static assertions verify no committed Secret values, no Eureka resources or settings, valid Gateway API references, correct probe paths, and the documented NCR substitution token.
- When an NKS cluster is available, server-side dry-run and rollout checks validate CRDs, Envoy Gateway, Gateway/HTTPRoute acceptance, public IP allocation, Redis readiness, Gateway readiness, and an HTTP request through Envoy.

## Deferred items

- Domain registration, DNS records, TLS certificate issuance, and HTTPS listener
- Production-grade managed or clustered Redis selection and credentials
- CI provider-specific NCR build/push pipeline
- Kubernetes manifests for account, deposit, loan, and card workloads
- Observability stack selection

## References

- NKS supports Kubernetes 1.34 for new clusters through January 2027: https://guide.ncloud-docs.com/docs/en/k8s-k8srelease
- Envoy Gateway v1.8 supports Kubernetes 1.32 through 1.35: https://gateway.envoyproxy.io/news/releases/matrix/
- Envoy Gateway v1.8.2 Helm installation: https://gateway.envoyproxy.io/docs/install/install-helm/
