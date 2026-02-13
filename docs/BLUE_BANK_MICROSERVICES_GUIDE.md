# Blue Bank 마이크로서비스 아키텍처 가이드

## 🏗️ 시스템 아키텍처

```
                            [Client]
                               |
                            [Nginx]
                               |
                        [API Gateway:8080]
                               |
                    [Eureka Server:8761]
                    /     |      |     \
                   /      |      |      \
        [Account:8081] [Deposit:8084] [Loan:8082] [Card:8083]
              |            |             |            |
         [AccountDB]  [DepositDB]   [LoanDB]    [CardDB]
            (H2)         (H2)         (H2)        (H2)
```

## 📦 구성 요소

### 1. Eureka Discovery Server
- **포트**: 8761
- **대시보드**: http://localhost:8761
- **역할**: 서비스 등록 및 디스커버리

### 2. API Gateway
- **포트**: 8080
- **역할**:
  - 라우팅 및 로드 밸런싱
  - Circuit Breaker (Resilience4j)
  - Rate Limiting (Redis)
  - JWT 인증
  - 요청/응답 로깅

### 3. 마이크로서비스

| 서비스 | 포트 | 경로 | 설명 |
|--------|------|------|------|
| Account Service | 8081 | `/api/accounts/**` | 계좌 관리, 잔액 조회, 이체 |
| Deposit Service | 8084 | `/api/deposits/**` | 예금 상품 관리, 이자 계산 |
| Loan Service | 8082 | `/api/loans/**` | 대출 신청, 승인, 상환 관리 |
| Card Service | 8083 | `/api/cards/**` | 카드 발급, 거래 내역, 혜택 관리 |

## 🚀 실행 방법

### 1. 개별 서비스 실행 (로컬 개발)

```bash
# 1. Eureka Server 실행
cd /Users/wonhee.lee/IdeaProjects/blue-bank-eureka-server
./gradlew bootRun

# 2. Gateway 실행
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway
./gradlew bootRun

# 3. Account Service 실행
cd /Users/wonhee.lee/IdeaProjects/blue-bank/app/account
./gradlew bootRun

# 4. Deposit Service 실행
cd /Users/wonhee.lee/IdeaProjects/blue-bank/app/deposit
./gradlew bootRun

# 5. Loan Service 실행
cd /Users/wonhee.lee/IdeaProjects/blue-bank/app/loan
./gradlew bootRun

# 6. Card Service 실행
cd /Users/wonhee.lee/IdeaProjects/blue-bank/app/card
./gradlew bootRun
```

### 2. Docker Compose 실행 (전체 시스템)

```bash
# 빌드 스크립트 실행
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway
./build-all-services.sh

# Docker Compose 실행
docker-compose -f docker-compose-complete.yml up -d

# 로그 확인
docker-compose -f docker-compose-complete.yml logs -f

# 종료
docker-compose -f docker-compose-complete.yml down
```

## 📋 API 엔드포인트

### Account Service (`/api/accounts`)
```bash
# 계좌 생성
POST /api/accounts
{
  "customerId": 1,
  "accountType": "CHECKING",
  "currency": "KRW"
}

# 계좌 조회
GET /api/accounts/{accountId}

# 잔액 조회
GET /api/accounts/{accountId}/balance

# 입금
POST /api/accounts/{accountId}/deposit
{
  "amount": 10000
}

# 출금
POST /api/accounts/{accountId}/withdraw
{
  "amount": 5000
}

# 이체
POST /api/accounts/transfer
{
  "fromAccountId": 1,
  "toAccountId": 2,
  "amount": 3000
}
```

### Deposit Service (`/api/deposits`)
```bash
# 예금 상품 생성
POST /api/deposits
{
  "accountId": 1,
  "depositType": "FIXED_DEPOSIT",
  "principal": 1000000,
  "interestRate": 3.5,
  "termMonths": 12
}

# 예금 조회
GET /api/deposits/{depositId}

# 예금 목록 조회
GET /api/deposits/account/{accountId}

# 이자 계산
GET /api/deposits/{depositId}/interest

# 조기 해지
POST /api/deposits/{depositId}/terminate
```

### Loan Service (`/api/loans`)
```bash
# 대출 신청
POST /api/loans/applications
{
  "customerId": 1,
  "loanType": "PERSONAL_CREDIT",
  "requestedAmount": 5000000,
  "termMonths": 36,
  "purpose": "Business"
}

# 신청 상태 조회
GET /api/loans/applications/{applicationId}

# 대출 승인
POST /api/loans/applications/{applicationId}/approve

# 대출 실행
POST /api/loans
{
  "applicationId": 1,
  "disbursementAccountId": 1
}

# 대출 상환
POST /api/loans/{loanId}/repay
{
  "amount": 150000
}
```

### Card Service (`/api/cards`)
```bash
# 카드 신청
POST /api/cards/applications
{
  "customerId": 1,
  "cardType": "CREDIT",
  "requestedLimit": 3000000
}

# 카드 발급
POST /api/cards
{
  "applicationId": 1,
  "linkedAccountId": 1
}

# 카드 활성화
POST /api/cards/{cardId}/activate

# 카드 거래 내역
GET /api/cards/{cardId}/transactions

# 카드 명세서
GET /api/cards/{cardId}/statements
```

