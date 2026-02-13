# Blue Bank API Gateway

Spring Cloud Gateway와 Nginx를 이용한 Blue Bank 서비스용 API Gateway입니다.

## 아키텍처

```
[ 클라이언트 ]
    ↓
[ Nginx (80/443) ]  ← 네트워크 레벨 보호
    ↓
[ Spring Cloud Gateway (8080) ]  ← 비즈니스 정책
    ↓
[ 백엔드 서비스 ]
```

### 계층별 책임

| 계층 | 역할 |
|------|------|
| **Nginx** | TLS 종료, IP 기반 속도 제한, 기본 WAF, 연결 관리, 정적 라우팅 |
| **Spring Cloud Gateway** | JWT 검증, 역할 기반 인가, 경로-서비스 매핑, Circuit Breaker, 감사 로그 |

## 주요 기능

### 보안
- JWT 기반 인증
- 역할 기반 권한 제어 (RBAC)
- 다층 속도 제한 (Nginx + Redis)
- TLS/HTTPS 암호화
- 보안 헤더 (HSTS, X-Frame-Options 등)

### 복원력
- Circuit Breaker 패턴 (Resilience4j)
- Fallback 엔드포인트
- Health Check
- Connection Pooling

### 관찰성
- 분산 추적 (X-Trace-Id)
- 구조화된 접근 로그
- 메트릭 엔드포인트 (Actuator)

## 프로젝트 구조

```
blue-bank-gateway/
├── src/
│   └── main/
│       ├── kotlin/
│       │   └── com/socoolheeya/bluebank/
│       │       ├── service/           # 전역 필터
│       │       │   ├── TraceIdFilter.kt
│       │       │   ├── AuthenticationFilter.kt
│       │       │   ├── AuthorizationFilter.kt
│       │       │   ├── AccessLogFilter.kt
│       │       │   └── RateLimitExceededFilter.kt
│       │       ├── controller/        # Fallback 컨트롤러
│       │       ├── configuration/     # Bean 설정
│       │       └── domain/            # JWT 프로바이더
│       └── resources/
│           └── application.yml        # Gateway 라우팅 및 설정
├── nginx/
│   ├── nginx.conf                     # Nginx 메인 설정
│   ├── conf.d/                        # 추가 설정
│   │   └── security.conf              # 보안 설정
│   └── ssl/                           # TLS 인증서
│       └── .gitkeep
├── redis-entrypoint.sh                # Redis 조건부 비밀번호 스크립트
├── Dockerfile                         # Spring Boot 앱 빌드
├── docker-compose.yml                 # 전체 서비스 구성
├── .env.example                       # 환경변수 템플릿
├── .dockerignore                      # Docker 빌드 제외 파일
└── README.md                          # 이 문서
```

---

## 🚀 빠른 시작 가이드

### 사전 준비사항

설치되어 있어야 할 도구들:
- **JDK 25** - Java 개발 키트
- **Docker Desktop** - 컨테이너 실행 환경
- **Docker Compose** - 멀티 컨테이너 관리 도구

### 방법 1: Docker Compose로 실행하기 (권장)

가장 쉽고 빠른 방법입니다. Docker만 설치되어 있으면 바로 실행할 수 있습니다.

#### 단계 1: SSL 인증서 생성 (개발용)

터미널에서 프로젝트 디렉토리로 이동한 후 아래 명령어를 실행하세요:

```bash
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway

# SSL 인증서 생성 (개발용 - 자가 서명)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/server.key \
  -out nginx/ssl/server.crt \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=BlueBank/CN=localhost"
```

**이 명령어가 하는 일:**
- `nginx/ssl/` 폴더에 SSL 인증서 파일 2개를 생성합니다
- `server.key`: 개인키 파일
- `server.crt`: 인증서 파일
- 유효기간: 365일

#### 단계 2: 환경변수 설정

