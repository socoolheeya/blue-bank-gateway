# WAF (Web Application Firewall) 구축 가이드

## 목차
1. [WAF 필요성](#waf-필요성)
2. [WAF 옵션 비교](#waf-옵션-비교)
3. [ModSecurity 구축](#modsecurity-구축)
4. [보안 규칙 설정](#보안-규칙-설정)
5. [테스트 및 검증](#테스트-및-검증)
6. [운영 관리](#운영-관리)

---

## WAF 필요성

### 금융권 필수 요구사항

#### 1. 법적/규제 준수
```
✓ 전자금융감독규정: 웹 애플리케이션 보안 통제 의무화
✓ 개인정보보호법: 개인정보 유출 방지 기술적 조치
✓ PCI DSS 요구사항 6.6: WAF 또는 코드 리뷰 필수
✓ 금융보안원 가이드라인: OWASP Top 10 대응
```

#### 2. 방어 대상 공격
| 공격 유형 | 위험도 | WAF 차단율 |
|----------|--------|-----------|
| SQL Injection | 극상 | 99%+ |
| XSS (Cross-Site Scripting) | 상 | 95%+ |
| CSRF | 상 | 90%+ |
| Path Traversal | 중 | 100% |
| File Upload | 중 | 95%+ |
| DDoS (Application Layer) | 상 | 80%+ |

#### 3. 비용 대비 효과
```
보안 사고 평균 비용: 수억원~수십억원
WAF 구축 비용:
  - ModSecurity (오픈소스): 무료
  - F5 NGINX WAF: 연 $수천~수만
  - AWS WAF: 월 $수십~수백

ROI: 매우 높음 (1:100 이상)
```

---

## WAF 옵션 비교

### 1. ModSecurity + OWASP CRS (★ 권장)
```
비용: 무료 (오픈소스)
난이도: 중~상
성능: 우수
커뮤니티: 활발

장점:
  ✓ OWASP Top 10 완벽 대응
  ✓ 커스텀 규칙 작성 가능
  ✓ 금융권 사용 실적 다수
  ✓ Nginx, Apache 모두 지원

단점:
  ✗ 초기 설정 복잡
  ✗ False Positive 튜닝 필요
  ✗ 상용 기술 지원 없음

적합: 중소형 금융사, 핀테크
```

### 2. F5 NGINX WAF (상용)
```
비용: 유료 구독 (연 수천만원)
난이도: 중
성능: 매우 우수
기술 지원: 공식 지원

장점:
  ✓ 턴키 솔루션
  ✓ 24/7 기술 지원
  ✓ 금융권 인증 보유
  ✓ 고급 봇 탐지

단점:
  ✗ 고비용
  ✗ 벤더 종속

적합: 대형 금융사
```

### 3. AWS WAF
```
비용: 종량제 (월 $100~)
난이도: 하
성능: 우수
관리: AWS 관리형

장점:
  ✓ 클라우드 네이티브
  ✓ ALB/CloudFront 통합
  ✓ 관리 부담 낮음
  ✓ 자동 스케일링

단점:
  ✗ AWS 종속
  ✗ 커스텀 제한적
  ✗ 온프레미스 불가

적합: AWS 기반 핀테크
```

### 4. Cloudflare WAF
```
비용: $20~$200/월
난이도: 하
성능: 매우 우수
관리: 완전 관리형

장점:
  ✓ CDN + WAF + DDoS 통합
  ✓ 글로벌 네트워크
  ✓ 즉시 적용

단점:
  ✗ 금융 데이터 외부 유출
  ✗ 규제 준수 이슈

적합: 글로벌 서비스
```

---

## ModSecurity 구축

### 방법 1: Docker로 빌드 (권장)

#### 1. Dockerfile 활용
```bash
# 프로젝트에 제공된 Dockerfile 사용
cd /path/to/blue-bank-gateway

# WAF 포함 Nginx 이미지 빌드 (10-15분 소요)
docker build -f docker/Dockerfile.nginx-waf -t nginx-waf:latest .

# 빌드 확인
docker images | grep nginx-waf
```

#### 2. Docker Compose 수정
```yaml
# docker-compose.yml
services:
  nginx:
    build:
      context: .
      dockerfile: docker/Dockerfile.nginx-waf
    image: nginx-waf:latest
    container_name: api-nginx-waf
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx-waf.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/modsec:/etc/nginx/modsec:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/logs:/var/log/nginx
      - waf-logs:/var/log/modsec
    depends_on:
      gateway:
        condition: service_healthy
    networks:
      - gateway-network
    restart: unless-stopped

volumes:
  waf-logs:
    driver: local
```

#### 3. 실행
```bash
# 빌드 및 실행
docker-compose up -d --build nginx

# 로그 확인
docker-compose logs -f nginx

# ModSecurity 동작 확인
curl -X GET "http://localhost/api/test?id=1' OR '1'='1"
# 차단되어야 함: 403 Forbidden

# WAF 로그 확인
docker-compose exec nginx cat /var/log/modsec/audit.log
```

### 방법 2: 네이티브 설치 (Ubuntu 예시)

```bash
# 1. 의존성 설치
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    libpcre3 libpcre3-dev \
    libssl-dev \
    libtool \
    autoconf \
    git \
    wget

# 2. ModSecurity 라이브러리 빌드
cd /opt
git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
cd ModSecurity
git submodule init
git submodule update
./build.sh
./configure
make
sudo make install

# 3. ModSecurity-nginx 커넥터
cd /opt
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

# 4. Nginx 소스 다운로드 및 빌드
NGINX_VERSION=1.26.2
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar zxvf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}

./configure --add-dynamic-module=/opt/ModSecurity-nginx \
    --with-http_ssl_module \
    --with-http_v2_module
make
sudo make install

# 5. OWASP CRS 다운로드
cd /usr/local
sudo wget https://github.com/coreruleset/coreruleset/archive/v4.0.0.tar.gz
sudo tar -xzvf v4.0.0.tar.gz
sudo mv coreruleset-4.0.0 owasp-crs
cd owasp-crs
sudo cp crs-setup.conf.example crs-setup.conf

# 6. ModSecurity 설정 복사
sudo mkdir -p /etc/nginx/modsec
sudo cp /opt/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
sudo cp /opt/ModSecurity/unicode.mapping /etc/nginx/modsec/
```

---

## 보안 규칙 설정

### 1. 금융권 필수 규칙

#### SQL Injection 방어
```nginx
# nginx/modsec/main.conf
SecRule REQUEST_URI|ARGS|REQUEST_HEADERS \
    "@rx (?i)(\bunion\b.*\bselect\b|\bselect\b.*\bfrom\b)" \
    "id:1001,\
    phase:2,\
    block,\
    log,\
    msg:'SQL Injection Attack',\
    severity:CRITICAL,\
    tag:'attack-sqli'"
```

#### 민감 데이터 유출 방지
```nginx
# 카드번호 패턴 탐지
SecRule RESPONSE_BODY "@rx \b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b" \
    "id:1008,\
    phase:4,\
    block,\
    log,\
    msg:'Credit Card Number in Response',\
    severity:CRITICAL,\
    tag:'data-leak'"

# 주민등록번호 패턴
SecRule RESPONSE_BODY "@rx \b\d{6}[\s\-]?\d{7}\b" \
    "id:1009,\
    phase:4,\
    block,\
    log,\
    msg:'Korean SSN Pattern in Response',\
    severity:CRITICAL"
```

#### JWT 토큰 검증
```nginx
# API 요청은 Authorization 헤더 필수
SecRule REQUEST_URI "^/api/" \
    "id:1007,\
    phase:1,\
    chain,\
    log,\
    msg:'Missing Authorization Header'"
    SecRule &REQUEST_HEADERS:Authorization "@eq 0" \
        "deny,status:401"
```

### 2. OWASP CRS 설정

#### CRS 설정 파일
```bash
# /usr/local/owasp-crs/crs-setup.conf

# 파라노이아 레벨 설정 (1-4)
# 1: 기본 (False Positive 낮음, 보안 중간)
# 2: 강화 (권장)
# 3: 엄격
# 4: 최대 (False Positive 높음)
SecAction \
  "id:900000,\
  phase:1,\
  nolog,\
  pass,\
  t:none,\
  setvar:tx.paranoia_level=2"

# 변칙 점수 임계값
SecAction \
  "id:900110,\
  phase:1,\
  nolog,\
  pass,\
  t:none,\
  setvar:tx.inbound_anomaly_score_threshold=5,\
  setvar:tx.outbound_anomaly_score_threshold=4"
```

### 3. False Positive 처리

#### 특정 규칙 비활성화
```nginx
# 특정 규칙 ID 제거
SecRuleRemoveById 920320

# 메시지 기반 제거
SecRuleRemoveByMsg "SQL Injection Attack"

# 특정 URL에서만 규칙 비활성화
SecRule REQUEST_URI "@streq /api/legacy/search" \
    "id:2100,\
    phase:1,\
    pass,\
    nolog,\
    ctl:ruleRemoveById=942100"
```

---

## 테스트 및 검증

### 1. 기본 동작 테스트

```bash
# 정상 요청 (200 OK)
curl -i http://localhost/api/accounts

# SQL Injection 시도 (403 Forbidden)
curl -i "http://localhost/api/accounts?id=1' OR '1'='1"

# XSS 시도 (403 Forbidden)
curl -i "http://localhost/api/test?name=<script>alert('xss')</script>"

# Path Traversal 시도 (403 Forbidden)
curl -i "http://localhost/../../etc/passwd"

# 악성 User-Agent (403 Forbidden)
curl -i -H "User-Agent: sqlmap/1.0" http://localhost/api/test
```

### 2. WAF 로그 확인

```bash
# Nginx WAF 로그
tail -f nginx/logs/waf.log

# ModSecurity 감사 로그
docker-compose exec nginx tail -f /var/log/modsec/audit.log

# 차단된 요청만 필터링
grep "Forbidden" nginx/logs/waf.log

# SQL Injection 공격 통계
grep "SQL Injection" /var/log/modsec/audit.log | wc -l
```

### 3. 성능 테스트

```bash
# Apache Bench로 성능 측정
# WAF 없이
ab -n 1000 -c 10 http://localhost/api/health

# WAF 포함
ab -n 1000 -c 10 http://localhost/api/health

# 성능 영향: 보통 5-15% 정도
```

### 4. 보안 감사

```bash
# OWASP ZAP으로 취약점 스캔
docker run -t owasp/zap2docker-stable zap-baseline.py \
    -t http://your-server.com

# Nikto 스캐너
nikto -h http://localhost
# WAF가 제대로 작동하면 차단되어야 함
```

---

## 운영 관리

### 1. 모니터링

#### Prometheus + Grafana 연동
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:9113']
    metrics_path: '/metrics'

  - job_name: 'modsecurity'
    static_configs:
      - targets: ['nginx:9145']
```

#### Grafana 대시보드
```json
{
  "panels": [
    {
      "title": "WAF Blocked Requests",
      "targets": [{
        "expr": "rate(nginx_http_requests_total{status=\"403\"}[5m])"
      }]
    },
    {
      "title": "Top Attack Types",
      "targets": [{
        "expr": "topk(10, sum by (attack_type) (modsecurity_attacks_total))"
      }]
    }
  ]
}
```

### 2. 알림 설정

```yaml
# alertmanager.yml
route:
  receiver: 'security-team'
  group_by: ['alertname', 'severity']

receivers:
  - name: 'security-team'
    email_configs:
      - to: 'security@bluebank.com'
    slack_configs:
      - channel: '#security-alerts'

# 알림 규칙
groups:
  - name: waf_alerts
    rules:
      - alert: HighAttackRate
        expr: rate(nginx_http_requests_total{status="403"}[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High attack rate detected"
          description: "{{ $value }} attacks/sec"

      - alert: SQLInjectionDetected
        expr: increase(modsecurity_attacks_total{type="sqli"}[1m]) > 0
        labels:
          severity: critical
        annotations:
          summary: "SQL Injection attempt detected"
```

### 3. 로그 분석

```bash
# 일일 공격 통계
cat /var/log/modsec/audit.log | \
  grep -o 'id "[0-9]*"' | \
  sort | uniq -c | sort -rn

# 공격 IP 상위 10개
grep "403" /var/log/nginx/access.log | \
  awk '{print $1}' | \
  sort | uniq -c | sort -rn | head -10

# 시간대별 공격 패턴
grep "403" /var/log/nginx/access.log | \
  awk '{print $4}' | \
  cut -d: -f2 | \
  sort | uniq -c
```

### 4. 규칙 업데이트

```bash
# OWASP CRS 업데이트 (분기별 권장)
cd /usr/local/owasp-crs
git pull origin main

# Nginx 재시작 (무중단)
docker-compose exec nginx nginx -s reload

# 또는 컨테이너 재시작
docker-compose restart nginx
```

### 5. 백업 및 복구

```bash
# 설정 백업
tar -czf waf-config-$(date +%Y%m%d).tar.gz \
  /etc/nginx/modsec/ \
  /etc/nginx/nginx.conf \
  /usr/local/owasp-crs/

# 로그 백업 (일일)
tar -czf modsec-logs-$(date +%Y%m%d).tar.gz \
  /var/log/modsec/*.log

# 복구
tar -xzf waf-config-20260214.tar.gz -C /
```

---

## 체크리스트

### 구축 단계
- [ ] ModSecurity 설치 및 Nginx 통합
- [ ] OWASP CRS 다운로드 및 설정
- [ ] 커스텀 보안 규칙 작성 (금융권 특화)
- [ ] False Positive 테스트 및 튜닝
- [ ] 성능 테스트 (처리량, 지연시간)

### 운영 단계
- [ ] 모니터링 대시보드 구축
- [ ] 알림 시스템 연동
- [ ] 로그 분석 자동화
- [ ] 규칙 업데이트 프로세스 수립
- [ ] 보안 사고 대응 절차 수립

### 준수 사항
- [ ] 전자금융감독규정 준수 확인
- [ ] PCI DSS 요구사항 충족
- [ ] 개인정보 유출 방지 검증
- [ ] 보안 감사 정기 실시 (분기별)
- [ ] 취약점 스캔 및 패치 (월별)

---

## FAQ

### Q1: WAF가 성능에 미치는 영향은?
```
A: 일반적으로 5-15% 정도의 오버헤드 발생
   - 요청당 1-5ms 추가 지연
   - CPU 사용률 10-20% 증가
   - 메모리 사용량 증가 (규칙셋 크기에 비례)

최적화 방법:
   - 불필요한 규칙 비활성화
   - 정적 파일은 WAF 우회
   - 헬스체크 엔드포인트 WAF 제외
```

### Q2: False Positive를 줄이려면?
```
A: 단계적 접근
   1. Detection Only 모드로 시작
      SecRuleEngine DetectionOnly

   2. 로그 분석하여 오탐 식별

   3. 예외 규칙 추가
      SecRuleRemoveById <rule_id>

   4. Blocking 모드로 전환
      SecRuleEngine On
```

### Q3: 상용 WAF vs ModSecurity 선택 기준은?
```
A: 조직 규모 및 요구사항에 따라:

ModSecurity 적합:
   - 중소형 금융사/핀테크
   - IT 역량 보유
   - 비용 절감 중요

상용 WAF 적합:
   - 대형 금융사
   - 24/7 기술 지원 필요
   - 턴키 솔루션 선호
   - 규제 인증 필수
```

---

## 참고 자료

- [ModSecurity 공식 문서](https://github.com/SpiderLabs/ModSecurity)
- [OWASP CRS](https://coreruleset.org/)
- [Nginx ModSecurity 통합 가이드](https://github.com/SpiderLabs/ModSecurity-nginx)
- [금융보안원 웹 보안 가이드](https://www.fsec.or.kr/)
- [PCI DSS Requirements](https://www.pcisecuritystandards.org/)