## 🔧 서비스별 Eureka 설정

각 서비스의 `application.yml`에 다음 설정을 추가해야 합니다:

### 1. 의존성 추가 (build.gradle.kts)
```kotlin
dependencies {
    implementation("org.springframework.cloud:spring-cloud-starter-netflix-eureka-client")
}

dependencyManagement {
    imports {
        mavenBom("org.springframework.cloud:spring-cloud-dependencies:2025.1.0")
    }
}
```

### 2. Eureka 설정 (application.yml)
```yaml
eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_URI:http://localhost:8761/eureka}
  instance:
    prefer-ip-address: true
    instance-id: ${spring.application.name}:${random.value}
```

상세한 설정은 `service-configs/` 디렉토리의 파일을 참조하세요:
- `account-eureka-config.yml`
- `deposit-eureka-config.yml`
- `loan-eureka-config.yml`
- `card-eureka-config.yml`

## 🔍 모니터링 및 관리

### Eureka Dashboard
- URL: http://localhost:8761
- 등록된 서비스 인스턴스 확인
- 서비스 상태 모니터링

### Gateway Routes
- URL: http://localhost:8080/actuator/gateway/routes
- 설정된 라우팅 규칙 확인

### Health Checks
- Gateway: http://localhost:8080/actuator/health
- Account: http://localhost:8081/actuator/health
- Deposit: http://localhost:8084/actuator/health
- Loan: http://localhost:8082/actuator/health
- Card: http://localhost:8083/actuator/health

### H2 Console (개발용)
- Account DB: http://localhost:8081/h2-console
- Deposit DB: http://localhost:8084/h2-console
- Loan DB: http://localhost:8082/h2-console
- Card DB: http://localhost:8083/h2-console
- JDBC URL: `jdbc:h2:mem:{serviceName}db`

## 🛡️ 보안 및 인증

### JWT 토큰 구조
```json
{
  "sub": "user123",
  "iat": 1622547800,
  "exp": 1622551400,
  "roles": ["CUSTOMER"],
  "customerId": 1
}
```

### 인증 헤더
```
Authorization: Bearer {JWT_TOKEN}
```

## 🔄 Circuit Breaker 설정

각 서비스별로 Circuit Breaker가 구성되어 있습니다:

- **Failure Rate Threshold**: 50%
- **Slow Call Rate Threshold**: 50%
- **Slow Call Duration**: 2초
- **Wait Duration in Open State**: 10초
- **Sliding Window Size**: 100 calls

## 🚨 트러블슈팅

### 1. 서비스가 Eureka에 등록되지 않는 경우
```bash
# Eureka Server 상태 확인
curl http://localhost:8761/actuator/health

# 서비스 로그 확인
docker logs {service-container-name}
```

### 2. Gateway가 서비스를 찾지 못하는 경우
```bash
# Eureka 등록 상태 확인
curl http://localhost:8761/eureka/apps

# Gateway 라우트 확인
curl http://localhost:8080/actuator/gateway/routes
```

### 3. Circuit Breaker가 OPEN 상태인 경우
```bash
# Circuit Breaker 상태 확인
curl http://localhost:8080/actuator/circuitbreakers

# 수동 리셋 (필요시)
curl -X POST http://localhost:8080/actuator/circuitbreaker-reset
```

## 📝 빌드 스크립트

### build-all-services.sh
```bash
#!/bin/bash

echo "Building Eureka Server..."
cd ../blue-bank-eureka-server
./gradlew clean build

echo "Building Gateway..."
cd ../blue-bank-gateway
./gradlew clean build

echo "Building Blue Bank Services..."
cd ../blue-bank
./gradlew clean build

echo "Building Docker images..."
docker-compose -f ../blue-bank-gateway/docker-compose-complete.yml build

echo "Build completed!"
```

## 🔄 서비스 간 통신

### Feign Client 설정
```yaml
feign:
  client:
    config:
      account:
        url: lb://ACCOUNT  # Eureka를 통한 로드밸런싱
        connectTimeout: 5000
        readTimeout: 10000
```

### 서비스 간 의존성
- Deposit → Account (계좌 검증)
- Loan → Account (잔액 확인)
- Card → Account (계좌 연결)

## 📊 성능 최적화

### Connection Pool 설정
```yaml
spring:
  cloud:
    gateway:
      httpclient:
        connect-timeout: 10000
        response-timeout: 15000
        pool:
          max-connections: 500
          acquire-timeout: 45000
```

### Redis Rate Limiting
```yaml
spring:
  cloud:
    gateway:
      default-filters:
        - name: RequestRateLimiter
          args:
            redis-rate-limiter.replenishRate: 10
            redis-rate-limiter.burstCapacity: 20
```

## 🏷️ 버전 정보

- Spring Boot: 4.0.2
- Spring Cloud: 2025.1.0
- Kotlin: 2.3.0
- Java: 21/25
- Docker Compose: 3.8

---

**참고**: 이 문서는 Blue Bank 마이크로서비스 시스템의 Gateway와 Eureka 통합을 위한 가이드입니다.
추가 질문이나 문제가 있으면 프로젝트 관리자에게 문의하세요.