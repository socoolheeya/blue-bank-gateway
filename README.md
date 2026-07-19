# Blue Bank Gateway

Spring Cloud Gateway for Blue Bank Microservices Architecture

## 🏗️ Project Structure

```
blue-bank-gateway/
├── src/                      # Source code
├── build/                    # Build outputs
├── docker/                   # Docker configurations
├── infra/                    # NCP VPC/NKS Terraform 및 부트스트랩
├── k8s/                      # Kubernetes Base/Dev/Prod manifests
├── argocd/                   # Argo CD Application 선언
├── docs/                     # 설계·배포·운영 문서
├── service-configs/          # Compose 전환용 서비스 설정
├── test-utils/               # 테스트 보조 도구
├── scripts/                  # Management scripts
│   ├── service-manager.sh           # 🔧 메인 서비스 관리 도구
│   ├── restart-services-multi-instance.sh  # 🔄 전체 서비스 재시작
│   ├── scale-all.sh                 # 📈 동시 스케일링
│   ├── monitor.sh                   # 📊 실시간 모니터링
│   ├── quick-test.sh                # 🧪 빠른 테스트
│   ├── deploy-dev.sh                # 🚀 개발 서버 Gateway 배포
│   └── test-load-balancing.sh       # 🔍 로드 밸런싱 확인
├── docker-compose.yml        # 공통 Gateway/Redis 스택
├── docker-compose.local.yml  # 로컬 전환 구성
├── docker-compose.dev.yml    # 개발 전환 구성
├── docker-compose.prod.yml   # 운영 전환 구성
├── docker-compose-services.yml  # Business services
└── README.md
```

## 🚀 Quick Start

> Kubernetes 애플리케이션 배포는 [Kubernetes 배포](docs/KUBERNETES_DEPLOYMENT.md), NCP 인프라 생성은 [NCP NKS Terraform 인프라 생성 및 배포](docs/NCP_TERRAFORM_DEPLOYMENT.md)를 참고합니다. Docker Compose는 로컬 및 전환 배포용으로 유지합니다.

### 로컬 환경

로컬에서는 Gateway와 Redis를 실행합니다. 업무 서비스 주소는 `SERVICES_*_URL` 환경변수로 덮어쓸 수 있습니다.

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.local.yml \
  up --build -d

docker compose \
  -f docker-compose.yml \
  -f docker-compose.local.yml \
  down
```

### 개발 Compose 전환 배포

NKS 개발 배포는 [NCP NKS Terraform 배포 가이드](docs/NCP_TERRAFORM_DEPLOYMENT.md)를 사용합니다. Compose를 임시로 사용할 때만 프로젝트 루트에 `.env.dev`를 생성합니다.

```dotenv
JWT_SECRET=replace-with-a-secret-at-least-256-bits-long
REDIS_PASSWORD=replace-with-the-development-redis-password
```

배포 스크립트를 실행합니다.

```bash
cd /opt/blue-bank-gateway
./scripts/deploy-dev.sh
```

스크립트는 다음 Compose 명령과 동일합니다.

```bash
docker compose --env-file .env.dev \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  up --build -d
```

다른 위치의 환경 파일을 사용하려면 `ENV_FILE`을 지정합니다.

```bash
ENV_FILE=/secure/config/gateway.env ./scripts/deploy-dev.sh
```

배포 상태와 로그는 다음과 같이 확인합니다.

```bash
docker compose --env-file .env.dev \
  -f docker-compose.yml -f docker-compose.dev.yml ps

docker compose --env-file .env.dev \
  -f docker-compose.yml -f docker-compose.dev.yml logs -f gateway
```

### 운영 Compose 전환 배포

운영 Kubernetes 전환 중 Compose를 사용할 때만 `.env.prod`에 비밀값을 설정합니다.

```dotenv
JWT_SECRET=replace-with-a-production-secret-at-least-256-bits-long
REDIS_PASSWORD=replace-with-the-production-redis-password
```

```bash
docker compose --env-file .env.prod \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  up --build -d
```

Kubernetes 배포에서는 Eureka 대신 `account`, `deposit`, `loan`, `card` Service DNS를 사용합니다.

### Blue Bank 비즈니스 서비스 시작

```bash
# 기본 설정으로 모든 서비스 시작 (Account:3, Deposit:5, Loan:6, Card:7)
./scripts/restart-services-multi-instance.sh

# 빠른 시작 (30초 대기)
./scripts/restart-services-multi-instance.sh --fast