```bash
# 환경변수 템플릿 복사
cp .env.example .env

# JWT 비밀키 생성 및 설정
export JWT_SECRET=$(openssl rand -base64 32)
echo "JWT_SECRET=${JWT_SECRET}" >> .env
```

**이 명령어가 하는 일:**
- `.env.example` 파일을 `.env`로 복사합니다
- 무작위 32바이트 JWT 비밀키를 생성합니다
- 생성된 키를 `.env` 파일에 저장합니다

**💡 팁:** `.env` 파일은 Git에 커밋하면 안 됩니다! (이미 `.gitignore`에 포함되어 있음)

#### 단계 3: Docker Compose로 실행

```bash
# 빌드하고 백그라운드에서 실행
docker-compose up --build -d
```

**이 명령어가 하는 일:**
- Spring Boot 애플리케이션을 Docker 이미지로 빌드합니다
- Redis, Gateway, Nginx 컨테이너를 순서대로 실행합니다
- `-d` 옵션: 백그라운드에서 실행 (터미널 차지하지 않음)

**실행되는 컨테이너:**
1. `gateway-redis` - Redis 서버 (포트: 6379)
2. `spring-gateway` - Spring Cloud Gateway (포트: 8080)
3. `api-nginx` - Nginx 웹서버 (포트: 80, 443)

#### 단계 4: 실행 확인

```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그 확인 (실시간)
docker-compose logs -f

# 특정 서비스 로그만 보기
docker-compose logs -f gateway
```

#### 단계 5: 접속 테스트

브라우저나 curl로 다음 URL에 접속해보세요:

```bash
# Health Check (HTTP - 정상 작동 확인)
curl http://localhost/health

# HTTPS 접속 (자가 서명 인증서라 경고가 뜰 수 있음)
curl -k https://localhost/health
```

**접속 주소:**
- **HTTP:** http://localhost (자동으로 HTTPS로 리다이렉트됨)
- **HTTPS:** https://localhost
- **Health Check:** http://localhost/health

**브라우저에서 접속 시 주의사항:**
- 자가 서명 인증서를 사용하므로 "안전하지 않음" 경고가 표시됩니다
- 개발 환경에서는 "고급 → 계속 진행" 클릭하여 접속하면 됩니다
- 실제 운영 환경에서는 정식 인증서를 사용해야 합니다

#### 단계 6: 중지 및 삭제

```bash
# 중지만 하기 (데이터 보존)
docker-compose stop

# 중지 후 컨테이너 삭제 (데이터 보존)
docker-compose down

# 컨테이너 + 볼륨(데이터) 모두 삭제
docker-compose down -v
```

---

### 방법 2: 로컬에서 직접 실행하기 (개발용)

Docker 없이 로컬 환경에서 직접 실행하는 방법입니다.

#### 단계 1: Redis 실행

Redis는 Docker로 실행하는 것이 가장 쉽습니다:

```bash
docker run -d --name redis-local -p 6379:6379 redis:7.2-alpine
```

또는 직접 설치한 경우:

```bash
# macOS
brew install redis
redis-server

# Linux
sudo apt-get install redis-server
sudo service redis-server start
```

#### 단계 2: 환경변수 설정

```bash
# JWT 비밀키 설정 (필수!)
export JWT_SECRET="your-secret-key-must-be-at-least-256-bits-long-for-hs256-algorithm"

# Redis 연결 정보
export REDIS_HOST=localhost
export REDIS_PORT=6379

# 백엔드 서비스 URL (실제 서비스가 있다면)
export SEARCH_SERVICE_URL=http://localhost:8081
export PAYMENT_SERVICE_URL=http://localhost:8082
```

**💡 안전한 JWT_SECRET 생성:**
```bash
openssl rand -base64 32
```

#### 단계 3: 애플리케이션 빌드

```bash
# 전체 빌드 (테스트 포함)
./gradlew build

# 테스트 제외하고 빌드 (빠름)
./gradlew build -x test
```

