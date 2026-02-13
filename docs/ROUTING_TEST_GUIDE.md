# 🧪 API Gateway 라우팅 테스트 가이드

## 📋 목차
1. [테스트 환경 확인](#1-테스트-환경-확인)
2. [기본 라우팅 테스트](#2-기본-라우팅-테스트)
3. [Fallback 테스트](#3-fallback-테스트)
4. [Rate Limiting 테스트](#4-rate-limiting-테스트)
5. [Gateway 필터 확인](#5-gateway-필터-확인)
6. [전체 플로우 테스트](#6-전체-플로우-테스트)

---

## 1. 테스트 환경 확인

### 컨테이너 상태 확인
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**예상 결과:**
```
NAMES             STATUS                    PORTS
api-nginx         Up (healthy)              0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
spring-gateway    Up (healthy)              8080/tcp
gateway-redis     Up (healthy)              6379/tcp
```

### Health Check
```bash
# Gateway 직접 호출
docker exec spring-gateway wget -qO- http://localhost:8080/actuator/health

# Nginx를 통한 호출
curl http://localhost/actuator/health
```

**예상 응답:**
```json
{
  "status": "UP",
  "groups": ["liveness", "readiness"]
}
```

---

## 2. 기본 라우팅 테스트

### 설정된 라우트

| 경로 | 대상 서비스 | 필터 |
|------|------------|------|
| `/search/**` | `http://search-service:8081` | StripPrefix(1), CircuitBreaker |
| `/payment/**` | `http://payment-service:8082` | StripPrefix(1), CircuitBreaker |

### StripPrefix 동작 방식

- **요청:** `GET /search/api/users`
- **라우팅 후:** `GET http://search-service:8081/api/users` (첫 번째 경로 제거)

### 테스트 명령어

#### A. Gateway 직접 호출 (컨테이너 내부)

```bash
# Search Service
docker exec spring-gateway wget -S -O- http://localhost:8080/search/api/test 2>&1

# Payment Service
docker exec spring-gateway wget -S -O- http://localhost:8080/payment/api/test 2>&1
```

#### B. Nginx를 통한 호출 (외부)

```bash
# Search Service
curl -v http://localhost/search/api/test

# Payment Service
curl -v http://localhost/payment/api/test
```

### 예상 결과

**Backend 서비스가 실행 중이 아닐 경우:**
- HTTP 503 Service Unavailable
- Circuit Breaker가 작동하여 Fallback으로 전달

**Backend 서비스가 실행 중일 경우:**
- HTTP 200 OK
- Backend 서비스의 응답 반환

---

## 3. Fallback 테스트

Circuit Breaker가 Backend 서비스 장애를 감지하면 Fallback 엔드포인트로 전달합니다.

### Fallback 엔드포인트 직접 호출

```bash
# Search Fallback
curl http://localhost/fallback/search

# Payment Fallback
curl http://localhost/fallback/payment
```

**예상 응답:**
```
Search Service Unavailable
```
```
Payment Service Unavailable
```

### Fallback 트리거 조건

Circuit Breaker 설정 (`application.yml`):
- **slowCallDurationThreshold:** 2초 이상 응답 시간
- **slowCallRateThreshold:** 느린 호출 50% 이상
- **failureRateThreshold:** 실패율 50% 이상
- **waitDurationInOpenState:** Circuit Open 시 10초 대기

---

## 4. Rate Limiting 테스트

### 설정값
```yaml
redis-rate-limiter:
  replenishRate: 100        # 초당 100개 요청 허용
  burstCapacity: 200        # 최대 200개 버스트
```

### 대량 요청 테스트

```bash
# 연속 250회 요청 (Rate Limit 초과)
for i in {1..250}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost/actuator/health
  sleep 0.01
done | sort | uniq -c
```

**예상 결과:**
```
    200 200
     50 429    # Too Many Requests
```

### Rate Limit 초과 시 응답

**HTTP 429 Too Many Requests**
```json
{
  "code": "RATE_LIMIT_EXCEEDED",
  "message": "요청이 너무 많습니다. 잠시 후 다시 시도해주세요"
}
```

### Redis에서 Rate Limit 데이터 확인

```bash
# Redis 컨테이너 접속
docker exec -it gateway-redis redis-cli

# Rate Limit 키 확인
KEYS request_rate_limiter.*

# 특정 IP의 현재 토큰 수 확인
GET request_rate_limiter.{IP주소}.tokens
```

---

## 5. Gateway 필터 확인

### Default Filters

모든 요청에 자동으로 추가되는 헤더:

```yaml
default-filters:
  - AddRequestHeader=X-Gateway, spring-gateway
  - AddResponseHeader=X-Gateway-Version, v1
```

### 헤더 확인

```bash
curl -v http://localhost/actuator/health 2>&1 | grep -i "x-gateway"
```

**예상 출력:**
```
< X-Gateway-Version: v1
```

### Global Filters 실행 순서

| 필터 | 순서 | 기능 |
|------|------|------|
| `JwtAuthFilter` | -200 | JWT 검증 및 인증 |
| `AuthorizationFilter` | -100 | 역할/권한 검증 |
| `RateLimitExceededFilter` | -90 | Rate Limit 초과 처리 |
| `AccessLogFilter` | LOWEST | 요청/응답 로깅 |

---

## 6. 전체 플로우 테스트

### 시나리오 1: 정상 요청 흐름

```bash
# 1. JWT 토큰 생성 (실제 환경에서는 인증 서버에서 발급)
# 테스트용으로는 JWT 필터가 비활성화되어 있다고 가정

# 2. Search API 호출
curl -X GET http://localhost/search/api/products \
  -H "Content-Type: application/json"

# 3. Payment API 호출
curl -X POST http://localhost/payment/api/orders \
  -H "Content-Type: application/json" \
  -d '{"amount": 10000, "currency": "KRW"}'
```

### 시나리오 2: Backend 장애 상황

```bash
# 1. Backend 서비스 중지 (시뮬레이션)
# search-service와 payment-service가 중지된 상태

# 2. 요청 시도
curl -v http://localhost/search/api/test

# 3. 예상: Circuit Breaker → Fallback 응답
```

### 시나리오 3: Rate Limit 도달

```bash
# 1. 짧은 시간에 대량 요청
for i in {1..300}; do
  curl -s http://localhost/actuator/health > /dev/null
done

# 2. Rate Limit 초과 응답 확인
curl -v http://localhost/actuator/health

# 3. 예상: HTTP 429 Too Many Requests
```

---

## 🔍 디버깅 및 로그 확인

### Gateway 로그 실시간 모니터링

```bash
docker logs -f spring-gateway
```

### 특정 요청 추적

AccessLogFilter가 모든 요청을 다음 형식으로 로깅합니다:

```
[ACCESS] GET /search/api/test - 172.18.0.1 - 503 - 1234ms
```

### Nginx 로그 확인

```bash
# Access Log
docker exec api-nginx tail -f /var/log/nginx/access.log

# Error Log
docker exec api-nginx tail -f /var/log/nginx/error.log
```

### Redis 연결 확인

```bash
# Gateway에서 Redis 연결 테스트
docker exec spring-gateway env | grep REDIS

# Redis Ping 테스트
docker exec gateway-redis redis-cli ping
```

---

## 📊 Metrics 확인

### Actuator Metrics 엔드포인트

```bash
# 사용 가능한 모든 메트릭
curl http://localhost/actuator/metrics

# Gateway 라우팅 메트릭
curl http://localhost/actuator/metrics/gateway.requests

# JVM 메모리 메트릭
curl http://localhost/actuator/metrics/jvm.memory.used
```

---

## ✅ 테스트 자동화 스크립트

프로젝트 루트에 `test-routing.sh` 스크립트가 제공됩니다:

```bash
# 실행 권한 부여
chmod +x test-routing.sh

# 전체 테스트 실행
./test-routing.sh
```

---

## 🚨 문제 해결

### 라우팅이 작동하지 않을 때

1. **라우트 설정 확인**
   ```bash
   docker exec spring-gateway cat /app/BOOT-INF/classes/application.yml
   ```

2. **환경 변수 확인**
   ```bash
   docker exec spring-gateway env | grep SERVICE_URL
   ```

3. **컨테이너 재시작**
   ```bash
   docker-compose restart gateway
   ```

4. **완전한 재빌드**
   ```bash
   docker-compose down -v
   docker-compose build --no-cache gateway
   docker-compose up -d
   ```

### Rate Limiting이 작동하지 않을 때

1. **Redis 연결 확인**
   ```bash
   docker logs spring-gateway | grep -i redis
   ```

2. **Redis 키 확인**
   ```bash
   docker exec gateway-redis redis-cli KEYS "*"
   ```

### Fallback이 작동하지 않을 때

1. **Circuit Breaker 로그 확인**
   ```bash
   docker logs spring-gateway | grep -i "circuit"
   ```

2. **Fallback Controller 확인**
   ```bash
   curl http://localhost/fallback/search
   ```

---

## 📚 참고 자료

- [Spring Cloud Gateway 공식 문서](https://docs.spring.io/spring-cloud-gateway/reference/)
- [Circuit Breaker Pattern](https://resilience4j.readme.io/docs/circuitbreaker)
- [Redis Rate Limiter](https://docs.spring.io/spring-cloud-gateway/reference/spring-cloud-gateway/gatewayfilter-factories/requestratelimiter-factory.html)