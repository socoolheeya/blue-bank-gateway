# NCP 개발 서버 구축 튜토리얼

이 문서는 Blue Bank 프로젝트를 NCP 개발 환경에 처음부터 구축할 때 따라 하는 실행 절차입니다. 콘솔에서 생성할 리소스와 터미널 명령을 시간 순서로 정리했습니다.

## 0. 사전 준비

필요한 계정과 도구:

- NCP Main Account
- NCP Sub Account(권장)
- macOS Homebrew
- Docker
- `kubectl`
- `helm`
- `git`

도구 확인:

```bash
docker version
kubectl version --client
helm version
git --version
```

### macOS Homebrew 설치 도구

Homebrew가 없다면 먼저 설치합니다.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

설치 후 셸 PATH를 적용합니다. Apple Silicon Mac 예시:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update
```

이번 구축에서 사용한 도구:

```bash
brew install kubectl
brew install helm
brew install ncp-iam-authenticator
brew install jq
brew install yq
brew install stern
```

Docker Desktop은 Docker 공식 사이트에서 설치하거나 이미 설치된 Docker를 사용합니다.

```bash
brew install --cask docker
open -a Docker
docker version
docker info
```

도구별 설치 상태:

```bash
which brew
which docker
which kubectl
which helm
which ncp-iam-authenticator
which jq
which yq
which stern
```

설치가 꼬였을 때 Homebrew 패키지 상태:

```bash
brew list
brew info kubectl helm ncp-iam-authenticator
brew doctor
```

NCP API 키는 절대 문서나 셸 히스토리에 남기지 않습니다. 아래 값은 예시입니다.

```bash
export NCLOUD_ACCESS_KEY="<ACCESS_KEY>"
export NCLOUD_SECRET_KEY="<SECRET_KEY>"
export NCLOUD_API_GW="https://ncloud.apigw.ntruss.com"
export NCLOUD_REGION="KR"
```

## 1. Sub Account 생성

NCP Console → Services → Management & Governance → Sub Account에서 생성합니다.

1. Sub Account 생성
2. Console 접근 필요 시 `콘솔 접근` 활성화
3. 개발자 고정 IP가 있다면 `지정한 IP 대역에서만 접근 가능` 선택
4. 예시 IP 형식: `203.0.113.10/32`
5. API Gateway 접근 권한 활성화
6. Sub Account 로그인 URL과 Access Key/Secret Key 발급

`/32`는 단일 IP 한 개만 허용한다는 의미입니다. 현재 공인 IP 확인:

```bash
curl -s https://ifconfig.me
```

Sub Account에 NKS 접근 정책을 부여하고, NKS 클러스터 생성 후 Access Entry에 해당 Sub Account를 등록합니다. API 인증 모드 클러스터에서는 오래된 `ncp-auth` ConfigMap 방식보다 NKS Access Entry를 사용합니다.

## 2. VPC 생성

NCP Console → VPC → VPC 관리 → VPC 생성:

- VPC 이름: `blue-bank-dev-vpc`
- IP 주소 범위: `10.0.0.0/16`

생성 후 VPC ID를 기록합니다. 이후 모든 Subnet은 이 VPC에 생성합니다.

## 3. Subnet 생성

VPC → Subnet 관리 → Subnet 생성에서 다음 4개를 생성합니다.

| 이름 | CIDR | Public/Private | 용도 |
|---|---|---|---|
| `blue-bank-dev-worker` | `10.0.10.0/24` | Private | NKS Worker, GEN |
| `blue-bank-dev-private-lb` | `10.0.20.0/24` | Private | 내부 LB, LOADB |
| `blue-bank-dev-public-lb` | `10.0.30.0/24` | Public | 외부 LB, LOADB |
| `blue-bank-dev-nat` | `10.0.40.0/24` | Public | NAT Gateway, NATGW |

Worker Subnet은 외부에서 직접 접근하지 않고 NAT Gateway를 통해 외부로 나갑니다. Public LB Subnet은 Envoy Gateway의 NCP LoadBalancer가 사용할 Subnet입니다.

## 4. NAT Gateway와 Route Table

VPC → NAT Gateway → NAT Gateway 생성:

1. NAT Subnet으로 `blue-bank-dev-nat` 선택
2. NAT Gateway 생성
3. 생성된 NAT Gateway ID 기록

VPC → Route Table → Route Table 생성:

- 이름: `blue-bank-dev-worker-rt`
- 대상 VPC: `blue-bank-dev-vpc`

Route 추가:

```text
Destination: 0.0.0.0/0
Target: NAT Gateway
```

Route Table의 Subnet 연결에서 Worker Subnet을 연결합니다. Public LB Subnet은 Public Route Table에 연결하고, Private LB Subnet은 Private Route Table에 연결합니다.

## 5. NKS 클러스터 생성

NCP Console → Kubernetes Service → Clusters → 클러스터 생성:

1. 클러스터명: `blue-bank-dev-nks`
2. Kubernetes 버전 선택
3. 인증 모드: API 인증
4. VPC: `blue-bank-dev-vpc`
5. Worker Subnet: `blue-bank-dev-worker`
6. Public LB Subnet: `blue-bank-dev-public-lb`
7. 개발 노드풀 이름은 20자 이하, 예: `blue-bank-dev-w`
8. 개발용 노드 수는 2개 이상, 운영 분산은 3개 이상
9. 인증키 설정에서 NCP 인증키를 선택
10. 클러스터 생성

클러스터 상세 화면에서 Endpoint URL과 Cluster UUID를 기록합니다.

### Endpoint IP ACL

NKS 클러스터 상세 → Kubernetes API Endpoint 또는 Endpoint 접근 설정에서 IP ACL을 엽니다. 현재 개발자 공인 IP를 `/32`로 추가합니다.

```bash
curl -s https://ifconfig.me
```

Endpoint ACL을 설정하지 않으면 kubeconfig가 있어도 API Server 접속이 거부될 수 있습니다.

## 6. NKS kubeconfig 발급

```bash
brew install ncp-iam-authenticator
which ncp-iam-authenticator
mkdir -p .kube