#### 단계 4: 애플리케이션 실행

```bash
# Gradle로 실행
./gradlew bootRun

# 또는 JAR 파일로 실행
java -jar build/libs/blue-bank-gateway-0.0.1-SNAPSHOT.jar
```

#### 단계 5: 접속 확인

```bash
# Health Check
curl http://localhost:8080/actuator/health

# Metrics
curl http://localhost:8080/actuator/metrics
```

**⚠️ 주의:**
- 로컬 실행 시에는 Nginx가 없으므로 8080 포트로 직접 접속합니다
- HTTPS는 사용할 수 없습니다 (Nginx가 TLS 처리를 담당)

---

## ⚙️ 설정 가이드

### 환경변수 설명

`.env` 파일 또는 시스템 환경변수로 설정합니다.

| 변수명 | 설명 | 기본값 | 필수 |
|--------|------|--------|------|
| `JWT_SECRET` | JWT 서명에 사용할 비밀키 (최소 256비트/32자 이상) | - | ✅ |
| `REDIS_HOST` | Redis 서버 주소 | localhost | ⭕ |
| `REDIS_PORT` | Redis 포트 번호 | 6379 | ⭕ |
| `REDIS_PASSWORD` | Redis 비밀번호 (없으면 빈 값) | (없음) | ❌ |
| `SEARCH_SERVICE_URL` | 검색 서비스 백엔드 주소 | http://localhost:8081 | ⭕ |
| `PAYMENT_SERVICE_URL` | 결제 서비스 백엔드 주소 | http://localhost:8082 | ⭕ |
| `SPRING_PROFILES_ACTIVE` | Spring 프로파일 (dev, prod 등) | prod | ⭕ |

**설정 예시 (.env 파일):**

**개발 환경 (비밀번호 없음):**
```bash
JWT_SECRET=abcdefghijklmnopqrstuvwxyz123456
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
# 또는 REDIS_PASSWORD 라인을 아예 작성하지 않아도 됨
SEARCH_SERVICE_URL=http://my-search-service:8081
PAYMENT_SERVICE_URL=http://my-payment-service:8082
```

**운영 환경 (비밀번호 있음):**
```bash
JWT_SECRET=abcdefghijklmnopqrstuvwxyz123456
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=my-super-secret-redis-password-here
SEARCH_SERVICE_URL=http://search-service:8081
PAYMENT_SERVICE_URL=http://payment-service:8082
```

### Redis 비밀번호 설정

이 프로젝트는 **조건부 Redis 비밀번호 설정**을 지원합니다.

**작동 방식:**
- `REDIS_PASSWORD` 환경변수가 **있으면** → Redis가 비밀번호 인증 활성화
- `REDIS_PASSWORD` 환경변수가 **없으면** → Redis가 비밀번호 없이 실행

**개발 환경에서 사용 (비밀번호 없음):**
```bash
# .env 파일
JWT_SECRET=$(openssl rand -base64 32)
REDIS_PASSWORD=

# 실행
docker-compose up -d

# Redis 접속 테스트
docker exec -it gateway-redis redis-cli ping
# 응답: PONG
```

**운영 환경에서 사용 (비밀번호 있음):**
```bash
# 안전한 비밀번호 생성
export REDIS_PASSWORD=$(openssl rand -base64 32)

# .env 파일에 저장
echo "JWT_SECRET=$(openssl rand -base64 32)" > .env
echo "REDIS_PASSWORD=${REDIS_PASSWORD}" >> .env

# 실행
docker-compose up -d

# Redis 접속 테스트 (비밀번호 필요)
docker exec -it gateway-redis redis-cli -a "${REDIS_PASSWORD}" ping
# 응답: PONG

# 비밀번호 없이 접속 시도 (실패해야 정상)
docker exec -it gateway-redis redis-cli ping
# 응답: NOAUTH Authentication required.
```

