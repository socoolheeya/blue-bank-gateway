#!/bin/bash

# Blue Bank 전체 서비스 종료 스크립트

echo "========================================="
echo "Stopping Blue Bank Microservices System"
echo "========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read PIDs from file
if [ -f .pids ]; then
    source .pids

    echo -e "\n${YELLOW}Stopping services...${NC}"

    # Stop Card Service
    if [ ! -z "$CARD_PID" ]; then
        echo "Stopping Card Service (PID: $CARD_PID)..."
        kill $CARD_PID 2>/dev/null
        echo -e "${GREEN}✓ Card Service stopped${NC}"
    fi

    # Stop Loan Service
    if [ ! -z "$LOAN_PID" ]; then
        echo "Stopping Loan Service (PID: $LOAN_PID)..."
        kill $LOAN_PID 2>/dev/null
        echo -e "${GREEN}✓ Loan Service stopped${NC}"
    fi

    # Stop Deposit Service
    if [ ! -z "$DEPOSIT_PID" ]; then
        echo "Stopping Deposit Service (PID: $DEPOSIT_PID)..."
        kill $DEPOSIT_PID 2>/dev/null
        echo -e "${GREEN}✓ Deposit Service stopped${NC}"
    fi

    # Stop Account Service
    if [ ! -z "$ACCOUNT_PID" ]; then
        echo "Stopping Account Service (PID: $ACCOUNT_PID)..."
        kill $ACCOUNT_PID 2>/dev/null
        echo -e "${GREEN}✓ Account Service stopped${NC}"
    fi

    # Stop Gateway
    if [ ! -z "$GATEWAY_PID" ]; then
        echo "Stopping API Gateway (PID: $GATEWAY_PID)..."
        kill $GATEWAY_PID 2>/dev/null
        echo -e "${GREEN}✓ API Gateway stopped${NC}"
    fi

    # Stop Eureka Server
    if [ ! -z "$EUREKA_PID" ]; then
        echo "Stopping Eureka Server (PID: $EUREKA_PID)..."
        kill $EUREKA_PID 2>/dev/null
        echo -e "${GREEN}✓ Eureka Server stopped${NC}"
    fi

    # Clean up PID file
    rm .pids

    echo -e "\n${GREEN}All services stopped successfully!${NC}"
else
    echo -e "${RED}PID file not found. Services may not be running or were started differently.${NC}"
    echo -e "${YELLOW}You can manually stop services using:${NC}"
    echo "ps aux | grep gradle"
    echo "kill <PID>"
fi

# Alternative: Kill all gradle processes (commented out for safety)
# echo -e "\n${YELLOW}Killing all gradle processes...${NC}"
# pkill -f gradle