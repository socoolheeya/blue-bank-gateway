#!/bin/bash

# ============================================
# SSL/TLS 인증서 생성 스크립트
# Blue Bank Gateway - Development Only
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SSL/TLS Certificate Generator${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# SSL 디렉토리 생성
mkdir -p "$SSL_DIR"

# 인증서 타입 선택
echo "인증서 타입을 선택하세요:"
echo "1) 개발용 Self-Signed Certificate (localhost)"
echo "2) 개발용 Self-Signed Certificate (커스텀 도메인)"
echo "3) Let's Encrypt 준비 (CSR 생성)"
read -p "선택 (1-3): " cert_type

case $cert_type in
    1)
        echo -e "\n${YELLOW}[1/3] localhost용 자체 서명 인증서 생성 중...${NC}"

        # 개인키 생성 (RSA 2048bit)
        openssl genrsa -out "$SSL_DIR/server.key" 2048

        # 자체 서명 인증서 생성 (유효기간 365일)
        openssl req -new -x509 -key "$SSL_DIR/server.key" \
            -out "$SSL_DIR/server.crt" \
            -days 365 \
            -subj "/C=KR/ST=Seoul/L=Seoul/O=BlueBank/CN=localhost"

        echo -e "${GREEN}✓ localhost 인증서 생성 완료${NC}"
        ;;

    2)
        read -p "도메인 이름 (예: dev.bluebank.com): " domain

        echo -e "\n${YELLOW}[1/3] $domain용 자체 서명 인증서 생성 중...${NC}"

        # SAN (Subject Alternative Name) 설정 파일 생성
        cat > "$SSL_DIR/openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=KR
ST=Seoul
L=Seoul
O=BlueBank
CN=$domain

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = *.$domain
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

        # 개인키 생성
        openssl genrsa -out "$SSL_DIR/server.key" 2048

        # CSR 생성
        openssl req -new -key "$SSL_DIR/server.key" \
            -out "$SSL_DIR/server.csr" \
            -config "$SSL_DIR/openssl.cnf"

        # 자체 서명 인증서 생성
        openssl x509 -req -in "$SSL_DIR/server.csr" \
            -signkey "$SSL_DIR/server.key" \
            -out "$SSL_DIR/server.crt" \
            -days 365 \
            -extensions v3_req \
            -extfile "$SSL_DIR/openssl.cnf"

        # CSR 파일 정리
        rm "$SSL_DIR/server.csr"

        echo -e "${GREEN}✓ $domain 인증서 생성 완료${NC}"
        ;;

    3)
        read -p "운영 도메인 (예: api.bluebank.com): " prod_domain

        echo -e "\n${YELLOW}[1/3] CSR (Certificate Signing Request) 생성 중...${NC}"

        # 운영용 설정 파일
        cat > "$SSL_DIR/prod-openssl.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=KR
ST=Seoul
L=Seoul
O=BlueBank Corporation
OU=IT Department
CN=$prod_domain
emailAddress=admin@bluebank.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $prod_domain
DNS.2 = *.$prod_domain
EOF

        # 개인키 생성 (4096bit - 운영용)
        openssl genrsa -out "$SSL_DIR/production.key" 4096

        # CSR 생성
        openssl req -new -key "$SSL_DIR/production.key" \
            -out "$SSL_DIR/production.csr" \
            -config "$SSL_DIR/prod-openssl.cnf"

        echo -e "${GREEN}✓ CSR 생성 완료${NC}"
        echo -e "\n${YELLOW}다음 단계:${NC}"
        echo "1. $SSL_DIR/production.csr 파일을 인증기관(CA)에 제출"
        echo "2. 발급받은 인증서를 $SSL_DIR/production.crt로 저장"
        echo "3. 중간 인증서가 있다면 $SSL_DIR/intermediate.crt로 저장"
        echo ""
        echo "Let's Encrypt를 사용하려면:"
        echo "  sudo certbot certonly --nginx -d $prod_domain"
        ;;

    *)
        echo -e "${RED}잘못된 선택입니다.${NC}"
        exit 1
        ;;
esac

# 권한 설정
echo -e "\n${YELLOW}[2/3] 파일 권한 설정 중...${NC}"
chmod 600 "$SSL_DIR"/*.key 2>/dev/null || true
chmod 644 "$SSL_DIR"/*.crt 2>/dev/null || true
echo -e "${GREEN}✓ 권한 설정 완료${NC}"

# 인증서 정보 출력
echo -e "\n${YELLOW}[3/3] 생성된 인증서 정보:${NC}"
if [ -f "$SSL_DIR/server.crt" ]; then
    openssl x509 -in "$SSL_DIR/server.crt" -noout -text | grep -A2 "Subject:"
    openssl x509 -in "$SSL_DIR/server.crt" -noout -dates
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}인증서 생성 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "생성된 파일:"
ls -lh "$SSL_DIR"/*.key "$SSL_DIR"/*.crt 2>/dev/null || true
echo ""

# 경고 메시지
if [ "$cert_type" != "3" ]; then
    echo -e "${RED}⚠️  경고: 자체 서명 인증서는 개발/테스트용입니다!${NC}"
    echo -e "${RED}   운영 환경에서는 공인 인증서를 사용하세요.${NC}"
    echo ""
fi

# Docker Compose 재시작 안내
echo -e "${YELLOW}Nginx 재시작이 필요합니다:${NC}"
echo "  docker-compose restart nginx"
echo ""
echo -e "${YELLOW}브라우저에서 자체 서명 인증서 신뢰 방법:${NC}"
echo "  Chrome: chrome://settings/security → 인증서 관리"
echo "  Firefox: about:preferences#privacy → 인증서 보기"
echo "  macOS: 키체인 접근 → 인증서 추가 → 항상 신뢰"
echo ""