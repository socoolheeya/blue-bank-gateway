#!/bin/bash

# Blue Bank 서비스들을 재시작 (기존 컨테이너 정리 후 새로 시작)

NETWORK="blue-bank-gateway_gateway-network"
BLUE_BANK_PATH="/Users/wonhee.lee/IdeaProjects/blue-bank"

# 각 서비스별 인스턴스 수 설정 (환경 변수로 오버라이드 가능)
ACCOUNT_INSTANCES=${ACCOUNT_INSTANCES:-3}
DEPOSIT_INSTANCES=${DEPOSIT_INSTANCES:-5}
LOAN_INSTANCES=${LOAN_INSTANCES:-6}
CARD_INSTANCES=${CARD_INSTANCES:-7}

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 사용법
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  --build         이미지를 다시 빌드"
    echo "  --fast          대기 시간 단축 (30초)"
    echo "  --no-wait       대기 없이 즉시 완료"
    echo "  -h, --help      도움말 표시"
    echo ""
    echo "환경 변수로 인스턴스 수 조정:"
    echo "  ACCOUNT_INSTANCES=5 DEPOSIT_INSTANCES=10 $0"
    echo ""
    echo "기본값:"
    echo "  Account: ${ACCOUNT_INSTANCES}개"
    echo "  Deposit: ${DEPOSIT_INSTANCES}개"
    echo "  Loan: ${LOAN_INSTANCES}개"
    echo "  Card: ${CARD_INSTANCES}개"
}

# 옵션 파싱
BUILD_FLAG=false
WAIT_TIME=120
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_FLAG=true
            shift
            ;;
        --fast)
            WAIT_TIME=30
            shift
            ;;
        --no-wait)
            WAIT_TIME=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🔄 Blue Bank 서비스 재시작 (Restart)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}📊 인스턴스 설정:${NC}"
echo -e "  ${CYAN}●${NC} Account Service: ${ACCOUNT_INSTANCES}개 (포트: 8100-8199)"
echo -e "  ${GREEN}●${NC} Deposit Service: ${DEPOSIT_INSTANCES}개 (포트: 8200-8299)"
echo -e "  ${YELLOW}●${NC} Loan Service: ${LOAN_INSTANCES}개 (포트: 8300-8399)"
echo -e "  ${MAGENTA}●${NC} Card Service: ${CARD_INSTANCES}개 (포트: 8400-8499)"
echo ""

