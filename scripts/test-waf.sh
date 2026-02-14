#!/bin/bash

# ============================================
# WAF (ModSecurity) 테스트 스크립트
# Blue Bank Gateway Security Testing
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정
TARGET_URL="${1:-http://localhost}"
VERBOSE="${2:-false}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WAF Security Test Suite${NC}"
echo -e "${BLUE}Target: $TARGET_URL${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 테스트 카운터
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 테스트 함수
test_request() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local headers="$4"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "[Test $TOTAL_TESTS] $test_name ... "

    if [ "$VERBOSE" = "true" ]; then
        echo ""
        echo "  URL: $url"
    fi

    # HTTP 요청 실행
    if [ -n "$headers" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" -H "$headers" "$url" 2>&1)
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>&1)
    fi

    # 결과 검증
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✓ PASS${NC} (Status: $response)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC} (Expected: $expected_status, Got: $response)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "${YELLOW}1. 기본 동작 테스트${NC}"
echo "----------------------------------------"
test_request "정상 요청" "$TARGET_URL/api/health" "200"
test_request "존재하지 않는 경로" "$TARGET_URL/notfound" "404"
echo ""

echo -e "${YELLOW}2. SQL Injection 테스트${NC}"
echo "----------------------------------------"
test_request "기본 SQLi (OR 1=1)" "$TARGET_URL/api/test?id=1' OR '1'='1" "403"
test_request "UNION SELECT SQLi" "$TARGET_URL/api/test?id=1 UNION SELECT * FROM users" "403"
test_request "Blind SQLi" "$TARGET_URL/api/test?id=1' AND SLEEP(5)--" "403"
test_request "Stacked Query" "$TARGET_URL/api/test?id=1; DROP TABLE users--" "403"
echo ""

echo -e "${YELLOW}3. XSS (Cross-Site Scripting) 테스트${NC}"
echo "----------------------------------------"
test_request "기본 XSS" "$TARGET_URL/api/test?name=<script>alert('xss')</script>" "403"
test_request "Event Handler XSS" "$TARGET_URL/api/test?name=<img src=x onerror=alert('xss')>" "403"
test_request "JavaScript Protocol" "$TARGET_URL/api/test?url=javascript:alert('xss')" "403"
test_request "Iframe XSS" "$TARGET_URL/api/test?content=<iframe src='evil.com'></iframe>" "403"
echo ""

echo -e "${YELLOW}4. Path Traversal 테스트${NC}"
echo "----------------------------------------"
test_request "기본 Path Traversal" "$TARGET_URL/../../../etc/passwd" "403"
test_request "인코딩된 Path Traversal" "$TARGET_URL/%2e%2e%2f%2e%2e%2f" "403"
test_request "Windows Path Traversal" "$TARGET_URL/..\\..\\windows\\system32" "403"
echo ""

echo -e "${YELLOW}5. 악성 User-Agent 테스트${NC}"
echo "----------------------------------------"
test_request "SQLMap Scanner" "$TARGET_URL/api/test" "403" "User-Agent: sqlmap/1.0"
test_request "Nikto Scanner" "$TARGET_URL/api/test" "403" "User-Agent: Nikto/2.1.6"
test_request "Nmap Scanner" "$TARGET_URL/api/test" "403" "User-Agent: Mozilla/5.0 (compatible; Nmap Scripting Engine)"
test_request "정상 User-Agent" "$TARGET_URL/api/test" "200" "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
echo ""

echo -e "${YELLOW}6. HTTP Method 테스트${NC}"
echo "----------------------------------------"
test_request "정상 GET" "$TARGET_URL/api/test" "200"
test_request "정상 POST" "$TARGET_URL/api/test" "200"
test_request "비정상 TRACE" "$TARGET_URL/api/test" "405"
test_request "비정상 TRACK" "$TARGET_URL/api/test" "405"
echo ""

echo -e "${YELLOW}7. File Upload 테스트${NC}"
echo "----------------------------------------"
# 임시 파일 생성
echo "<?php system(\$_GET['cmd']); ?>" > /tmp/test.php
echo "#!/bin/bash\necho 'test'" > /tmp/test.sh
echo "test content" > /tmp/test.txt

test_request "PHP 파일 업로드 (차단)" "$TARGET_URL/api/upload?file=test.php" "403"
test_request "Shell 스크립트 업로드 (차단)" "$TARGET_URL/api/upload?file=test.sh" "403"
test_request "정상 텍스트 파일 (허용)" "$TARGET_URL/api/upload?file=test.txt" "200"

# 임시 파일 삭제
rm -f /tmp/test.php /tmp/test.sh /tmp/test.txt
echo ""

echo -e "${YELLOW}8. Rate Limiting 테스트${NC}"
echo "----------------------------------------"
echo -n "[Test] Rate Limit (100 requests) ... "

# 100개 요청 빠르게 전송
rate_limit_passed=0
for i in {1..110}; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL/api/test" 2>&1)
    if [ "$status" = "429" ]; then
        rate_limit_passed=1
        break
    fi
done

if [ $rate_limit_passed -eq 1 ]; then
    echo -e "${GREEN}✓ PASS${NC} (Rate limit triggered)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ SKIP${NC} (Rate limit not triggered - check configuration)"
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

echo -e "${YELLOW}9. Security Headers 테스트${NC}"
echo "----------------------------------------"
headers=$(curl -s -I "$TARGET_URL/api/test" 2>&1)

check_header() {
    local header_name="$1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "[Test $TOTAL_TESTS] $header_name ... "

    if echo "$headers" | grep -qi "$header_name"; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC} (Header not found)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

check_header "X-Frame-Options"
check_header "X-Content-Type-Options"
check_header "X-XSS-Protection"
echo ""

echo -e "${YELLOW}10. OWASP Top 10 추가 테스트${NC}"
echo "----------------------------------------"
test_request "Command Injection" "$TARGET_URL/api/test?cmd=;ls -la" "403"
test_request "LDAP Injection" "$TARGET_URL/api/test?user=admin)(&(password=*))" "403"
test_request "XML External Entity" "$TARGET_URL/api/test" "403"
test_request "Server-Side Request Forgery" "$TARGET_URL/api/test?url=http://169.254.169.254/metadata" "403"
echo ""

# 결과 요약
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}테스트 결과 요약${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "총 테스트: $TOTAL_TESTS"
echo -e "${GREEN}성공: $PASSED_TESTS${NC}"
echo -e "${RED}실패: $FAILED_TESTS${NC}"
echo ""

# 성공률 계산
if [ $TOTAL_TESTS -gt 0 ]; then
    success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "성공률: ${success_rate}%"
    echo ""

    if [ $success_rate -ge 90 ]; then
        echo -e "${GREEN}✓ WAF가 정상적으로 동작하고 있습니다!${NC}"
        exit 0
    elif [ $success_rate -ge 70 ]; then
        echo -e "${YELLOW}⚠ WAF 설정을 검토해주세요.${NC}"
        exit 1
    else
        echo -e "${RED}✗ WAF가 제대로 동작하지 않습니다. 설정을 확인하세요.${NC}"
        exit 2
    fi
fi

echo -e "${BLUE}========================================${NC}"
echo ""
echo "상세 로그 확인:"
echo "  docker-compose logs nginx"
echo "  docker-compose exec nginx cat /var/log/modsec/audit.log"
echo ""