export KUBECONFIG="$PWD/.kube/blue-bank-dev.yaml"
ncp-iam-authenticator update-kubeconfig \
  --region KR \
  --clusterUuid <CLUSTER_UUID> \
  --kubeconfig "$KUBECONFIG" \
  --overwrite

kubectl config current-context
kubectl get nodes -o wide
```

`cannot create config file`이 나오면 부모 디렉터리가 없는 것입니다.

```bash
mkdir -p "$HOME/.ncloud"
mkdir -p "$(dirname "$KUBECONFIG")"
```

`Unauthorized`일 때 점검:

```bash
echo "$KUBECONFIG"
kubectl config current-context
env | grep '^NCLOUD_'
ncp-iam-authenticator update-kubeconfig \
  --region KR \
  --clusterUuid <CLUSTER_UUID> \
  --kubeconfig "$KUBECONFIG" \
  --overwrite
```

NKS context와 로컬 context를 구분합니다.

```bash
kubectl config get-contexts
kubectl config use-context nks_kr_<cluster>_<uuid>
```

## 7. Object Storage와 NCR

NCP Console → Object Storage에서 필요 시 버킷을 생성합니다. Terraform state나 백업을 저장할 때 사용합니다. 애플리케이션 이미지는 Object Storage가 아니라 Container Registry(NCR)에 저장합니다.

NCP Console → Container Registry → Registry 생성:

```text
Registry: blue-bank-dev
Endpoint: blue-bank-dev.kr.ncr.ntruss.com
```

로컬 로그인:

```bash
docker login blue-bank-dev.kr.ncr.ntruss.com \
  -u "$NCLOUD_ACCESS_KEY" \
  -p "$NCLOUD_SECRET_KEY"
```

이미지와 플랫폼 확인:

```bash
docker image ls
docker buildx ls
docker buildx inspect --bootstrap
docker buildx imagetools inspect \
  blue-bank-dev.kr.ncr.ntruss.com/blue-bank-gateway:dev-<SHA>
```

`no match for platform in manifest`가 나오면 반드시 `linux/amd64`로 빌드합니다.

```bash
docker buildx build \
  --platform linux/amd64 \
  -t blue-bank-dev.kr.ncr.ntruss.com/blue-bank-gateway:dev-<SHA> \
  --push .
```

NKS Namespace와 Registry Secret:

```bash
kubectl create namespace blue-bank
kubectl create secret docker-registry ncr-registry \
  -n blue-bank \
  --docker-server=blue-bank-dev.kr.ncr.ntruss.com \
  --docker-username="$NCLOUD_ACCESS_KEY" \
  --docker-password="$NCLOUD_SECRET_KEY"
