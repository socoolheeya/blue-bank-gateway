#!/bin/bash

# Blue Bank 서비스 매니저 - 인스턴스 수를 자유롭게 조정 가능

NETWORK="blue-bank-gateway_gateway-network"
BLUE_BANK_PATH="/Users/wonhee.lee/IdeaProjects/blue-bank"

# 서비스별 포트 범위
# ACCOUNT: 8081 ~ 8089
# DEPOSIT: 8101 ~ 8199
# LOAN: 8201 ~ 8299
# CARD: 8301 ~ 8399

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 사용법 출력
usage() {
    echo "사용법: $0 [명령] [옵션]"
    echo ""
    echo "명령:"
    echo "  start [service] [count]   - 특정 서비스의 인스턴스를 N개 시작"
    echo "  stop [service] [count]     - 특정 서비스의 인스턴스를 N개 중지"
    echo "  restart [service] [count]  - 특정 서비스를 재시작"
    echo "  scale [service] [count]    - 특정 서비스를 정확히 N개로 조정"
    echo "  status                     - 모든 서비스 상태 확인"
    echo "  stop-all                   - 모든 서비스 중지"
    echo "  start-all [count]          - 모든 서비스를 각각 N개씩 시작 (기본: 3)"
    echo "  build                      - 모든 서비스 이미지 빌드"
    echo ""
    echo "서비스:"
    echo "  account - Account Service (포트: 8081-8089)"
    echo "  deposit - Deposit Service (포트: 8101-8199)"
    echo "  loan    - Loan Service (포트: 8201-8299)"
    echo "  card    - Card Service (포트: 8301-8399)"
    echo ""
    echo "예제:"
    echo "  $0 start account 5        # Account 서비스 5개 인스턴스 시작"
    echo "  $0 scale deposit 10       # Deposit 서비스를 정확히 10개로 조정"
    echo "  $0 stop loan 3            # Loan 서비스 3개 인스턴스 중지"
    echo "  $0 status                 # 모든 서비스 상태 확인"
    echo "  $0 start-all 5            # 모든 서비스를 각각 5개씩 시작"
}

# 서비스별 포트 범위 가져오기
get_port_range() {
    case $1 in
        account) echo "8100:8199" ;;
        deposit) echo "8200:8299" ;;
        loan) echo "8300:8399" ;;
        card) echo "8400:8499" ;;
        *) echo "0:0" ;;
    esac
}

# 서비스별 기본 포트 가져오기
get_base_port() {
    case $1 in
        account) echo 8099 ;;  # 8100부터 시작하도록 8099로 설정
        deposit) echo 8199 ;;  # 8200부터 시작
        loan) echo 8299 ;;     # 8300부터 시작
        card) echo 8399 ;;     # 8400부터 시작
        *) echo 0 ;;
    esac
}

# 서비스 이미지 이름 가져오기
get_image_name() {
    case $1 in
        account) echo "blue-bank-account-service:latest" ;;
        deposit) echo "blue-bank-deposit-service:latest" ;;
        loan) echo "blue-bank-loan-service:latest" ;;
        card) echo "blue-bank-card-service:latest" ;;
        *) echo "" ;;
    esac
}

# 현재 실행 중인 인스턴스 수 확인
get_running_count() {
    service=$1
    docker ps --filter "name=${service}-service-" --format "{{.Names}}" | wc -l
}

# 다음 사용 가능한 인스턴스 번호 찾기
get_next_instance_number() {
    service=$1
    base_port=$(get_base_port $service)

    for i in $(seq 1 99); do
        container_name="${service}-service-${i}"
        if ! docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
            echo $i
            return
        fi
    done
    echo 0
}

# 서비스 시작
start_service() {
    service=$1
    count=${2:-1}
    base_port=$(get_base_port $service)
    image=$(get_image_name $service)

    if [ -z "$image" ]; then
        echo -e "${RED}❌ 잘못된 서비스 이름: $service${NC}"
        return 1
    fi

    service_upper=$(echo $service | tr '[:lower:]' '[:upper:]')
    echo -e "${BLUE}🚀 ${service_upper} Service ${count}개 인스턴스 시작...${NC}"

    started=0
    for j in $(seq 1 $count); do
        instance_num=$(get_next_instance_number $service)
        if [ $instance_num -eq 0 ]; then
            echo -e "${RED}❌ 더 이상 인스턴스를 생성할 수 없습니다 (최대 99개)${NC}"
            break
        fi

        port=$((base_port + instance_num))
        container_name="${service}-service-${instance_num}"

        echo -e "  ${GREEN}→ Instance ${instance_num} (Port: ${port})${NC}"

        docker run -d \
            --name ${container_name} \
            --network $NETWORK \
            -p ${port}:${port} \
            -e SERVER_PORT=${port} \
            -e SPRING_APPLICATION_NAME=${service} \
            -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka-server:8761/eureka \
            -e EUREKA_INSTANCE_PREFER_IP_ADDRESS=true \
            -e EUREKA_INSTANCE_INSTANCE_ID=${service}-${instance_num}:${port} \
            ${image} > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            ((started++))
        else
            echo -e "${RED}    ❌ 시작 실패${NC}"
        fi
    done

    echo -e "${GREEN}✅ ${started}개 인스턴스가 시작되었습니다${NC}"
}

