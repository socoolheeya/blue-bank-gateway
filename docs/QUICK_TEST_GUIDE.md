# Blue Bank Eureka 통합 빠른 테스트 가이드

## 🚀 빠른 시작 (5분 내)

### 1단계: 전체 시스템 시작
```bash
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway
./start-all-services.sh
```

### 2단계: 서비스 확인 (30초 대기 후)
```bash
# Eureka Dashboard 확인
open http://localhost:8761

# 또는 테스트 스크립트 실행
./test-eureka-integration.sh
```

### 3단계: API 테스트

#### 계좌 생성 (Gateway 통해서)
```bash
curl -X POST http://localhost:8080/api/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": 1,
    "accountType": "CHECKING",
    "currency": "KRW"
  }'
```

#### 예금 상품 조회 (Gateway 통해서)
```bash
curl http://localhost:8080/api/deposits
```

### 4단계: 서비스 중지
```bash
./stop-all-services.sh
```

## 📋 체크리스트

### ✅ Eureka Server (http://localhost:8761)
- [ ] Eureka Dashboard 접속 가능
- [ ] 5개 서비스 모두 등록됨:
  - [ ] API-GATEWAY
  - [ ] ACCOUNT
  - [ ] DEPOSIT
  - [ ] LOAN
  - [ ] CARD

### ✅ Gateway Routes (http://localhost:8080)
- [ ] `/api/accounts/**` → Account Service
- [ ] `/api/deposits/**` → Deposit Service
- [ ] `/api/loans/**` → Loan Service
- [ ] `/api/cards/**` → Card Service

### ✅ 서비스 간 통신
- [ ] Deposit → Account (Feign Client)
- [ ] Loan → Account (Feign Client)
- [ ] Card → Account (Feign Client)

## 🔍 트러블슈팅

### 서비스가 시작되지 않는 경우
```bash
# 로그 확인
tail -f eureka.log
tail -f gateway.log
tail -f account.log

# 포트 충돌 확인
lsof -i :8761  # Eureka
lsof -i :8080  # Gateway
lsof -i :8081  # Account
lsof -i :8082  # Loan
lsof -i :8083  # Card
lsof -i :8084  # Deposit
```

### Eureka에 서비스가 등록되지 않는 경우
```bash
# 서비스 application.yml 확인
cat /Users/wonhee.lee/IdeaProjects/blue-bank/app/{service}/src/main/resources/application.yml

# Eureka 설정 확인:
# - eureka.client.service-url.defaultZone
# - spring.application.name
```

### Gateway 라우팅이 안 되는 경우
```bash
# Gateway 라우트 확인
curl http://localhost:8080/actuator/gateway/routes | python3 -m json.tool

# Eureka 등록 상태 확인
curl http://localhost:8761/eureka/apps | python3 -m json.tool
```

## 📊 모니터링 URLs

| 서비스 | Health Check | Console/Dashboard |
|--------|-------------|-------------------|
| Eureka | http://localhost:8761/actuator/health | http://localhost:8761 |
| Gateway | http://localhost:8080/actuator/health | http://localhost:8080/actuator/gateway/routes |
| Account | http://localhost:8081/actuator/health | http://localhost:8081/h2-console |
| Deposit | http://localhost:8084/actuator/health | http://localhost:8084/h2-console |
| Loan | http://localhost:8082/actuator/health | http://localhost:8082/h2-console |
| Card | http://localhost:8083/actuator/health | http://localhost:8083/h2-console |

## 📝 H2 Console 접속 정보
- **JDBC URL**: `jdbc:h2:mem:{serviceName}db`
  - Account: `jdbc:h2:mem:accountdb`
  - Deposit: `jdbc:h2:mem:depositdb`
  - Loan: `jdbc:h2:mem:loandb`
  - Card: `jdbc:h2:mem:carddb`
- **Username**: sa
- **Password**: (비워둠)

## 🎯 테스트 시나리오

### 시나리오 1: 계좌 생성 후 입금
```bash
# 1. 계좌 생성
curl -X POST http://localhost:8080/api/accounts \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "accountType": "CHECKING", "currency": "KRW"}'

# 2. 입금
curl -X POST http://localhost:8080/api/accounts/1/deposit \
  -H "Content-Type: application/json" \
  -d '{"amount": 100000}'
```

### 시나리오 2: Circuit Breaker 테스트
```bash
# 1. Account Service 중지
kill $(ps aux | grep 'account.*bootRun' | grep -v grep | awk '{print $2}')

# 2. Gateway 통해 요청 (Fallback 응답 확인)
curl http://localhost:8080/api/accounts/1

# 3. Account Service 재시작
cd /Users/wonhee.lee/IdeaProjects/blue-bank/app/account
./gradlew bootRun &
```

## 🛠️ 개발 팁

### IntelliJ IDEA에서 실행
1. 각 서비스의 Application 클래스 실행
2. 실행 순서:
   - EurekaServerApplication
   - BlueBankGatewayApplication
   - AccountApplication
   - DepositApplication
   - LoanApplication
   - CardApplication

### 환경 변수 설정
```bash
export EUREKA_URI=http://localhost:8761/eureka
export FEIGN_ACCOUNT_URL=lb://ACCOUNT
```

### 로그 레벨 조정
application.yml에 추가:
```yaml
logging:
  level:
    com.netflix.eureka: DEBUG
    com.netflix.discovery: DEBUG
    org.springframework.cloud.gateway: DEBUG
```

---

**작성일**: 2024-02-13
**문서 버전**: 1.0