```

Gateway Secret:

```bash
JWT_SECRET_VALUE="$(openssl rand -base64 48)"
REDIS_PASSWORD_VALUE="$(openssl rand -base64 32)"
kubectl create secret generic blue-bank-gateway-secret \
  -n blue-bank \
  --from-literal=JWT_SECRET="$JWT_SECRET_VALUE" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD_VALUE"
unset JWT_SECRET_VALUE REDIS_PASSWORD_VALUE
```

## 8. Argo CD 설치

Gateway 저장소에서:

```bash
./infra/scripts/bootstrap-argocd.sh
kubectl get pods -n argocd
kubectl get applications -n argocd
```

Argo CD Application 상세 상태:

```bash
kubectl get application blue-bank-gateway-dev -n argocd -o yaml
kubectl get application blue-bank-gateway-dev -n argocd \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{" "}{.status.sync.revision}{"\n"}'
kubectl describe application blue-bank-gateway-dev -n argocd
```

Argo CD가 잘못된 Repository/branch/path를 보는지 확인합니다.

```bash
kubectl get application blue-bank-gateway-dev -n argocd \
  -o jsonpath='{.spec.source.repoURL}{"\n"}{.spec.source.targetRevision}{"\n"}{.spec.source.path}{"\n"}'
```

Argo CD Server 접속:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

브라우저:

```text
https://localhost:8080
```

초기 비밀번호:

```bash
argocd admin initial-password -n argocd
```

## 9. Envoy Gateway와 Application

Envoy Gateway Application은 Helm Chart로 설치되고, Gateway 리소스는 Gateway 저장소의 Kustomize manifest가 관리합니다.

```bash
kubectl get pods -n envoy-gateway-system
kubectl get gateway -n blue-bank
kubectl get httproute -n blue-bank
kubectl get svc -n envoy-gateway-system -o wide
```

업무 서비스 Application 생성 예시:

```bash
kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: blue-bank-services-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/socoolheeya/blue-bank.git
    targetRevision: main
    path: k8s/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: blue-bank
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

Heredoc은 마지막 `EOF`를 공백 없이 줄의 처음에 입력해야 합니다.

## 10. 서비스 포트와 DNS

서비스 이름과 포트는 다음과 같이 통일합니다.

```text
blue-bank-account:8100
blue-bank-deposit:8200
blue-bank-loan:8300
blue-bank-card:8400
redis:6379
blue-bank-gateway:8080
```

확인:

```bash
kubectl get svc -n blue-bank
kubectl get endpointslices -n blue-bank
```

Gateway ConfigMap:

```yaml
SERVICES_ACCOUNT_URL: http://blue-bank-account:8100
SERVICES_DEPOSIT_URL: http://blue-bank-deposit:8200
SERVICES_LOAN_URL: http://blue-bank-loan:8300
SERVICES_CARD_URL: http://blue-bank-card:8400
```

내부 DNS 테스트:

```bash
kubectl run netcheck -n blue-bank --rm -it \
  --restart=Never --image=curlimages/curl:8.10.1 -- sh
```

컨테이너 안에서:

```bash
curl -i http://blue-bank-account:8100/actuator/health
curl -i http://blue-bank-deposit:8200/actuator/health
curl -i http://blue-bank-loan:8300/actuator/health
curl -i http://blue-bank-card:8400/actuator/health
```

## 11. 외부 호출

```bash
export LB_HOST="<EXTERNAL_LB_HOSTNAME>"
printf '<%s>\n' "$LB_HOST"
curl -i "http://${LB_HOST}/api/accounts"
```

브라우저에는 다음을 입력합니다.

```text
http://<EXTERNAL_LB_HOSTNAME>/api/accounts
```

`LB_HOST`에 터미널 프롬프트 문자나 공백을 복사하면 `Could not resolve host: api`가 발생합니다. 반드시 hostname만 설정합니다.

## 12. GitHub Actions 자동 배포

Gateway와 업무 서비스 Repository Settings → Secrets and variables → Actions에 다음을 등록합니다.

```text
NCR_ENDPOINT
NCLOUD_ACCESS_KEY
NCLOUD_SECRET_KEY
```

workflow는 다음 작업을 합니다.

