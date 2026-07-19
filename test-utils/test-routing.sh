#!/bin/bash

echo "============================================"
echo "🧪 API Gateway 라우팅 테스트"
echo "============================================"
echo ""

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Gateway URL
GATEWAY_URL="http://localhost:8080"

echo -e "${BLUE}📋 1. 설정된 라우트 확인${NC}"
echo "-------------------------------------------"
docker exec spring-gateway wget -qO- http://localhost:8080/actuator/gateway/routes 2>/dev/null | python3 -m json.tool || echo "Gateway routes 엔드포인트를 사용할 수 없습니다. 컨테이너를 재시작해주세요."
echo ""

echo -e "${BLUE}📋 2. Health Check 테스트${NC}"
echo "-------------------------------------------"
HEALTH=$(docker exec spring-gateway wget -qO- http://localhost:8080/actuator/health 2>/dev/null)
echo "$HEALTH" | python3 -m json.tool
if echo "$HEALTH" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✅ Health Check: 정상${NC}"
else
    echo -e "${RED}❌ Health Check: 실패${NC}"
fi
echo ""

echo -e "${BLUE}📋 3. Search Service 라우팅 테스트${NC}"
echo "   경로: /search/** → search-service"
echo "-------------------------------------------"
echo "요청: GET $GATEWAY_URL/search/api/test"
SEARCH_RESPONSE=$(docker exec spring-gateway wget -S -O- http://localhost:8080/search/api/test 2>&1)
SEARCH_CODE=$(echo "$SEARCH_RESPONSE" | grep "HTTP/" | awk '{print $2}')

if [ "$SEARCH_CODE" = "503" ] || [ "$SEARCH_CODE" = "504" ]; then
    echo -e "${YELLOW}⚠️  Backend 서비스가 없어서 Circuit Breaker Fallback 작동 (예상됨)${NC}"
    echo "응답 코드: $SEARCH_CODE"
    echo "$SEARCH_RESPONSE" | tail -5
elif [ "$SEARCH_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Search Service 라우팅 성공${NC}"
    echo "$SEARCH_RESPONSE" | tail -10
else
    echo -e "${RED}❌ 예상치 못한 응답: $SEARCH_CODE${NC}"
    echo "$SEARCH_RESPONSE" | tail -10
fi
echo ""

echo -e "${BLUE}📋 4. Payment Service 라우팅 테스트${NC}"
echo "   경로: /payment/** → payment-service"
echo "-------------------------------------------"
echo "요청: GET $GATEWAY_URL/payment/api/test"
PAYMENT_RESPONSE=$(docker exec spring-gateway wget -S -O- http://localhost:8080/payment/api/test 2>&1)
PAYMENT_CODE=$(echo "$PAYMENT_RESPONSE" | grep "HTTP/" | awk '{print $2}')

if [ "$PAYMENT_CODE" = "503" ] || [ "$PAYMENT_CODE" = "504" ]; then
    echo -e "${YELLOW}⚠️  Backend 서비스가 없어서 Circuit Breaker Fallback 작동 (예상됨)${NC}"
    echo "응답 코드: $PAYMENT_CODE"
    echo "$PAYMENT_RESPONSE" | tail -5
elif [ "$PAYMENT_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Payment Service 라우팅 성공${NC}"
    echo "$PAYMENT_RESPONSE" | tail -10
else
    echo -e "${RED}❌ 예상치 못한 응답: $PAYMENT_CODE${NC}"
    echo "$PAYMENT_RESPONSE" | tail -10
fi
echo ""

echo -e "${BLUE}📋 5. Fallback 엔드포인트 직접 테스트${NC}"
echo "-------------------------------------------"
echo "요청: GET $GATEWAY_URL/fallback/search"
FALLBACK_SEARCH=$(docker exec spring-gateway wget -qO- http://localhost:8080/fallback/search 2>/dev/null)
if echo "$FALLBACK_SEARCH" | grep -q "Search Service Unavailable"; then
    echo -e "${GREEN}✅ Search Fallback: 정상${NC}"
    echo "응답: $FALLBACK_SEARCH"
else
    echo -e "${RED}❌ Search Fallback: 실패${NC}"
    echo "응답: $FALLBACK_SEARCH"
fi

echo ""
echo "요청: GET $GATEWAY_URL/fallback/payment"
FALLBACK_PAYMENT=$(docker exec spring-gateway wget -qO- http://localhost:8080/fallback/payment 2>/dev/null)
if echo "$FALLBACK_PAYMENT" | grep -q "Payment Service Unavailable"; then
    echo -e "${GREEN}✅ Payment Fallback: 정상${NC}"
    echo "응답: $FALLBACK_PAYMENT"
else
    echo -e "${RED}❌ Payment Fallback: 실패${NC}"
    echo "응답: $FALLBACK_PAYMENT"
fi
echo ""

echo -e "${BLUE}📋 6. Gateway 헤더 확인${NC}"
echo "   X-Gateway, X-Gateway-Version 헤더 추가 확인"
echo "-------------------------------------------"
HEADERS=$(docker exec spring-gateway wget -S -O /dev/null http://localhost:8080/actuator/health 2>&1)
if echo "$HEADERS" | grep -q "X-Gateway"; then
    echo -e "${GREEN}✅ Gateway 헤더 추가됨:${NC}"
    echo "$HEADERS" | grep -i "x-gateway"
else
    echo -e "${YELLOW}⚠️  Gateway 헤더를 찾을 수 없습니다${NC}"
fi
echo ""

echo -e "${BLUE}📋 7. Rate Limiting 테스트 (5회 연속 요청)${NC}"
echo "   설정: 100 req/s (burst: 200)${NC}"
echo "-------------------------------------------"
SUCCESS=0
RATE_LIMITED=0

for i in {1..5}; do
    RESPONSE=$(docker exec spring-gateway wget -S -O- http://localhost:8080/actuator/health 2>&1)
    if echo "$RESPONSE" | grep -q "429\|Too Many Requests"; then
        RATE_LIMITED=$((RATE_LIMITED + 1))
    else
        SUCCESS=$((SUCCESS + 1))
    fi
    sleep 0.1
done

echo "성공: $SUCCESS, Rate Limited: $RATE_LIMITED"
if [ $RATE_LIMITED -gt 0 ]; then
    echo -e "${GREEN}✅ Rate Limiting 작동 확인${NC}"
else
    echo -e "${YELLOW}⚠️  Rate Limiting이 작동하지 않음 (정상 범위 내 요청)${NC}"
fi
echo ""

echo "============================================"
echo "✅ 라우팅 테스트 완료"
echo "============================================"
