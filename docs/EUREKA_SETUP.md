# Eureka Discovery Server & Gateway 설정 가이드

## 구성 완료 사항

### 1. Eureka Discovery Server
- **위치**: `/Users/wonhee.lee/IdeaProjects/blue-bank-eureka-server`
- **포트**: 8761
- **대시보드 URL**: http://localhost:8761

### 2. API Gateway (Spring Cloud Gateway)
- **위치**: `/Users/wonhee.lee/IdeaProjects/blue-bank-gateway`
- **포트**: 8080
- Eureka Client로 설정되어 서비스 디스커버리 사용 가능

## 실행 방법

### 로컬 개발 환경

1. **Eureka Server 실행**
```bash
cd /Users/wonhee.lee/IdeaProjects/blue-bank-eureka-server
./gradlew bootRun
```

2. **Gateway 실행**
```bash
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway
./gradlew bootRun
```

### Docker Compose 실행
```bash
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway

# Eureka Server 빌드
cd ../blue-bank-eureka-server
./gradlew clean build

# Gateway 빌드
cd ../blue-bank-gateway
./gradlew clean build

# Docker Compose 실행
docker-compose up -d
```

## 마이크로서비스 Eureka 등록 방법

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

### 2. application.yml 설정
```yaml
spring:
  application:
    name: PAYMENT-SERVICE  # 서비스 이름

eureka:
  client:
    service-url:
      defaultZone: http://localhost:8761/eureka
  instance:
    prefer-ip-address: true
```

참고: `microservice-sample-config.yml` 파일에 전체 설정 예시가 있습니다.

## 라우팅 구성

Gateway는 다음과 같은 라우팅을 제공합니다:

| 경로 | 서비스 이름 | 설명 |
|------|------------|------|
| `/search/**` | SEARCH-SERVICE | 검색 서비스 |
| `/payment/**` | PAYMENT-SERVICE | 결제 서비스 |
| `/api/**` | BLUE-BANK-SERVICE | 메인 뱅킹 서비스 |

### 동적 라우팅
- `lb://` 프리픽스를 사용하여 로드 밸런싱 지원
- Eureka에 등록된 서비스는 자동으로 디스커버리됨
- 서비스 이름 기반 라우팅: `http://gateway:8080/{service-name}/**`

## 모니터링

### Eureka Dashboard
- URL: http://localhost:8761
- 등록된 모든 서비스 인스턴스 확인 가능

### Gateway Actuator Endpoints
- Health: http://localhost:8080/actuator/health
- Gateway Routes: http://localhost:8080/actuator/gateway/routes
- Metrics: http://localhost:8080/actuator/metrics

## 주요 기능

1. **Service Discovery**: 서비스 자동 발견 및 등록
2. **Load Balancing**: 여러 인스턴스 간 자동 로드 밸런싱
3. **Circuit Breaker**: Resilience4j 통합
4. **Rate Limiting**: Redis 기반 요청 제한 (설정 가능)
5. **JWT Authentication**: 인증 필터 구현
6. **Request/Response Logging**: 액세스 로그 필터

## 트러블슈팅

### 서비스가 Eureka에 등록되지 않는 경우
1. Eureka Server가 실행 중인지 확인
2. 서비스의 eureka.client.service-url.defaultZone 설정 확인
3. 네트워크 연결 상태 확인

### Gateway가 서비스를 찾지 못하는 경우
1. 서비스가 Eureka에 등록되어 있는지 확인
2. 서비스 이름이 일치하는지 확인 (대소문자 구분)
3. Gateway의 discovery.locator.enabled가 true인지 확인