1. Java 25 빌드
2. `linux/amd64` Docker 이미지 생성
3. NCR에 `dev-${GITHUB_SHA}`와 `latest` push
4. `k8s/overlays/dev/kustomization.yaml`의 `newTag` 자동 변경
5. GitHub Actions bot 커밋·push
6. Argo CD가 manifest를 감지해 롤링 배포

```bash
git log --oneline -5
grep -n "newTag" k8s/overlays/dev/kustomization.yaml
kubectl get application blue-bank-gateway-dev -n argocd
```

이미지 태그가 예상과 다를 때 확인합니다.

```bash
git log -1 --format='%H %s'
git show --stat --oneline HEAD
kubectl get deployment blue-bank-gateway -n blue-bank \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl get pods -n blue-bank \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase'
```

GitHub Actions의 `update-manifest`가 실패하면 다음 원인을 확인합니다.

- `NCR_ENDPOINT`, `NCLOUD_ACCESS_KEY`, `NCLOUD_SECRET_KEY` Secret 이름 오타
- `docker/login-action`의 registry가 NCR endpoint와 일치하지 않음
- workflow가 `main`을 checkout하면서 다른 branch를 push함
- Protected Branch가 GitHub Actions bot의 push를 차단함
- `k8s/**`를 trigger path에 넣어 manifest bot commit이 workflow를 무한 재실행함
- `newTag`가 없어서 `sed`가 치환하지 못함

Workflow 로그에서 다음 단계가 모두 성공해야 합니다.

```text
Login to NCR
Build service / Build and push image
Update dev image tag
Commit and push manifest
```

운영 `release` 브랜치를 보호하면 직접 push 대신 자동 PR 생성 방식을 사용합니다. `main`/`release` workflow와 Argo CD `targetRevision`은 반드시 동일한 브랜치를 바라봐야 합니다.

## 13. 자주 발생한 오류

### 이미지 platform 오류

```text
no match for platform in manifest
```

```bash
docker buildx build --platform linux/amd64 --push .
```

### `latest: not found`

CI가 `latest`를 push하지 않았거나 NCR Repository 이름이 다릅니다. 실제 배포에는 SHA 태그를 사용하고, CI가 SHA와 latest를 모두 push하게 합니다.

### `ImagePullBackOff`

```bash
kubectl describe pod <POD> -n blue-bank
kubectl get secret ncr-registry -n blue-bank
```

Pod 이벤트만 모아서 확인합니다.

```bash
kubectl get events -n blue-bank \
  --sort-by='.lastTimestamp' | tail -50
```

이미지 이름/태그/플랫폼을 한 번에 확인합니다.

```bash
kubectl get deployment -n blue-bank \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'
kubectl describe pod <POD> -n blue-bank | sed -n '/Events:/,$p'
```

NCR에 실제 태그가 있는지 NCP Console 또는 Docker Registry 조회로 확인하고, `latest`를 Deployment에서 사용한다면 CI가 `latest`도 push했는지 확인합니다. 운영 배포는 `dev-<GITHUB_SHA>` 같은 immutable 태그가 더 안전합니다.

Events의 `not found`, `unauthorized`, `no match for platform`을 구분합니다.

### Java class version 오류

```text
class file version 69.0 ... recognizes up to 65.0
```

빌드와 runtime 모두 Java 25로 맞춥니다.

```dockerfile
FROM eclipse-temurin:25-jre-alpine
```

### Actuator probe 500

```text
No static resource actuator/health
```

각 서비스의 runtime JAR에 Actuator가 포함됐는지 확인하고, `SERVER_PORT`, `containerPort`, Service port, probe 포트를 일치시킵니다.

```bash
kubectl logs deployment/blue-bank-loan -n blue-bank --tail=200
kubectl describe pod <POD> -n blue-bank
```

실제 health 응답 확인:

```bash
kubectl port-forward -n blue-bank deployment/blue-bank-account 18100:8100
curl -i http://127.0.0.1:18100/actuator/health
```

로컬 포트가 이미 사용 중이면 `18100:8100`처럼 왼쪽 포트만 변경합니다. `bind: address already in use`는 NKS 포트 오류가 아니라 로컬 포트 충돌입니다.

### ConfigMap 변경이 Pod에 반영되지 않음

