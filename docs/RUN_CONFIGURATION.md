# API Gateway 실행 가이드

## 🚀 Prod 프로파일 실행 (Docker Compose)

**Prod 프로파일은 Docker Compose로만 실행 가능합니다.**

### 전체 스택 시작
```bash
docker-compose up -d
```

### 로그 확인
```bash
# 전체 로그
docker-compose logs -f

# Gateway만
docker logs -f spring-gateway

# Redis만
docker logs -f gateway-redis
```

### 상태 확인
```bash
docker ps
docker-compose ps
```

### 중지
```bash
# 정상 종료
docker-compose down

# 볼륨까지 삭제
docker-compose down -v
```

### 재빌드
```bash
# Gateway만 재빌드
docker-compose build --no-cache gateway
docker-compose up -d

# 전체 재빌드
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

## 💻 Local 프로파일로 실행하기 (IntelliJ)

### 방법 1: Run Configuration 설정
1. IntelliJ에서 `Run` → `Edit Configurations...`
2. `Spring Boot` 설정 선택 (또는 새로 생성)
3. **Active profiles** 필드에 입력:
   ```
   local
   ```
4. Apply → OK

### 방법 2: 환경변수로 설정
Run Configuration에서:
- **Environment variables** 필드에 추가:
  ```
  SPRING_PROFILES_ACTIVE=local
  ```

### 방법 3: VM Options로 설정
Run Configuration에서:
- **VM options** 필드에 추가:
  ```
  -Dspring.profiles.active=local
  ```

## 프로파일별 설정

### local 프로파일 (개발용)
- **파일**: `application-local.yml`
- **Redis 호스트**: `localhost`
- **Redis 비밀번호**: 없음
- **로그 레벨**: DEBUG (Gateway), INFO (Netty)
- **용도**: IntelliJ IDE에서 로컬 개발

### prod 프로파일 (프로덕션용)
- **파일**: `application-prod.yml`
- **Redis 호스트**: `redis` (컨테이너 이름)
- **Redis 비밀번호**: 환경변수 `REDIS_PASSWORD` 필수
- **로그 레벨**: INFO (Gateway), WARN (Netty)
- **용도**: Docker Compose로 배포

## Redis 설정

### 로컬 개발 (비밀번호 없음)
```bash
# Redis 컨테이너 시작 (비밀번호 없음)
REDIS_PASSWORD= docker-compose up -d redis
```

### 프로덕션 (비밀번호 있음)
```bash
# .env 파일에 설정
REDIS_PASSWORD=your-secure-password

# 전체 스택 시작
docker-compose up -d
```

## 확인 방법

### 현재 활성 프로파일 확인
애플리케이션 시작 로그에서:
```
The following 1 profile is active: "local"
```

### Redis 연결 확인
로그에서 에러 없이:
```
Bootstrapping Spring Data Redis repositories
```

## 문제 해결

### Redis 연결 실패 시
1. Redis 컨테이너 상태 확인:
   ```bash
   docker ps --filter name=redis
   ```

2. Redis 비밀번호 없이 실행 중인지 확인:
   ```bash
   docker logs gateway-redis | grep "without password"
   ```

3. 포트가 노출되었는지 확인:
   ```bash
   nc -zv localhost 6379
   ```