**내부 구현:**
- `redis-entrypoint.sh` 스크립트가 환경변수를 체크
- Spring Gateway의 `application.yml`에서 자동으로 비밀번호 사용
- Health Check도 자동으로 비밀번호 유무에 따라 작동

**보안 권장사항:**
- ✅ 개발 환경: 비밀번호 없이 사용 가능
- ⚠️ 운영 환경: **반드시** 강력한 비밀번호 설정
- 🔐 비밀번호는 AWS Secrets Manager, HashiCorp Vault 등에 저장 권장

### 필터 실행 순서

요청이 들어오면 다음 순서로 필터가 실행됩니다:

```
1. TraceIdFilter (우선순위: -200)
   → 요청 추적 ID 생성/전파 (X-Trace-Id)

2. AuthenticationFilter (우선순위: -100)
   → JWT 토큰 검증 및 사용자 정보 추출

3. AuthorizationFilter (우선순위: -90)
   → 사용자 권한 확인 (역할 기반)

4. [Spring Gateway 내장 필터들]
   → Rate Limiter, Circuit Breaker 등

5. AccessLogFilter (우선순위: 가장 낮음)
   → 요청/응답 로그 기록
```

### 속도 제한 (Rate Limiting)

#### Nginx 레이어 (IP 기반)
- **일반 엔드포인트:** 초당 100개 요청, 버스트 200개
- **인증 엔드포인트 (/auth):** 초당 10개 요청, 버스트 20개
- **동시 연결:** IP당 최대 10개

**예시:**
- 사용자가 1초에 150개 요청 → 처음 200개까지는 허용 (버스트), 이후 초당 100개로 제한
- 1초에 250개 요청 → 200개 허용, 50개는 429 Too Many Requests 응답

#### Spring Gateway 레이어 (Redis 기반)
- **토큰 충전 속도:** 초당 100개
- **최대 버스트 용량:** 200개 토큰

**동작 방식:**
- 각 사용자는 토큰 버킷을 갖습니다
- 요청마다 토큰 1개 소비
- 토큰이 없으면 429 에러 반환

### Circuit Breaker 설정

백엔드 서비스가 응답하지 않을 때 자동으로 차단하는 기능입니다.

**설정값:**
- **느린 호출 기준:** 2000ms (2초) 이상 걸리면 "느림"으로 간주
- **느린 호출 비율 임계값:** 50% (절반 이상이 느리면 차단)
- **실패율 임계값:** 50% (절반 이상 실패하면 차단)
- **차단 지속 시간:** 10초 (10초 후 자동으로 다시 시도)

**예시:**
1. 검색 서비스가 10번 중 6번 실패 → Circuit Open (차단)
2. 10초간 모든 요청은 즉시 Fallback 응답 반환
3. 10초 후 자동으로 1개 요청만 테스트
4. 성공하면 Circuit Close (정상화), 실패하면 다시 10초 대기

---

## 🛣️ API 라우팅

### 라우팅 규칙

| 경로 | 백엔드 서비스 | Circuit Breaker | Fallback |
|------|--------------|-----------------|----------|
| `/search/**` | SEARCH_SERVICE_URL | ✅ | /fallback/search |
| `/payment/**` | PAYMENT_SERVICE_URL | ✅ | /fallback/payment |
| `/health` | Actuator | ❌ | - |

**예시:**
- 요청: `https://localhost/search/products?q=laptop`
- 전달: `http://search-service:8081/products?q=laptop` (StripPrefix로 /search 제거)

### 인증 제외 경로 (Public Paths)

다음 경로는 JWT 없이 접근 가능합니다:
- `/health` - Health Check
- `/auth/**` - 로그인, 회원가입 등 인증 API

---

## 🧪 테스트 및 빌드

### 빌드 명령어

