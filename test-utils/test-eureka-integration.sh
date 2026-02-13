#!/bin/bash

# Blue Bank Eureka 통합 테스트 스크립트

echo "========================================="
echo "Blue Bank Eureka Integration Test"
echo "========================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check service
check_service() {
    local url=$1
    local name=$2

    response=$(curl -s -o /dev/null -w "%{http_code}" $url)
    if [ "$response" == "200" ]; then
        echo -e "${GREEN}✓ $name is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $name is not responding (HTTP $response)${NC}"
        return 1
    fi
}

# Function to check Eureka registration
check_eureka_registration() {
    local service=$1

    response=$(curl -s http://localhost:8761/eureka/apps/$service)
    if [[ $response == *"<app>"* ]]; then
        echo -e "${GREEN}✓ $service is registered in Eureka${NC}"
        return 0
    else
        echo -e "${RED}✗ $service is NOT registered in Eureka${NC}"
        return 1
    fi
}

echo -e "\n${YELLOW}1. Checking Service Health...${NC}"
check_service "http://localhost:8761/actuator/health" "Eureka Server"
check_service "http://localhost:8080/actuator/health" "API Gateway"
check_service "http://localhost:8081/actuator/health" "Account Service"
check_service "http://localhost:8084/actuator/health" "Deposit Service"
check_service "http://localhost:8082/actuator/health" "Loan Service"
check_service "http://localhost:8083/actuator/health" "Card Service"

echo -e "\n${YELLOW}2. Checking Eureka Registration...${NC}"
check_eureka_registration "API-GATEWAY"
check_eureka_registration "ACCOUNT"
check_eureka_registration "DEPOSIT"
check_eureka_registration "LOAN"
check_eureka_registration "CARD"

echo -e "\n${YELLOW}3. Testing Gateway Routes...${NC}"

# Test Account Service through Gateway
echo -n "Testing Account Service via Gateway: "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/accounts)
if [ "$response" == "200" ] || [ "$response" == "404" ] || [ "$response" == "405" ]; then
    echo -e "${GREEN}✓ Route working (HTTP $response)${NC}"
else
    echo -e "${RED}✗ Route failed (HTTP $response)${NC}"
fi

# Test Deposit Service through Gateway
echo -n "Testing Deposit Service via Gateway: "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/deposits)
if [ "$response" == "200" ] || [ "$response" == "404" ] || [ "$response" == "405" ]; then
    echo -e "${GREEN}✓ Route working (HTTP $response)${NC}"
else
    echo -e "${RED}✗ Route failed (HTTP $response)${NC}"
fi

# Test Loan Service through Gateway
echo -n "Testing Loan Service via Gateway: "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/loans)
if [ "$response" == "200" ] || [ "$response" == "404" ] || [ "$response" == "405" ]; then
    echo -e "${GREEN}✓ Route working (HTTP $response)${NC}"
else
    echo -e "${RED}✗ Route failed (HTTP $response)${NC}"
fi

# Test Card Service through Gateway
echo -n "Testing Card Service via Gateway: "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/cards)
if [ "$response" == "200" ] || [ "$response" == "404" ] || [ "$response" == "405" ]; then
    echo -e "${GREEN}✓ Route working (HTTP $response)${NC}"
else
    echo -e "${RED}✗ Route failed (HTTP $response)${NC}"
fi

echo -e "\n${YELLOW}4. Gateway Routes Information...${NC}"
echo "Fetching configured routes from Gateway..."
curl -s http://localhost:8080/actuator/gateway/routes | python3 -m json.tool 2>/dev/null | head -20

echo -e "\n${GREEN}========================================="
echo "Test Complete!"
echo "=========================================${NC}"

echo -e "\n${YELLOW}Useful URLs:${NC}"
echo "- Eureka Dashboard: http://localhost:8761"
echo "- Gateway Routes: http://localhost:8080/actuator/gateway/routes"
echo "- Eureka Apps: http://localhost:8761/eureka/apps"