# 이미지 빌드 후 시작
./scripts/restart-services-multi-instance.sh --build
```

## 📡 Service Endpoints & Port Ranges

| Service | Gateway Route | Port Range | Default Instances |
|---------|--------------|------------|-------------------|
| Gateway | - | 8080 | 1 |
| Envoy Gateway | - | 80 | 1 |
| Account | /api/accounts | 8100-8199 | 3 |
| Deposit | /api/deposits | 8200-8299 | 5 |
| Loan | /api/loans | 8300-8399 | 6 |
| Card | /api/cards | 8400-8499 | 7 |

## 🛠️ 스크립트 활용 운영 가이드

### 1. service-manager.sh - 통합 서비스 관리

#### 기본 명령어
```bash
# 서비스 상태 확인
./scripts/service-manager.sh status

# 특정 서비스 N개 시작
./scripts/service-manager.sh start [service] [count]

# 특정 서비스 N개 중지
./scripts/service-manager.sh stop [service] [count]

# 특정 서비스를 정확히 N개로 조정
./scripts/service-manager.sh scale [service] [count]

# 서비스 재시작
./scripts/service-manager.sh restart [service] [count]

# 모든 서비스 시작 (각 서비스별 N개)
./scripts/service-manager.sh start-all [count]

# 모든 서비스 중지
./scripts/service-manager.sh stop-all

# 서비스 이미지 빌드
./scripts/service-manager.sh build
```

#### 실제 사용 예시
```bash
# Account 서비스 5개 인스턴스 시작
./scripts/service-manager.sh start account 5

# Deposit 서비스를 정확히 10개로 스케일링
./scripts/service-manager.sh scale deposit 10

# Loan 서비스 3개 인스턴스 중지
./scripts/service-manager.sh stop loan 3

# 전체 상태 확인
./scripts/service-manager.sh status
```

### 2. restart-services-multi-instance.sh - 전체 서비스 재시작

#### 기본 사용법
```bash
# 기본 인스턴스 수로 재시작
./scripts/restart-services-multi-instance.sh

# 환경 변수로 인스턴스 수 조정
ACCOUNT_INSTANCES=5 DEPOSIT_INSTANCES=10 ./scripts/restart-services-multi-instance.sh

# 옵션 사용
./scripts/restart-services-multi-instance.sh --build    # 이미지 재빌드
./scripts/restart-services-multi-instance.sh --fast     # 30초 대기
./scripts/restart-services-multi-instance.sh --no-wait  # 대기 없음
```

#### 기본 인스턴스 설정
- Account: 3개
- Deposit: 5개
- Loan: 6개
- Card: 7개

### 3. 모니터링 및 테스트 스크립트

#### monitor.sh - 실시간 모니터링
```bash
# 5초마다 자동 새로고침되는 모니터링 시작
./scripts/monitor.sh
```
- Docker 컨테이너 상태
- Eureka 등록 상태
- 메모리 사용량
- Ctrl+C로 종료

#### quick-test.sh - 빠른 테스트
```bash
# 모든 서비스 엔드포인트 테스트
./scripts/quick-test.sh
```
- 각 서비스 10회 요청
- 응답 시간 측정
- HTTP 상태 코드 확인
- 로드 밸런싱 검증

#### test-load-balancing.sh - 로드 밸런싱 상세 확인
```bash
# Deposit 서비스에 20개 요청 보내기
./scripts/test-load-balancing.sh /api/deposits 20

# Account 서비스 테스트
./scripts/test-load-balancing.sh /api/accounts 30
```

### 4. 운영 시나리오별 가이드

#### 📌 시나리오 1: 초기 시작
```bash
# 1. 로컬 인프라 스택 시작
docker compose \
  -f docker-compose.yml \
  -f docker-compose.local.yml \
  up --build -d

# 2. 30초 대기
sleep 30

# 3. Blue Bank 서비스 시작
./scripts/restart-services-multi-instance.sh

# 4. 상태 확인
./scripts/service-manager.sh status
```

#### 📌 시나리오 2: 특정 서비스만 스케일링
```bash
# Loan 서비스가 1개만 실행 중일 때 6개로 늘리기
./scripts/service-manager.sh scale loan 6

# Card 서비스가 1개만 실행 중일 때 7개로 늘리기
./scripts/service-manager.sh scale card 7
```

#### 📌 시나리오 3: 부분 재시작
```bash
# Account 서비스만 재시작 (현재 실행 중인 개수 유지)
./scripts/service-manager.sh restart account

# Deposit 서비스를 5개로 재시작
./scripts/service-manager.sh restart deposit 5
```

#### 📌 시나리오 4: 장애 대응
```bash
# 1. 현재 상태 확인
./scripts/service-manager.sh status

# 2. 문제 있는 서비스만 재시작
./scripts/service-manager.sh restart loan

# 3. 모니터링
./scripts/monitor.sh
```

#### 📌 시나리오 5: 성능 테스트
```bash
# 1. 모든 서비스를 최대로 스케일
./scripts/scale-all.sh 10

# 2. 로드 밸런싱 확인
./scripts/test-load-balancing.sh /api/deposits 100

