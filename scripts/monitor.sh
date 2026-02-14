#!/bin/bash

# Blue Bank 서비스 실시간 모니터링

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 서비스 목록
services=("account" "deposit" "loan" "card")

# 화면 지우기 함수
clear_screen() {
    echo -e "\033[2J\033[H"
}

# 서비스 상태 확인
check_service_health() {
    service=$1
    port=$2
    curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/actuator/health 2>/dev/null
}

# 실시간 모니터링
monitor() {
    while true; do
        clear_screen

        # 헤더
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}       ${CYAN}Blue Bank Services Monitor${NC} - $(date '+%Y-%m-%d %H:%M:%S')       ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # 전체 요약
        total_instances=0
        for service in "${services[@]}"; do
            count=$(docker ps --filter "name=${service}-service-" --format "{{.Names}}" 2>/dev/null | wc -l)
            total_instances=$((total_instances + count))
        done

        echo -e "${GREEN}📊 전체 인스턴스: ${total_instances}개${NC}"
        echo ""

        # 각 서비스별 상태
        for service in "${services[@]}"; do
            case $service in
                account)
                    color=$CYAN
                    icon="🏦"
                    port_range="8081-8089"
                    ;;
                deposit)
                    color=$GREEN
                    icon="💰"
                    port_range="8101-8199"
                    ;;
                loan)
                    color=$YELLOW
                    icon="💳"
                    port_range="8201-8299"
                    ;;
                card)
                    color=$MAGENTA
                    icon="💳"
                    port_range="8301-8399"
                    ;;
            esac

            # 실행 중인 인스턴스 수 확인
            instances=$(docker ps --filter "name=${service}-service-" --format "{{.Names}}" 2>/dev/null)
            count=$(echo "$instances" | grep -c "^" 2>/dev/null || echo 0)

            # 서비스 헤더
            echo -e "${color}${icon} ${service^^} Service${NC} (포트: ${port_range})"
            echo -e "├─ 인스턴스: ${count}개 실행 중"

            if [ $count -gt 0 ]; then
                # 인스턴스 상세 정보
                echo "$instances" | while read instance; do
                    # 포트 번호 추출
                    port=$(docker port $instance 2>/dev/null | grep -oP '\d+$' | head -1)

                    # 컨테이너 상태
                    status=$(docker ps --filter "name=$instance" --format "{{.Status}}" 2>/dev/null)

                    # 메모리 사용량
                    stats=$(docker stats --no-stream --format "{{.MemUsage}}" $instance 2>/dev/null)

                    # Eureka 등록 상태
                    eureka_status="?"
                    if curl -s http://localhost:8761/eureka/apps/${service^^} 2>/dev/null | grep -q "${instance}"; then
                        eureka_status="✓"
                    else
                        eureka_status="✗"
                    fi

                    echo -e "│  ├─ ${instance} (Port: ${port})"
                    echo -e "│  │  ├─ 상태: ${status}"
                    echo -e "│  │  ├─ 메모리: ${stats}"
                    echo -e "│  │  └─ Eureka: ${eureka_status}"
                done
            else
                echo -e "│  └─ ${RED}실행 중인 인스턴스 없음${NC}"
            fi
            echo -e "└────────────────────────────────────────"
            echo ""
        done

        # Gateway 상태
        echo -e "${BLUE}🌐 Gateway Status${NC}"
        gateway_health=$(curl -s http://localhost:8080/actuator/health 2>/dev/null | grep -oP '"status":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$gateway_health" ]; then
            echo -e "├─ Health: ${GREEN}${gateway_health}${NC}"
        else
            echo -e "├─ Health: ${RED}OFFLINE${NC}"
        fi

        # Eureka 상태
        echo -e "${BLUE}📡 Eureka Status${NC}"
        eureka_apps=$(curl -s http://localhost:8761/eureka/apps 2>/dev/null | grep "<app>" | sed 's/<[^>]*>//g' | sed 's/^[ \t]*//')
        if [ -n "$eureka_apps" ]; then
            echo "$eureka_apps" | while read app; do
                count=$(curl -s http://localhost:8761/eureka/apps/$app 2>/dev/null | grep -c "<instanceId>")
                echo -e "├─ $app: ${count}개 인스턴스"
            done
        else
            echo -e "├─ ${RED}Eureka 연결 실패${NC}"
        fi

        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  [Ctrl+C]로 종료  |  5초마다 자동 새로고침"

        # 5초 대기
        sleep 5
    done
}

# Ctrl+C 처리
trap 'echo -e "\n${YELLOW}모니터링을 종료합니다...${NC}"; exit 0' INT

# 모니터링 시작
echo -e "${GREEN}Blue Bank 서비스 모니터링을 시작합니다...${NC}"
sleep 2
monitor