```bash
kubectl rollout restart deployment/blue-bank-gateway -n blue-bank
kubectl exec -n blue-bank deployment/blue-bank-gateway -- printenv | grep SERVICES_
```

ConfigMap과 Pod 환경변수를 각각 비교합니다.

```bash
kubectl get configmap blue-bank-gateway-config -n blue-bank -o yaml
kubectl exec -n blue-bank deployment/blue-bank-gateway -- printenv | grep SERVICES_
```

### Rate Limit이 1로 동작

응답 헤더 확인:

```bash
curl -i "http://${LB_HOST}/api/accounts"
```

Java Bean과 profile 설정이 서로 덮어쓰지 않는지 확인합니다. 최종 값이 초당 100이면 다음 헤더가 나와야 합니다.

```text
x-ratelimit-burst-capacity: 100
x-ratelimit-replenish-rate: 100
```

부하 테스트:

```bash
for i in {1..120}; do
  curl -sS -o /dev/null -w "%{http_code}\n" \
    "http://${LB_HOST}/api/accounts" &
done
wait
```

Rate Limit 응답 코드 집계:

```bash
for i in {1..120}; do
  curl -sS -o /dev/null -w "%{http_code}\n" \
    "http://${LB_HOST}/api/accounts"
done | sort | uniq -c
```

`LB_HOST`가 비어 있거나 프롬프트 문자가 섞였는지 확인합니다.

```bash
printf '<%s>\n' "$LB_HOST"
kubectl get svc -n envoy-gateway-system -o wide
```

`<>`가 출력되면 변수 값이 비어 있는 것입니다.

```bash
export LB_HOST="<EXTERNAL_LB_HOSTNAME>"
```

### 로컬 클러스터를 조회함

```bash
kubectl config current-context
kubectl get pods -n blue-bank -o wide
```

`10.244.x.x`이면 로컬일 가능성이 높고, NKS context는 이 환경에서 `198.18.x.x` Pod IP가 보입니다.

현재 NKS context를 명시해 실행하는 방법:

```bash
kubectl --context nks_kr_<cluster>_<uuid> get pods -n blue-bank
```

## 16. 전체 상태 점검 명령 모음

```bash
# 인증/context
kubectl config current-context
kubectl get nodes -o wide

# Argo CD
kubectl get applications -n argocd
kubectl get application blue-bank-gateway-dev -n argocd \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'

# Workload
kubectl get pods -n blue-bank -o wide
kubectl get deployment -n blue-bank
kubectl get svc -n blue-bank
kubectl get endpointslices -n blue-bank

# Gateway/Envoy
kubectl get gateway -n blue-bank
kubectl get httproute -n blue-bank
kubectl get svc -n envoy-gateway-system -o wide

# 이벤트/로그
kubectl get events -n blue-bank --sort-by='.lastTimestamp' | tail -40
kubectl logs deployment/blue-bank-gateway -n blue-bank --tail=200

# Kustomize
kubectl kustomize k8s/overlays/dev | grep -E 'image:|kind: (Deployment|Service)'
```

## 14. Grafana 모니터링

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
kubectl get pods -n monitoring
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```

Grafana가 `Running/Ready`가 된 후 브라우저에서 `http://localhost:3000/login`으로 접속합니다.

```bash
kubectl get secret kube-prometheus-stack-grafana -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Gateway의 `/actuator/prometheus`를 Prometheus가 수집하도록 ServiceMonitor 또는 scrape annotation이 필요합니다. 429 요청 수 예시:

```promql
sum(rate(http_server_requests_seconds_count{status="429"}[1m]))
```

## 15. 운영 전 체크리스트

- [ ] NKS context 확인
- [ ] NKS Endpoint IP ACL 확인
- [ ] Worker Node 3개 이상
- [ ] NCR Secret과 Gateway Secret 생성
- [ ] 모든 업무 Pod `1/1 Running`
- [ ] EndpointSlice에 Pod endpoint 존재
- [ ] Envoy Gateway LoadBalancer hostname 확인
- [ ] HTTPRoute와 Gateway 상태 확인
- [ ] Gateway ConfigMap Service DNS 확인
- [ ] Gateway rollout 성공
- [ ] 외부 `/api/accounts` 호출 성공
- [ ] SHA 이미지 태그 및 Argo revision 확인
- [ ] 운영 release branch 보호와 PR 승인 설정