# 3. 실시간 모니터링
./scripts/monitor.sh
```

## 🔄 로드 밸런싱 확인

### Spring Cloud LoadBalancer (Round Robin)
```bash
# 로드 밸런싱 테스트 (인스턴스 정보 포함)
./scripts/test-lb-with-info.sh

# 출력 예시:
# Request  1 -> Port: 8205
# Request  2 -> Port: 8200
# Request  3 -> Port: 8205
# Request  4 -> Port: 8200
# ...
# Port 8200: 10 requests (50.0%)
# Port 8205: 10 requests (50.0%)
```

## 🔧 Configuration

### Gateway Routes (RouteConfiguration.kt)
```kotlin
- lb://ACCOUNT → Account Service (Load Balanced)
- lb://DEPOSIT → Deposit Service (Load Balanced)
- lb://LOAN → Loan Service (Load Balanced)
- lb://CARD → Card Service (Load Balanced)
```

### Environment Variables

로컬 Compose는 별도 Eureka 환경변수가 필요하지 않습니다. 개발 및 운영 서버는 각각 `.env.dev`, `.env.prod`를 사용합니다.

```env
REDIS_PASSWORD=yourpassword
JWT_SECRET=your-secret-key-must-be-at-least-256-bits
```

### 프로파일별 설정
- `application.yml` - 공통 설정
- `application-local.yml` - 로컬 개발 (DEBUG 로그)
- `application-dev.yml` - 개발 서버
- `application-staging.yml` - 스테이징 환경
- `application-prod.yml` - 프로덕션 환경

## 📊 모니터링 URL

| 대시보드 | URL | 설명 |
|---------|-----|------|
| Eureka Dashboard | http://localhost:8761 | 서비스 등록 상태 |
| Gateway Health | http://localhost:8080/actuator/health | Gateway 상태 |
| Gateway Routes | http://localhost:8080/actuator/gateway/routes | 라우트 설정 |
| Gateway Metrics | http://localhost:8080/actuator/metrics | 메트릭 정보 |

## 🧪 API 테스트

### 기본 엔드포인트 테스트
```bash
# Account Service
curl http://localhost:8080/api/accounts

# Deposit Service (인스턴스 정보 포함)
curl http://localhost:8080/api/deposits | jq .

# Loan Service
curl http://localhost:8080/api/loans

# Card Service
curl http://localhost:8080/api/cards
```

### JWT 인증 테스트
```bash
# JWT 토큰 생성 (test-utils 디렉토리)
java -cp . TestJwtGenerator

# 인증 헤더와 함께 요청
curl -H "Authorization: Bearer ${JWT_TOKEN}" http://localhost:8080/api/accounts
```

## 🐳 Docker 관리

### 컨테이너 상태 확인
```bash
# 모든 서비스 컨테이너 확인
docker ps --filter "name=-service-"

# 특정 서비스 로그 확인
docker logs deposit-service-1 -f

# 컨테이너 리소스 사용량
docker stats --no-stream
```

### 네트워크 확인
```bash
# Gateway 네트워크 확인
docker network inspect blue-bank-gateway_gateway-network
```

## 🚨 트러블슈팅

### 1. 서비스가 Eureka에 등록되지 않음
```bash
# Eureka 로그 확인
docker logs eureka-server

# 서비스 재시작
./scripts/service-manager.sh restart [service]
```

### 2. 503 Service Unavailable
```bash
# 서비스 상태 확인
./scripts/service-manager.sh status

# Gateway 라우트 확인
curl http://localhost:8080/actuator/gateway/routes
```

### 3. 로드 밸런싱이 작동하지 않음
```bash
# RouteConfiguration.kt 확인 (lb:// 사용 여부)
# Eureka 등록 상태 확인
curl http://localhost:8761/eureka/apps
```

### 4. 포트 충돌
```bash
# 사용 중인 포트 확인
lsof -i :8100-8499

# 기존 컨테이너 정리
docker ps -a --filter "name=-service-" -q | xargs docker rm -f
```

## 📝 개발 가이드

### 로컬 개발
```bash
# Gateway 실행
SPRING_PROFILES_ACTIVE=local ./gradlew bootRun

# 특정 서비스만 테스트
./scripts/service-manager.sh start account 1
```

### 서비스 이미지 빌드
```bash
# 모든 서비스 빌드
./scripts/service-manager.sh build

# 개별 서비스 빌드
cd /path/to/blue-bank/app/account
./gradlew clean bootJar
docker build -t blue-bank-account-service .
```

## 📚 추가 문서

- [DOCKER-COMPOSE.md](./DOCKER-COMPOSE.md) - Docker Compose 파일 상세 가이드
- [scripts/README.md](./scripts/README.md) - 스크립트 상세 사용법

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.
