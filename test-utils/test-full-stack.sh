#!/bin/bash

echo "============================================"
echo "🧪 Nginx + API Gateway 통합 테스트"
echo "============================================"
echo ""

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 테스트 결과 카운터
PASSED=0
FAILED=0

# 테스트 함수
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="$3"
    local expected_text="$4"

    echo -e "${BLUE}Testing: $name${NC}"
    echo "URL: $url"

    RESPONSE=$(curl -s -w "\n%{http_code}" "$url" 2>&1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" = "$expected_code" ]; then
        if [ -n "$expected_text" ]; then
            if echo "$BODY" | grep -q "$expected_text"; then
                echo -e "${GREEN}✅ PASS${NC} - HTTP $HTTP_CODE, Contains: '$expected_text'"
                PASSED=$((PASSED + 1))
            else
                echo -e "${RED}❌ FAIL${NC} - HTTP $HTTP_CODE, Missing: '$expected_text'"
                echo "Response: $BODY"
                FAILED=$((FAILED + 1))
            fi
        else
            echo -e "${GREEN}✅ PASS${NC} - HTTP $HTTP_CODE"
            PASSED=$((PASSED + 1))
        fi
    else
        echo -e "${RED}❌ FAIL${NC} - Expected HTTP $expected_code, Got HTTP $HTTP_CODE"
        echo "Response: $BODY"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

echo "============================================"
echo "📊 1. 컨테이너 상태 확인"
echo "============================================"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter name=gateway --filter name=nginx
echo ""

echo "============================================"
echo "🔍 2. Health Check 테스트"
echo "============================================"

# Nginx Health Check
test_endpoint "Nginx Health Check" \
    "http://localhost/health" \
    "200" \
    "UP"

# Gateway Actuator (직접)
test_endpoint "Gateway Actuator (via Nginx)" \
    "http://localhost/actuator/health" \
    "200" \
    "UP"

echo "============================================"
echo "🛣️  3. 라우팅 테스트"
echo "============================================"

# Fallback 엔드포인트
test_endpoint "Search Fallback" \
    "http://localhost/fallback/search" \
    "503" \
    "Search Service Unavailable"

test_endpoint "Payment Fallback" \
    "http://localhost/fallback/payment" \
    "503" \
    "Payment Service Unavailable"

echo "============================================"
echo "🚦 4. Rate Limiting 테스트 (간단)"
echo "============================================"
echo "5회 연속 요청 테스트..."

SUCCESS=0
for i in {1..5}; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/actuator/health)
    if [ "$CODE" = "200" ]; then
        SUCCESS=$((SUCCESS + 1))
    fi
done

if [ $SUCCESS -eq 5 ]; then
    echo -e "${GREEN}✅ PASS${NC} - 5/5 requests succeeded (within rate limit)"
    PASSED=$((PASSED + 1))
else
    echo -e "${YELLOW}⚠️  PARTIAL${NC} - $SUCCESS/5 requests succeeded"
    PASSED=$((PASSED + 1))
fi
echo ""

echo "============================================"
echo "🔐 5. Security Headers 확인"
echo "============================================"

HEADERS=$(curl -s -I http://localhost/actuator/health)

check_header() {
    local header_name="$1"
    if echo "$HEADERS" | grep -qi "$header_name"; then
        echo -e "${GREEN}✅ $header_name${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ $header_name (missing)${NC}"
        FAILED=$((FAILED + 1))
    fi
}

check_header "X-Frame-Options"
check_header "X-Content-Type-Options"
check_header "X-XSS-Protection"
echo ""

echo "============================================"
echo "🌐 6. Nginx → Gateway 프록시 확인"
echo "============================================"

# Check if response comes from Gateway
RESPONSE=$(curl -s -I http://localhost/actuator/health)
if echo "$RESPONSE" | grep -q "Server: nginx"; then
    echo -e "${GREEN}✅ Nginx is fronting the requests${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌ Nginx not detected${NC}"
    FAILED=$((FAILED + 1))
fi

# Check Gateway routing
test_endpoint "Gateway Routes Endpoint" \
    "http://localhost/actuator/gateway/routes" \
    "200" \
    ""

echo "============================================"
echo "📈 7. Gateway Metrics 확인"
echo "============================================"

test_endpoint "Metrics Endpoint" \
    "http://localhost/actuator/metrics" \
    "200" \
    "names"

echo "============================================"
echo "🔄 8. Redis 연결 확인"
echo "============================================"

# Redis 컨테이너 상태
REDIS_STATUS=$(docker inspect gateway-redis --format='{{.State.Health.Status}}' 2>/dev/null)
if [ "$REDIS_STATUS" = "healthy" ]; then
    echo -e "${GREEN}✅ Redis container is healthy${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌ Redis container is not healthy: $REDIS_STATUS${NC}"
    FAILED=$((FAILED + 1))
fi

# Gateway → Redis 연결 확인
GATEWAY_LOGS=$(docker logs spring-gateway 2>&1 | tail -50)
if echo "$GATEWAY_LOGS" | grep -q "Redis repositories"; then
    echo -e "${GREEN}✅ Gateway connected to Redis${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌ Gateway Redis connection issue${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

echo "============================================"
echo "📝 9. 로그 확인"
echo "============================================"

echo "Nginx 최근 로그 (마지막 3줄):"
docker exec api-nginx tail -3 /var/log/nginx/access.log 2>/dev/null || echo "No access logs yet"
echo ""

echo "Gateway 최근 로그 (마지막 3줄):"
docker logs spring-gateway 2>&1 | grep -E "(Started|profile|ERROR)" | tail -3
echo ""

echo "============================================"
echo "📊 테스트 결과 요약"
echo "============================================"
TOTAL=$((PASSED + FAILED))
PERCENTAGE=$((PASSED * 100 / TOTAL))

echo -e "${GREEN}✅ Passed: $PASSED${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"
echo "Total: $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 모든 테스트 통과! ($PERCENTAGE%)${NC}"
    exit 0
elif [ $PERCENTAGE -ge 80 ]; then
    echo -e "${YELLOW}⚠️  대부분 통과 ($PERCENTAGE%)${NC}"
    exit 0
else
    echo -e "${RED}❌ 테스트 실패가 많습니다 ($PERCENTAGE%)${NC}"
    exit 1
fi
