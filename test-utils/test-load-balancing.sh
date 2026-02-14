#!/bin/bash

# 로드 밸런싱 테스트 스크립트

echo "🧪 Blue Bank Gateway 로드 밸런싱 테스트"
echo "======================================"
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 각 서비스에 대한 요청 수
REQUEST_COUNT=20

# 결과 저장용 임시 파일
TEMP_FILE="/tmp/lb_test_results_$$"

echo "📊 각 서비스에 ${REQUEST_COUNT}번 요청을 보내고 응답 분석..."
echo ""

# Account Service 테스트
echo -e "${BLUE}1. Account Service 로드 밸런싱 테스트${NC}"
echo "----------------------------------------"
for i in $(seq 1 $REQUEST_COUNT); do
    response=$(curl -s -w "||PORT:%{remote_port}" http://localhost:8080/api/accounts 2>/dev/null)
    port=$(echo $response | grep -oP 'PORT:\K\d+' | tail -1)
    echo "Request $i: Port $port"
    echo $port >> ${TEMP_FILE}_account
done
echo -e "${GREEN}Account Service 인스턴스 분포:${NC}"
sort ${TEMP_FILE}_account | uniq -c | sort -nr
echo ""

# Deposit Service 테스트
echo -e "${BLUE}2. Deposit Service 로드 밸런싱 테스트${NC}"
echo "----------------------------------------"
for i in $(seq 1 $REQUEST_COUNT); do
    response=$(curl -s -w "||PORT:%{remote_port}" http://localhost:8080/api/deposits 2>/dev/null)
    port=$(echo $response | grep -oP 'PORT:\K\d+' | tail -1)
    echo "Request $i: Port $port"
    echo $port >> ${TEMP_FILE}_deposit
done
echo -e "${GREEN}Deposit Service 인스턴스 분포:${NC}"
sort ${TEMP_FILE}_deposit | uniq -c | sort -nr
echo ""

# Loan Service 테스트
echo -e "${BLUE}3. Loan Service 로드 밸런싱 테스트${NC}"
echo "----------------------------------------"
for i in $(seq 1 $REQUEST_COUNT); do
    response=$(curl -s -w "||PORT:%{remote_port}" http://localhost:8080/api/loans 2>/dev/null)
    port=$(echo $response | grep -oP 'PORT:\K\d+' | tail -1)
    echo "Request $i: Port $port"
    echo $port >> ${TEMP_FILE}_loan
done
echo -e "${GREEN}Loan Service 인스턴스 분포:${NC}"
sort ${TEMP_FILE}_loan | uniq -c | sort -nr
echo ""

# Card Service 테스트
echo -e "${BLUE}4. Card Service 로드 밸런싱 테스트${NC}"
echo "----------------------------------------"
for i in $(seq 1 $REQUEST_COUNT); do
    response=$(curl -s -w "||PORT:%{remote_port}" http://localhost:8080/api/cards 2>/dev/null)
    port=$(echo $response | grep -oP 'PORT:\K\d+' | tail -1)
    echo "Request $i: Port $port"
    echo $port >> ${TEMP_FILE}_card
done
echo -e "${GREEN}Card Service 인스턴스 분포:${NC}"
sort ${TEMP_FILE}_card | uniq -c | sort -nr
echo ""

# 정리
rm -f ${TEMP_FILE}_*

echo "======================================"
echo -e "${YELLOW}📈 로드 밸런싱 테스트 완료!${NC}"
echo ""
echo "위 결과는 각 서비스 인스턴스로 분산된 요청 수를 보여줍니다."
echo "균등한 분포는 로드 밸런싱이 제대로 작동함을 의미합니다."