```bash
# 전체 빌드 (테스트 포함)
./gradlew build

# 테스트 제외하고 빌드
./gradlew build -x test

# 테스트만 실행
./gradlew test

# 코드 스타일 검사 (Kotlin)
./gradlew ktlintCheck

# 코드 스타일 자동 수정
./gradlew ktlintFormat
```

### Docker 이미지 빌드

```bash
# 이미지 빌드
docker build -t blue-bank-gateway:latest .

# 빌드한 이미지로 실행
docker run -p 8080:8080 \
  -e JWT_SECRET=your-secret-key \
  -e REDIS_HOST=host.docker.internal \
  blue-bank-gateway:latest
```

---

## 📊 모니터링

### Health Check 확인

```bash
# Gateway Health Check
curl http://localhost:8080/actuator/health

# Nginx Health Check
curl http://localhost/health

# Redis Health Check
docker exec gateway-redis redis-cli ping
```

**응답 예시:**
```json
{
  "status": "UP",
  "components": {
    "redis": {
      "status": "UP"
    }
  }
}
```

### 메트릭 확인

```bash
# 사용 가능한 메트릭 목록
curl http://localhost:8080/actuator/metrics

# 특정 메트릭 조회 (JVM 메모리)
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# HTTP 요청 카운트
curl http://localhost:8080/actuator/metrics/http.server.requests
```

### 로그 확인

```bash
# Docker Compose 로그 (모든 서비스)
docker-compose logs -f

# Gateway 로그만 보기
docker-compose logs -f gateway

# Nginx 접근 로그
tail -f nginx/logs/access.log

# Nginx 에러 로그
tail -f nginx/logs/error.log
```

**로그 형식 (AccessLogFilter):**
```
traceId=abc123 method=GET path=/search/products status=200 latency=45ms userId=user1 clientIp=192.168.1.1
```

---

## 🐛 문제 해결 (Troubleshooting)

### 1. 빌드 실패: JWT_SECRET 에러

**증상:**
```
PlaceholderResolutionException: Could not resolve placeholder 'jwt.secret'
```

**원인:** JWT_SECRET 환경변수가 설정되지 않았습니다.

**해결:**
```bash
# 비밀키 생성 및 설정
export JWT_SECRET=$(openssl rand -base64 32)

# 또는 .env 파일에 추가
echo "JWT_SECRET=$(openssl rand -base64 32)" >> .env
```

### 2. Redis 연결 거부

**증상:**
```
RedisConnectionException: Unable to connect to Redis
```

**원인:** Redis가 실행되지 않았거나 연결 정보가 잘못되었습니다.

**해결:**
```bash
# Redis 상태 확인
docker-compose ps redis

# Redis 로그 확인
docker-compose logs redis

# Redis Health Check (비밀번호 없는 경우)
docker exec gateway-redis redis-cli ping
# 응답: PONG (정상)

# Redis Health Check (비밀번호 있는 경우)
docker exec gateway-redis redis-cli -a "your-password" ping
# 응답: PONG (정상)

# Redis 재시작
docker-compose restart redis
```

### 2-1. Redis 비밀번호 에러

**증상:**
```
*** FATAL CONFIG FILE ERROR (Redis 7.2.12) ***
Reading the configuration file, at line 3
>>> 'requirepass'
wrong number of arguments
```

**원인:** `REDIS_PASSWORD` 환경변수가 빈 문자열로 설정되어 Redis가 시작에 실패했습니다.

**해결:**

**방법 1: 비밀번호 없이 사용 (개발 환경)**
```bash
# .env 파일에서 REDIS_PASSWORD를 완전히 제거하거나 빈 값으로 설정
# .env
REDIS_PASSWORD=

# 재시작
docker-compose down -v
docker-compose up -d
```

