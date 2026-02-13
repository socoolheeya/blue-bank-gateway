#!/bin/bash

# Blue Bank 전체 서비스 시작 스크립트

echo "========================================="
echo "Starting Blue Bank Microservices System"
echo "========================================="

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Start Eureka Server
echo -e "\n${YELLOW}1. Starting Eureka Server...${NC}"
cd /Users/wonhee.lee/IdeaProjects/blue-bank-eureka-server
./gradlew bootRun > eureka.log 2>&1 &
EUREKA_PID=$!
echo -e "${GREEN}Eureka Server started with PID: $EUREKA_PID${NC}"

# Wait for Eureka to start
echo "Waiting for Eureka Server to start..."
sleep 10

# Start Gateway
echo -e "\n${YELLOW}2. Starting API Gateway...${NC}"
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway
./gradlew bootRun > gateway.log 2>&1 &
GATEWAY_PID=$!
echo -e "${GREEN}API Gateway started with PID: $GATEWAY_PID${NC}"

# Wait a bit
sleep 5

# Start Account Service
echo -e "\n${YELLOW}3. Starting Account Service...${NC}"
cd /Users/wonhee.lee/IdeaProjects/blue-bank/app/account
./gradlew bootRun > account.log 2>&1 &
ACCOUNT_PID=$!
echo -e "${GREEN}Account Service started with PID: $ACCOUNT_PID${NC}"

# Start Deposit Service
echo -e "\n${YELLOW}4. Starting Deposit Service...${NC}"
cd ../deposit
./gradlew bootRun > deposit.log 2>&1 &
DEPOSIT_PID=$!
echo -e "${GREEN}Deposit Service started with PID: $DEPOSIT_PID${NC}"

# Start Loan Service
echo -e "\n${YELLOW}5. Starting Loan Service...${NC}"
cd ../loan
./gradlew bootRun > loan.log 2>&1 &
LOAN_PID=$!
echo -e "${GREEN}Loan Service started with PID: $LOAN_PID${NC}"

# Start Card Service
echo -e "\n${YELLOW}6. Starting Card Service...${NC}"
cd ../card
./gradlew bootRun > card.log 2>&1 &
CARD_PID=$!
echo -e "${GREEN}Card Service started with PID: $CARD_PID${NC}"

# Save PIDs to file for stop script
cd /Users/wonhee.lee/IdeaProjects/blue-bank-gateway
cat > .pids << EOF
EUREKA_PID=$EUREKA_PID
GATEWAY_PID=$GATEWAY_PID
ACCOUNT_PID=$ACCOUNT_PID
DEPOSIT_PID=$DEPOSIT_PID
LOAN_PID=$LOAN_PID
CARD_PID=$CARD_PID
EOF

echo -e "\n${GREEN}========================================="
echo "All services started successfully!"
echo "=========================================${NC}"

echo -e "\n${YELLOW}Service URLs:${NC}"
echo "- Eureka Dashboard: http://localhost:8761"
echo "- API Gateway: http://localhost:8080"
echo "- Account Service: http://localhost:8081 (H2: http://localhost:8081/h2-console)"
echo "- Deposit Service: http://localhost:8084 (H2: http://localhost:8084/h2-console)"
echo "- Loan Service: http://localhost:8082 (H2: http://localhost:8082/h2-console)"
echo "- Card Service: http://localhost:8083 (H2: http://localhost:8083/h2-console)"

echo -e "\n${YELLOW}To monitor logs:${NC}"
echo "tail -f eureka.log gateway.log account.log deposit.log loan.log card.log"

echo -e "\n${YELLOW}To stop all services:${NC}"
echo "./stop-all-services.sh"