# 서비스 중지
stop_service() {
    service=$1
    count=${2:-1}

    service_upper=$(echo $service | tr '[:lower:]' '[:upper:]')
    echo -e "${YELLOW}🛑 ${service_upper} Service ${count}개 인스턴스 중지...${NC}"

    # 실행 중인 인스턴스 목록 가져오기
    instances=$(docker ps --filter "name=${service}-service-" --format "{{.Names}}" | head -n $count)

    stopped=0
    for instance in $instances; do
        echo -e "  ${YELLOW}→ Stopping ${instance}${NC}"
        docker stop ${instance} > /dev/null 2>&1
        docker rm ${instance} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            ((stopped++))
        fi
    done

    echo -e "${GREEN}✅ ${stopped}개 인스턴스가 중지되었습니다${NC}"
}

# 서비스를 특정 수로 스케일
scale_service() {
    service=$1
    target_count=${2:-1}

    current_count=$(get_running_count $service)

    service_upper=$(echo $service | tr '[:lower:]' '[:upper:]')
    echo -e "${BLUE}📊 ${service_upper} Service 스케일링: ${current_count} → ${target_count}${NC}"

    if [ $current_count -lt $target_count ]; then
        # 스케일 업
        to_start=$((target_count - current_count))
        start_service $service $to_start
    elif [ $current_count -gt $target_count ]; then
        # 스케일 다운
        to_stop=$((current_count - target_count))
        stop_service $service $to_stop
    else
        echo -e "${GREEN}✅ 이미 ${target_count}개 인스턴스가 실행 중입니다${NC}"
    fi
}

# 서비스 상태 확인
check_status() {
    echo -e "${BLUE}📊 Blue Bank 서비스 상태${NC}"
    echo "=================================="

    services=("account" "deposit" "loan" "card")

    for service in "${services[@]}"; do
        count=$(get_running_count $service)
        port_range=$(get_port_range $service)

        if [ $count -gt 0 ]; then
            service_upper=$(echo $service | tr '[:lower:]' '[:upper:]')
            echo -e "${GREEN}● ${service_upper} Service${NC}: ${count}개 실행 중 (포트 범위: ${port_range})"

            # 실행 중인 인스턴스 상세 정보
            docker ps --filter "name=${service}-service-" --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}" | tail -n +1
        else
            service_upper=$(echo $service | tr '[:lower:]' '[:upper:]')
            echo -e "${RED}○ ${service_upper} Service${NC}: 실행 중인 인스턴스 없음 (포트 범위: ${port_range})"
        fi
        echo ""
    done

    # Eureka 등록 상태 확인
    echo -e "${BLUE}🔍 Eureka 등록 상태:${NC}"
    curl -s http://localhost:8761/eureka/apps | grep "<app>" | sed 's/<[^>]*>//g' | sed 's/^[ \t]*//' | sort | uniq | while read app; do
        count=$(curl -s http://localhost:8761/eureka/apps/$app | grep -c "<instanceId>")
        echo "  - $app: ${count}개 인스턴스"
    done
}

# 모든 서비스 중지
stop_all() {
    echo -e "${YELLOW}🛑 모든 Blue Bank 서비스 인스턴스 중지...${NC}"

    services=("account" "deposit" "loan" "card")

    for service in "${services[@]}"; do
        count=$(get_running_count $service)
        if [ $count -gt 0 ]; then
            stop_service $service $count
        fi
    done

    echo -e "${GREEN}✅ 모든 서비스가 중지되었습니다${NC}"
}

# 모든 서비스 시작
start_all() {
    count=${1:-3}

    echo -e "${BLUE}🚀 모든 Blue Bank 서비스를 각각 ${count}개씩 시작...${NC}"

    services=("account" "deposit" "loan" "card")

    for service in "${services[@]}"; do
        start_service $service $count
        echo ""
    done

    echo -e "${GREEN}✅ 모든 서비스가 시작되었습니다${NC}"
}

# 서비스 이미지 빌드
build_services() {
    echo -e "${BLUE}🔨 Blue Bank 서비스 이미지 빌드...${NC}"

    services=("account" "deposit" "loan" "card")

    for service in "${services[@]}"; do
        service_upper=$(echo $service | tr '[:lower:]' '[:upper:]')
        echo -e "${YELLOW}Building ${service_upper} Service...${NC}"
        cd $BLUE_BANK_PATH/app/$service
        ./gradlew clean bootJar
        docker build -t blue-bank-${service}-service .
        echo ""
    done

    echo -e "${GREEN}✅ 모든 이미지 빌드 완료${NC}"
}

# 메인 실행 로직
case "$1" in
    start)
        start_service $2 $3
        ;;
    stop)
        stop_service $2 $3
        ;;
    restart)
        service=$2
        count=${3:-$(get_running_count $2)}
        stop_service $service $count
        sleep 2
        start_service $service $count
        ;;
    scale)
        scale_service $2 $3
        ;;
    status)
        check_status
        ;;
    stop-all)
        stop_all
        ;;
    start-all)
        start_all $2
        ;;
    build)
        build_services
        ;;
    *)
        usage
        exit 1
        ;;
esac