**방법 2: 비밀번호 설정 (운영 환경)**
```bash
# 강력한 비밀번호 생성 및 설정
echo "REDIS_PASSWORD=$(openssl rand -base64 32)" >> .env

# 재시작
docker-compose down -v
docker-compose up -d

# 접속 확인
export REDIS_PASSWORD=$(grep REDIS_PASSWORD .env | cut -d'=' -f2)
docker exec gateway-redis redis-cli -a "${REDIS_PASSWORD}" ping
# 응답: PONG
```

### 3. Nginx SSL 에러

**증상:**
```
nginx: [emerg] cannot load certificate "/etc/nginx/ssl/server.crt"
```

**원인:** SSL 인증서 파일이 없습니다.

**해결:**
```bash
# 인증서 생성 (빠른 시작 가이드 참고)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/server.key \
  -out nginx/ssl/server.crt \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=BlueBank/CN=localhost"

# 파일 존재 확인
ls -l nginx/ssl/
```

**임시 해결 (HTTPS 비활성화):**
`nginx/nginx.conf`에서 HTTPS 서버 블록을 주석 처리

### 4. Circuit Breaker 계속 Open 상태

**증상:** 백엔드 서비스가 정상인데도 Fallback만 응답됨

**원인:** Circuit Breaker가 차단 상태입니다.

**해결:**
```bash
# 백엔드 서비스 상태 확인
curl http://localhost:8081/health  # Search Service
curl http://localhost:8082/health  # Payment Service

# Circuit Breaker 임계값 조정
# src/main/resources/application.yml 편집
# failureRateThreshold: 50 → 70 (실패율 70%까지 허용)
# slowCallDurationThreshold: 2000 → 5000 (5초까지 느린 호출 허용)

# 재시작
docker-compose restart gateway
```

### 5. 포트 충돌

**증상:**
```
Error starting userland proxy: listen tcp 0.0.0.0:80: bind: address already in use
```

**원인:** 80, 443, 6379 포트가 이미 사용 중입니다.

**해결:**
```bash
# 사용 중인 프로세스 확인 (macOS/Linux)
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :6379

# 프로세스 종료
sudo kill -9 <PID>

# 또는 docker-compose.yml에서 포트 변경
# ports:
#   - "8000:80"    # 80 → 8000으로 변경
#   - "8443:443"   # 443 → 8443으로 변경
```

### 6. 컨테이너가 계속 재시작됨

**증상:**
```bash
docker-compose ps
# STATUS: Restarting (1) 10 seconds ago
```

**원인:** 애플리케이션 시작 실패 또는 Health Check 실패

**해결:**
```bash
# 로그 확인
docker-compose logs gateway

# Health Check 비활성화하고 직접 확인
docker-compose up gateway
# (Ctrl+C로 중지 가능)

# 의존성 문제일 수 있으므로 순서대로 실행
docker-compose up redis
docker-compose up gateway
docker-compose up nginx
```

### 7. Docker 이미지 빌드 실패

**증상:**
```
failed to solve: gradle:8.11-jdk25: not found
```

**원인:** Dockerfile에서 지정한 Gradle/JDK 이미지가 Docker Hub에 존재하지 않습니다.

**해결:**
```bash
# Dockerfile을 열어서 이미지 버전 확인
cat Dockerfile | grep FROM

# 사용 가능한 이미지로 변경
# Dockerfile 2번째 줄을 다음 중 하나로 수정:
FROM gradle:9.3.1-jdk25 AS builder    # 현재 프로젝트 Gradle 버전
FROM gradle:8.11-jdk21 AS builder     # 안정적인 조합
FROM gradle:latest-jdk21 AS builder   # 최신 Gradle + JDK 21

# 다시 빌드
docker-compose build --no-cache gateway
docker-compose up -d
```

### 8. Docker Compose version 경고

**증상:**
```
WARN: the attribute `version` is obsolete
```

**원인:** Docker Compose 최신 버전에서는 `version` 필드가 더 이상 필요하지 않습니다.

**해결:**
- 이미 수정되어 있습니다 (최신 버전에는 `version` 필드 없음)
- 경고일 뿐이므로 무시해도 됩니다