# STEP 1: 기존 컨테이너 정리
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 1: 기존 컨테이너 정리${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 각 서비스별로 정리
services=("account" "deposit" "loan" "card")
for service in "${services[@]}"; do
    count=$(docker ps -a --filter "name=${service}-service-" --format "{{.Names}}" | wc -l)
    if [ $count -gt 0 ]; then
        echo -e "  ${RED}▶${NC} ${service^} Service: ${count}개 컨테이너 중지..."
        docker ps -a --filter "name=${service}-service-" --format "{{.Names}}" | while read container; do
            docker stop $container >/dev/null 2>&1 &
        done
        wait
        docker ps -a --filter "name=${service}-service-" --format "{{.Names}}" | while read container; do
            docker rm $container >/dev/null 2>&1
        done
        echo -e "    ${GREEN}✓${NC} 완료"
    else
        echo -e "  ${GREEN}✓${NC} ${service^} Service: 정리할 컨테이너 없음"
    fi
done

echo ""

# STEP 2: 이미지 빌드 (옵션)
if [ "$BUILD_FLAG" = true ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}STEP 2: 서비스 이미지 빌드${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    for service in "${services[@]}"; do
        echo -e "  ${BLUE}▶${NC} ${service^} Service 빌드..."
        cd $BLUE_BANK_PATH/app/$service
        ./gradlew clean bootJar >/dev/null 2>&1
        docker build -t blue-bank-${service}-service . >/dev/null 2>&1
        echo -e "    ${GREEN}✓${NC} 완료"
    done
    echo ""
fi

# STEP 3: 새 컨테이너 시작
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}STEP 3: 새 컨테이너 시작${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Account Service (포트 8100-8199)
echo -e "  ${CYAN}▶${NC} Account Service ${ACCOUNT_INSTANCES}개 인스턴스 시작..."
for i in $(seq 1 $ACCOUNT_INSTANCES); do
    PORT=$((8099 + i))
    docker run -d \
      --name account-service-$i \
      --network $NETWORK \
      -p $PORT:$PORT \
      -e SERVER_PORT=$PORT \
      -e SPRING_APPLICATION_NAME=account \
      -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka-server:8761/eureka \
      -e EUREKA_INSTANCE_PREFER_IP_ADDRESS=true \
      -e EUREKA_INSTANCE_INSTANCE_ID=account-${i}:${PORT} \
      blue-bank-account-service:latest >/dev/null 2>&1
    echo -e "    ${GREEN}✓${NC} Instance $i (Port: $PORT)"
done

# Deposit Service (포트 8200-8299)
echo -e "  ${GREEN}▶${NC} Deposit Service ${DEPOSIT_INSTANCES}개 인스턴스 시작..."
for i in $(seq 1 $DEPOSIT_INSTANCES); do
    PORT=$((8199 + i))
    docker run -d \
      --name deposit-service-$i \
      --network $NETWORK \
      -p $PORT:$PORT \
      -e SERVER_PORT=$PORT \
      -e SPRING_APPLICATION_NAME=deposit \
      -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka-server:8761/eureka \
      -e EUREKA_INSTANCE_PREFER_IP_ADDRESS=true \
      -e EUREKA_INSTANCE_INSTANCE_ID=deposit-${i}:${PORT} \
      blue-bank-deposit-service:latest >/dev/null 2>&1
    echo -e "    ${GREEN}✓${NC} Instance $i (Port: $PORT)"
done

# Loan Service (포트 8300-8399)
echo -e "  ${YELLOW}▶${NC} Loan Service ${LOAN_INSTANCES}개 인스턴스 시작..."
for i in $(seq 1 $LOAN_INSTANCES); do
    PORT=$((8299 + i))
    docker run -d \
      --name loan-service-$i \
      --network $NETWORK \
      -p $PORT:$PORT \
      -e SERVER_PORT=$PORT \
      -e SPRING_APPLICATION_NAME=loan \
      -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka-server:8761/eureka \
      -e EUREKA_INSTANCE_PREFER_IP_ADDRESS=true \
      -e EUREKA_INSTANCE_INSTANCE_ID=loan-${i}:${PORT} \
      blue-bank-loan-service:latest >/dev/null 2>&1
    echo -e "    ${GREEN}✓${NC} Instance $i (Port: $PORT)"
done

# Card Service (포트 8400-8499)
echo -e "  ${MAGENTA}▶${NC} Card Service ${CARD_INSTANCES}개 인스턴스 시작..."
for i in $(seq 1 $CARD_INSTANCES); do
    PORT=$((8399 + i))
    docker run -d \
      --name card-service-$i \
      --network $NETWORK \
      -p $PORT:$PORT \
      -e SERVER_PORT=$PORT \
      -e SPRING_APPLICATION_NAME=card \
      -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka-server:8761/eureka \
      -e EUREKA_INSTANCE_PREFER_IP_ADDRESS=true \
      -e EUREKA_INSTANCE_INSTANCE_ID=card-${i}:${PORT} \
      blue-bank-card-service:latest >/dev/null 2>&1
    echo -e "    ${GREEN}✓${NC} Instance $i (Port: $PORT)"
done

echo ""

# STEP 4: Eureka 등록 대기 및 확인
if [ $WAIT_TIME -gt 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}STEP 4: Eureka 등록 대기${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -ne "  ⏳ 서비스 등록 대기 중"
    for i in $(seq 1 $WAIT_TIME); do
        echo -ne "."
        sleep 1
    done
    echo -e " ${GREEN}완료!${NC}"
    echo ""

    # Eureka 등록 확인
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}STEP 5: 등록 상태 확인${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    for service in "${services[@]}"; do
        SERVICE_UPPER=$(echo $service | tr '[:lower:]' '[:upper:]')
        count=$(curl -s http://localhost:8761/eureka/apps/$SERVICE_UPPER 2>/dev/null | grep -c "<instanceId>")
        echo -e "  ${GREEN}●${NC} $SERVICE_UPPER: ${count}개 인스턴스 등록됨"
    done
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}        ✅ 재시작 완료!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📊 최종 상태:${NC}"

# 실행 중인 컨테이너 수 확인
total=0
for service in "${services[@]}"; do
    count=$(docker ps --filter "name=${service}-service-" --format "{{.Names}}" | wc -l)
    total=$((total + count))
    case $service in
        account) color=$CYAN ;;
        deposit) color=$GREEN ;;
        loan) color=$YELLOW ;;
        card) color=$MAGENTA ;;
    esac
    echo -e "  ${color}●${NC} ${service^}: ${count}개 실행 중"
done
echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${BLUE}합계: ${total}개 인스턴스${NC}"

echo ""
echo -e "${CYAN}🔍 확인 URL:${NC}"
echo "  • Eureka Dashboard: http://localhost:8761"
echo "  • Gateway Health: http://localhost:8080/actuator/health"
echo "  • Gateway Routes: http://localhost:8080/actuator/gateway/routes"
echo ""
echo -e "${CYAN}🧪 테스트 명령:${NC}"
echo "  ./scripts/quick-test.sh"
echo "  ./scripts/monitor.sh"