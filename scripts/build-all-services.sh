#!/bin/bash

# Blue Bank 전체 서비스 빌드 스크립트

echo "========================================="
echo "Blue Bank Microservices Build Script"
echo "========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check build status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 build successful${NC}"
    else
        echo -e "${RED}✗ $1 build failed${NC}"
        exit 1
    fi
}

# Build Eureka Server
echo -e "\n${YELLOW}Building Eureka Server...${NC}"
cd ../blue-bank-eureka-server
./gradlew clean build -x test
check_status "Eureka Server"

# Build Gateway
echo -e "\n${YELLOW}Building API Gateway...${NC}"
cd ../blue-bank-gateway
./gradlew clean build -x test
check_status "API Gateway"

# Build Account Service
echo -e "\n${YELLOW}Building Account Service...${NC}"
cd ../blue-bank/app/account
./gradlew clean build -x test
check_status "Account Service"

# Build Deposit Service
echo -e "\n${YELLOW}Building Deposit Service...${NC}"
cd ../deposit
./gradlew clean build -x test
check_status "Deposit Service"

# Build Loan Service
echo -e "\n${YELLOW}Building Loan Service...${NC}"
cd ../loan
./gradlew clean build -x test
check_status "Loan Service"

# Build Card Service
echo -e "\n${YELLOW}Building Card Service...${NC}"
cd ../card
./gradlew clean build -x test
check_status "Card Service"

# Build Docker images
echo -e "\n${YELLOW}Building Docker images...${NC}"
cd ../../../blue-bank-gateway

# Check if docker-compose-complete.yml exists
if [ -f "docker-compose-complete.yml" ]; then
    docker-compose -f docker-compose-complete.yml build
    check_status "Docker images"
else
    echo -e "${RED}docker-compose-complete.yml not found${NC}"
    exit 1
fi

echo -e "\n${GREEN}========================================="
echo "All services built successfully!"
echo "=========================================${NC}"

echo -e "\n${YELLOW}To start all services, run:${NC}"
echo "docker-compose -f docker-compose-complete.yml up -d"

echo -e "\n${YELLOW}Service URLs:${NC}"
echo "- Eureka Dashboard: http://localhost:8761"
echo "- API Gateway: http://localhost:8080"
echo "- Account Service: http://localhost:8081"
echo "- Deposit Service: http://localhost:8084"
echo "- Loan Service: http://localhost:8082"
echo "- Card Service: http://localhost:8083"