---

## 🔧 개발 가이드

### 새로운 라우트 추가하기

#### 1단계: application.yml 수정

`src/main/resources/application.yml`에 라우트 추가:

```yaml
routes:
  # 기존 라우트들...

  # 새로운 서비스 추가
  - id: account-service
    uri: ${ACCOUNT_SERVICE_URL:http://localhost:8083}
    predicates:
      - Path=/account/**
    filters:
      - StripPrefix=1
      - name: CircuitBreaker
        args:
          name: accountCB
          fallbackUri: forward:/fallback/account
          slowCallDurationThreshold: 2000
          slowCallRateThreshold: 50
          failureRateThreshold: 50
          waitDurationInOpenState: 10000
```

**설명:**
- `id`: 라우트 식별자 (고유해야 함)
- `uri`: 백엔드 서비스 주소 (환경변수로 설정 가능)
- `predicates`: 매칭 조건 (Path로 URL 패턴 지정)
- `filters`: 적용할 필터들
  - `StripPrefix=1`: URL에서 첫 번째 경로 제거 (/account/users → /users)

#### 2단계: Fallback 엔드포인트 추가

`src/main/kotlin/com/socoolheeya/bluebank/controller/FallbackController.kt` 수정:

```kotlin
@GetMapping("/fallback/account")
fun accountFallback(): Mono<ResponseEntity<Map<String, String>>> {
    return Mono.just(
        ResponseEntity
            .status(HttpStatus.SERVICE_UNAVAILABLE)
            .body(mapOf(
                "code" to "SERVICE_UNAVAILABLE",
                "message" to "Account service is temporarily unavailable."
            ))
    )
}
```

#### 3단계: 환경변수 추가

`.env` 파일에 추가:
```bash
ACCOUNT_SERVICE_URL=http://account-service:8083
```

`docker-compose.yml`에 추가:
```yaml
gateway:
  environment:
    ACCOUNT_SERVICE_URL: ${ACCOUNT_SERVICE_URL:-http://account-service:8083}
```

#### 4단계: 재시작

```bash
docker-compose restart gateway
```

### 인가 규칙 추가하기

특정 경로에 역할 기반 권한 체크를 추가하려면:

`src/main/kotlin/com/socoolheeya/bluebank/service/AuthorizationFilter.kt` 수정:

```kotlin
override fun filter(exchange: ServerWebExchange, chain: GatewayFilterChain): Mono<Void> {
    val role = exchange.request.headers.getFirst("X-User-Role")
    val path = exchange.request.path.value()

    // 기존 규칙
    if (path.startsWith("/api/v1/accounts") && role != "admin") {
        exchange.response.statusCode = HttpStatus.FORBIDDEN
        return exchange.response.setComplete()
    }

    // 새로운 규칙 추가
    if (path.startsWith("/payment/withdraw") && role != "premium") {
        exchange.response.statusCode = HttpStatus.FORBIDDEN
        return exchange.response.setComplete()
    }

    return chain.filter(exchange)
}
```

**더 나은 방법:** 설정 파일로 관리

`application.yml`에 추가:
```yaml
authorization:
  rules:
    - path: /admin/**
      requiredRole: admin
    - path: /payment/withdraw
      requiredRole: premium
```

---

## 🚀 운영 환경 배포 체크리스트

### 보안

