# Blue Bank Gateway Scripts

## 📁 스크립트 목록

### 1. **service-manager.sh** - 🔧 메인 서비스 관리 도구
모든 서비스 관리 작업을 수행하는 통합 스크립트입니다.

```bash
# 사용법
./service-manager.sh [명령] [옵션]

# 명령어
start [service] [count]    # 특정 서비스의 인스턴스를 N개 시작
stop [service] [count]     # 특정 서비스의 인스턴스를 N개 중지
scale [service] [count]    # 특정 서비스를 정확히 N개로 조정
restart [service] [count]  # 특정 서비스를 재시작
status                     # 모든 서비스 상태 확인
start-all [count]          # 모든 서비스를 각각 N개씩 시작
stop-all                   # 모든 서비스 중지
build                      # 모든 서비스 이미지 빌드

# 예시
./service-manager.sh start account 5      # Account 서비스 5개 시작
./service-manager.sh scale deposit 10     # Deposit 서비스를 10개로 조정
./service-manager.sh status               # 전체 상태 확인
./service-manager.sh stop-all             # 모든 서비스 중지
```

### 2. **restart-services-multi-instance.sh** - 🔄 전체 서비스 재시작
모든 서비스를 미리 설정된 개수로 재시작합니다.

```bash
# 사용법
./restart-services-multi-instance.sh [옵션]

# 옵션
--build     # 이미지를 다시 빌드
--fast      # 대기 시간 단축 (30초)
--no-wait   # 대기 없이 즉시 완료

# 환경 변수로 인스턴스 수 조정
ACCOUNT_INSTANCES=5 DEPOSIT_INSTANCES=10 ./restart-services-multi-instance.sh

# 기본 설정
- Account: 3개
- Deposit: 5개
- Loan: 6개
- Card: 7개
```

### 3. **scale-all.sh** - 📈 모든 서비스 동시 스케일링
모든 서비스를 동일한 인스턴스 수로 조정합니다.

```bash
# 사용법
./scale-all.sh [인스턴스 수]

# 예시
./scale-all.sh 10   # 모든 서비스를 각각 10개로 조정
```

### 4. **monitor.sh** - 📊 실시간 모니터링
서비스 상태를 실시간으로 모니터링합니다.

```bash
# 사용법
./monitor.sh

# 특징
- 5초마다 자동 새로고침
- Docker 컨테이너 상태 표시
- Eureka 등록 상태 표시
- 메모리 사용량 표시
- Ctrl+C로 종료
```

### 5. **quick-test.sh** - 🧪 빠른 테스트
모든 서비스의 엔드포인트를 테스트하고 로드 밸런싱을 확인합니다.

```bash
# 사용법
./quick-test.sh

# 테스트 항목
- 각 서비스 10회 요청
- 응답 시간 측정
- HTTP 상태 코드 확인
- Eureka 등록 확인
- Gateway 라우트 확인
```

---

## 📊 포트 할당 범위

| 서비스 | 포트 범위 | 최대 인스턴스 |
|--------|-----------|---------------|
| Account | 8100-8199 | 99개 |
| Deposit | 8200-8299 | 99개 |
| Loan | 8300-8399 | 99개 |
| Card | 8400-8499 | 99개 |

## 🚀 일반적인 사용 시나리오

### 1. 개발 환경 시작
```bash
# 모든 서비스를 기본 설정으로 재시작
./restart-services-multi-instance.sh
```

### 2. 특정 서비스 스케일링
```bash
# Account 서비스를 10개로 늘리기
./service-manager.sh scale account 10
```

### 3. 전체 시스템 모니터링
```bash
# 실시간 모니터링 시작
./monitor.sh
```

### 4. 시스템 테스트
```bash
# 빠른 테스트 실행
./quick-test.sh
```

### 5. 전체 종료
```bash
# 모든 서비스 중지
./service-manager.sh stop-all
```

## 📝 팁

- `service-manager.sh`가 대부분의 작업을 처리할 수 있습니다
- 여러 서비스를 다른 인스턴스 수로 실행하려면 `restart-services-multi-instance.sh` 사용
- 실시간 상태 확인은 `monitor.sh` 사용
- 빠른 동작 확인은 `quick-test.sh` 사용