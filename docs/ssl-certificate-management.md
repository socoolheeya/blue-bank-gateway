# SSL/TLS 인증서 관리 가이드

## 목차
1. [인증서 타입 비교](#인증서-타입-비교)
2. [개발 환경 인증서](#개발-환경-인증서)
3. [운영 환경 인증서](#운영-환경-인증서)
4. [인증서 관리 Best Practices](#인증서-관리-best-practices)
5. [문제 해결](#문제-해결)

---

## 인증서 타입 비교

### 1. Self-Signed Certificate (자체 서명 인증서)
```
✓ 장점:
  - 무료
  - 즉시 생성 가능
  - 만료 기간 제약 없음

✗ 단점:
  - 브라우저 경고 (신뢰할 수 없음)
  - 공식 인증 기관 검증 없음
  - 운영 환경 부적합

📌 용도: 로컬 개발, 내부 테스트
```

### 2. Domain Validated (DV) Certificate
```
✓ 장점:
  - 저렴 또는 무료 (Let's Encrypt)
  - 빠른 발급 (몇 분)
  - 자동 갱신 가능

✗ 단점:
  - 조직 검증 없음
  - 신뢰도 낮음

📌 용도: 블로그, 개인 사이트, 개발 서버
```

### 3. Organization Validated (OV) Certificate
```
✓ 장점:
  - 조직 검증 포함
  - 높은 신뢰도
  - 금융권 권장

✗ 단점:
  - 유료 (연간 수십만원~)
  - 발급 시간 소요 (며칠~주)

📌 용도: 기업 웹사이트, API 서버
```

### 4. Extended Validation (EV) Certificate
```
✓ 장점:
  - 최고 수준 검증
  - 브라우저 주소창에 조직명 표시
  - 피싱 방지

✗ 단점:
  - 고가 (연간 수백만원)
  - 까다로운 검증 절차

📌 용도: 금융 기관, 결제 서비스
```

---

## 개발 환경 인증서

### 방법 1: 스크립트로 자동 생성
```bash
# 프로젝트 루트에서 실행
cd /path/to/blue-bank-gateway
./scripts/generate-ssl-cert.sh

# 옵션 1 선택: localhost용 인증서 생성
```

### 방법 2: 수동 생성
```bash
# 1. 개인키 생성 (2048bit)
openssl genrsa -out nginx/ssl/server.key 2048

# 2. 자체 서명 인증서 생성 (유효기간 1년)
openssl req -new -x509 -key nginx/ssl/server.key \
  -out nginx/ssl/server.crt -days 365 \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=BlueBank/CN=localhost"

# 3. 권한 설정
chmod 600 nginx/ssl/server.key
chmod 644 nginx/ssl/server.crt
```

### 방법 3: mkcert (권장)
```bash
# mkcert 설치 (macOS)
brew install mkcert
mkcert -install

# 인증서 생성
cd nginx/ssl
mkcert localhost 127.0.0.1 ::1

# 생성된 파일 이름 변경
mv localhost+2.pem server.crt
mv localhost+2-key.pem server.key
```

**장점**: 시스템에 자동으로 루트 CA 등록되어 브라우저 경고 없음

---

## 운영 환경 인증서

### 방법 1: Let's Encrypt (무료)

#### 사전 요구사항
- 공인 도메인 보유
- 도메인이 서버 IP를 가리킴 (DNS 설정 완료)
- 80/443 포트 개방

#### Certbot으로 자동 발급
```bash
# 1. Certbot 설치 (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx

# 2. Nginx 플러그인으로 자동 발급 및 설정
sudo certbot --nginx -d api.bluebank.com -d www.bluebank.com

# 3. 자동 갱신 테스트 (90일마다 갱신 필요)
sudo certbot renew --dry-run

# 4. 자동 갱신 크론잡 설정 (certbot이 자동으로 추가함)
# /etc/cron.d/certbot
```

#### Docker 환경에서 Let's Encrypt
```yaml
# docker-compose.yml
services:
  nginx:
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - /etc/letsencrypt:/etc/letsencrypt:ro  # Certbot 인증서
      - certbot-webroot:/var/www/certbot

  certbot:
    image: certbot/certbot
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
      - certbot-webroot:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

volumes:
  certbot-webroot:
```

### 방법 2: 상용 인증서 (OV/EV)

#### 1. CSR 생성
```bash
# 스크립트 사용
./scripts/generate-ssl-cert.sh
# 옵션 3 선택: CSR 생성

# 또는 수동 생성
openssl req -new -newkey rsa:4096 -nodes \
  -keyout production.key \
  -out production.csr \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=BlueBank Corporation/CN=api.bluebank.com"
```

#### 2. CSR 파일을 CA에 제출
- **한국**: 한국정보인증(KICA), 코모도코리아
- **글로벌**: DigiCert, GlobalSign, Sectigo

#### 3. CA에서 발급받은 인증서 설치
```bash
# CA에서 받은 파일:
# - server.crt (서버 인증서)
# - intermediate.crt (중간 인증서)
# - root.crt (루트 인증서)

# 인증서 체인 파일 생성
cat server.crt intermediate.crt > nginx/ssl/server.crt

# Nginx 설정
# ssl_certificate /etc/nginx/ssl/server.crt;
# ssl_certificate_key /etc/nginx/ssl/production.key;
```

### 방법 3: AWS Certificate Manager (ACM)
```bash
# ALB/CloudFront 사용시 무료
# 단, EC2에 직접 다운로드 불가

# Nginx가 아닌 AWS Load Balancer에서 SSL 종료
[인터넷] → [ALB (SSL 종료)] → [Nginx (HTTP)] → [Gateway]
```

---

## 인증서 관리 Best Practices

### 1. 보안
```bash
# ✓ 개인키는 절대 Git에 커밋하지 말 것
echo "*.key" >> .gitignore
echo "*.pem" >> .gitignore

# ✓ 개인키 권한 제한
chmod 600 nginx/ssl/*.key

# ✓ 개인키 암호화 (선택)
openssl rsa -aes256 -in server.key -out server.encrypted.key

# ✗ 개인키를 이메일/슬랙으로 전송하지 말 것
```

### 2. 만료 관리
```bash
# 인증서 만료일 확인
openssl x509 -in nginx/ssl/server.crt -noout -enddate

# 30일 전 알림 스크립트 (cron)
#!/bin/bash
EXPIRY=$(openssl x509 -in /etc/nginx/ssl/server.crt -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
    echo "⚠️  SSL 인증서 $DAYS_LEFT일 후 만료!" | mail -s "SSL Alert" admin@bluebank.com
fi
```

### 3. 환경별 분리
```bash
# 디렉토리 구조
nginx/ssl/
├── dev/
│   ├── server.crt
│   └── server.key
├── staging/
│   ├── server.crt
│   └── server.key
└── production/
    ├── server.crt
    ├── server.key
    └── intermediate.crt

# Nginx 설정 (환경 변수 사용)
ssl_certificate /etc/nginx/ssl/${ENVIRONMENT}/server.crt;
ssl_certificate_key /etc/nginx/ssl/${ENVIRONMENT}/server.key;
```

### 4. 버전 관리
```bash
# 인증서 갱신 시 백업
cp nginx/ssl/server.crt nginx/ssl/server.crt.$(date +%Y%m%d)
cp nginx/ssl/server.key nginx/ssl/server.key.$(date +%Y%m%d)

# 갱신
mv new-server.crt nginx/ssl/server.crt
mv new-server.key nginx/ssl/server.key

# Nginx 재시작
docker-compose restart nginx
```

### 5. 모니터링
```bash
# Prometheus Exporter 사용
# ssl_exporter로 만료일 모니터링

# Grafana 대시보드에서 알림 설정
# Alert: SSL certificate expires in < 30 days
```

---

## Nginx 설정

### 기본 설정
```nginx
server {
    listen 443 ssl http2;
    server_name api.bluebank.com;

    # 인증서 파일
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    # SSL 프로토콜 (TLS 1.2, 1.3만 허용)
    ssl_protocols TLSv1.2 TLSv1.3;

    # 강력한 암호화 스위트
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # 세션 캐시 (성능 향상)
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # OCSP Stapling (인증서 상태 확인)
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/nginx/ssl/intermediate.crt;

    # HSTS (강제 HTTPS)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

### 고급 설정 (PCI DSS 준수)
```nginx
# 금융권 보안 요구사항 충족
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers on;
ssl_session_tickets off;

# DH 파라미터 (2048bit 이상)
ssl_dhparam /etc/nginx/ssl/dhparam.pem;
```

---

## 문제 해결

### 1. "certificate has expired" 오류
```bash
# 인증서 만료일 확인
openssl x509 -in nginx/ssl/server.crt -noout -dates

# 해결: 인증서 갱신
sudo certbot renew  # Let's Encrypt
# 또는 CA에서 새 인증서 발급
```

### 2. "certificate verify failed" 오류
```bash
# 인증서 체인 확인
openssl verify -CAfile intermediate.crt server.crt

# 해결: 중간 인증서 포함
cat server.crt intermediate.crt > fullchain.crt
```

### 3. "SSL handshake failed" 오류
```bash
# SSL 설정 테스트
openssl s_client -connect api.bluebank.com:443 -servername api.bluebank.com

# Nginx 설정 검증
docker-compose exec nginx nginx -t
```

### 4. 브라우저 "NET::ERR_CERT_COMMON_NAME_INVALID"
```bash
# SAN (Subject Alternative Name) 확인
openssl x509 -in server.crt -noout -text | grep -A1 "Subject Alternative Name"

# 해결: SAN 포함하여 인증서 재생성
```

---

## 체크리스트

### 개발 환경
- [ ] 자체 서명 인증서 생성
- [ ] Git에서 `*.key` 제외
- [ ] 브라우저에 인증서 신뢰 추가 (mkcert 권장)

### 스테이징 환경
- [ ] Let's Encrypt DV 인증서 발급
- [ ] 자동 갱신 설정
- [ ] 만료 알림 설정

### 운영 환경
- [ ] OV/EV 인증서 발급
- [ ] 중간 인증서 체인 확인
- [ ] TLS 1.2+ 강제
- [ ] HSTS 헤더 활성화
- [ ] 보안 감사 (SSL Labs: A+ 등급)
- [ ] 백업 및 재해 복구 계획
- [ ] 모니터링 및 알림

---

## 관련 링크

- [Let's Encrypt 공식 문서](https://letsencrypt.org/docs/)
- [SSL Labs 테스트](https://www.ssllabs.com/ssltest/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [certbot 공식 문서](https://certbot.eff.org/)
- [mkcert GitHub](https://github.com/FiloSottile/mkcert)