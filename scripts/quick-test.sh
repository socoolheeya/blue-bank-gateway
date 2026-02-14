#!/bin/bash

# Blue Bank 서비스 빠른 테스트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Blue Bank 서비스 테스트${NC}"
echo "======================================"
echo ""

# 서비스 엔드포인트 테스트
services=(
    "account|/api/accounts|🏦"
    "deposit|/api/deposits|💰"
    "loan|/api/loans|💳"
    "card|/api/cards|💳"
)

for service_info in "${services[@]}"; do
    IFS='|' read -r service endpoint icon <<< "$service_info"

    echo -e "${BLUE}${icon} ${service^^} Service Test${NC}"
    echo "  Endpoint: http://localhost:8080${endpoint}"

    # 10번 요청해서 로드 밸런싱 확인
    echo -e "  ${YELLOW}10회 요청 테스트:${NC}"

    for i in {1..10}; do
        response=$(curl -s -w "||HTTP:%{http_code}||TIME:%{time_total}" http://localhost:8080${endpoint} 2>/dev/null)
        http_code=$(echo $response | grep -oP 'HTTP:\K\d+')
        response_time=$(echo $response | grep -oP 'TIME:\K[0-9.]+')

        if [ "$http_code" == "200" ]; then
            echo -e "    Request $i: ${GREEN}✓${NC} (${response_time}s)"
        else
            echo -e "    Request $i: ${RED}✗${NC} (HTTP $http_code)"
        fi
    done
    echo ""
done

# 전체 상태 요약
echo -e "${BLUE}📊 서비스 상태 요약${NC}"
echo "======================================"

for service_info in "${services[@]}"; do
    IFS='|' read -r service endpoint icon <<< "$service_info"

    # 실행 중인 인스턴스 수
    count=$(docker ps --filter "name=${service}-service-" --format "{{.Names}}" | wc -l)

    # Eureka 등록 수
    eureka_count=$(curl -s http://localhost:8761/eureka/apps/${service^^} 2>/dev/null | grep -c "<instanceId>")

    # Gateway 라우트 확인
    route_exists=$(curl -s http://localhost:8080/actuator/gateway/routes 2>/dev/null | grep -q "${service}-service" && echo "Yes" || echo "No")

    echo -e "${icon} ${service^^}:"
    echo -e "  - Docker 인스턴스: ${count}개"
    echo -e "  - Eureka 등록: ${eureka_count}개"
    echo -e "  - Gateway 라우트: ${route_exists}"
    echo ""
done

echo "======================================"
echo -e "${GREEN}✅ 테스트 완료!${NC}"