- [ ] **정식 TLS 인증서 사용** (Let's Encrypt 등)
  ```bash
  # Certbot으로 무료 인증서 발급
  certbot certonly --standalone -d yourdomain.com
  ```

- [ ] **JWT_SECRET을 Vault에 저장**
  - AWS Secrets Manager
  - HashiCorp Vault
  - Azure Key Vault

- [ ] **Redis 비밀번호 설정**
  ```bash
  # .env 파일에 강력한 비밀번호 설정
  echo "REDIS_PASSWORD=$(openssl rand -base64 32)" >> .env

  # 프로젝트는 이미 조건부 비밀번호 설정을 지원합니다
  # REDIS_PASSWORD 환경변수만 설정하면 자동으로 활성화됩니다
  ```

- [ ] **방화벽 규칙 설정**
  - 필요한 포트만 열기 (80, 443)
  - SSH 포트 변경
  - Fail2ban 설치

### 모니터링

- [ ] **로그 수집 시스템 구축**
  - ELK Stack (Elasticsearch, Logstash, Kibana)
  - Grafana Loki
  - CloudWatch Logs

- [ ] **메트릭 모니터링**
  - Prometheus + Grafana
  - Datadog
  - New Relic

- [ ] **알림 설정**
  - Circuit Breaker Open
  - Health Check 실패
  - 높은 에러율

### 성능

- [ ] **Rate Limit 조정**
  - 실제 트래픽 패턴 분석 후 적정값 설정

- [ ] **Connection Pool 튜닝**
  ```yaml
  # application.yml
  spring:
    cloud:
      gateway:
        httpclient:
          pool:
            max-connections: 1000  # 트래픽에 맞게 조정
  ```

- [ ] **CORS 설정** (필요 시)
  ```yaml
  spring:
    cloud:
      gateway:
        globalcors:
          corsConfigurations:
            '[/**]':
              allowedOrigins: "https://yourdomain.com"
              allowedMethods: "*"
  ```

### 고가용성

- [ ] **다중 인스턴스 구성** (최소 2개 이상)
- [ ] **로드 밸런서 앞단에 배치** (ALB, NLB 등)
- [ ] **Redis Cluster/Sentinel 구성**
- [ ] **자동 재시작 정책 확인**
  ```yaml
  restart: unless-stopped  # 이미 설정됨
  ```

---

## 📖 참고 자료

### 공식 문서
- [Spring Cloud Gateway 문서](https://spring.io/projects/spring-cloud-gateway)
- [Nginx 문서](https://nginx.org/en/docs/)
- [Resilience4j 문서](https://resilience4j.readme.io/)

### 유용한 명령어 모음

```bash
# === Docker 관련 ===

# 모든 컨테이너 상태 확인
docker-compose ps

# 특정 서비스만 재시작
docker-compose restart gateway

# 컨테이너 내부 접속
docker exec -it spring-gateway sh

# 리소스 사용량 확인
docker stats

# === 로그 관련 ===

# 최근 100줄만 보기
docker-compose logs --tail=100 gateway

# 특정 시간 이후 로그
docker-compose logs --since 30m gateway

# === Redis 관련 ===

# Redis CLI 접속 (비밀번호 없는 경우)
docker exec -it gateway-redis redis-cli

# Redis CLI 접속 (비밀번호 있는 경우)
export REDIS_PASSWORD=$(grep REDIS_PASSWORD .env | cut -d'=' -f2)
docker exec -it gateway-redis redis-cli -a "${REDIS_PASSWORD}"

# Redis 키 확인
docker exec -it gateway-redis redis-cli KEYS "*"

# Redis 정보 확인
docker exec -it gateway-redis redis-cli INFO server

# Rate Limiter 키 확인 (IP별 토큰 버킷)
docker exec -it gateway-redis redis-cli KEYS "request_rate_limiter*"

# 특정 IP의 Rate Limit 상태 확인
docker exec -it gateway-redis redis-cli GET "request_rate_limiter.192.168.1.1.tokens"

# === Gradle 관련 ===

# 의존성 목록 확인
./gradlew dependencies

# 캐시 정리
./gradlew clean

# 빠른 빌드 (캐시 활용)
./gradlew build --build-cache
```

---

## 📞 지원

문제가 발생하거나 질문이 있으시면:
- 이슈 등록: GitHub Issues
- 개발팀 문의: dev@bluebank.com

---

## 📝 라이선스

(라이선스 정보 추가 필요)
