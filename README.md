# Blue Bank Gateway

Spring Cloud Gateway for Blue Bank Microservices Architecture

## 🏗️ Project Structure

```
blue-bank-gateway/
├── src/                      # Source code
├── build/                    # Build outputs
├── docker/                   # Docker configurations
│   ├── Dockerfile.simple     # Simplified Dockerfile
│   ├── docker-compose-complete.yml
│   └── redis-entrypoint.sh
├── scripts/                  # Management scripts
│   ├── build-all-services.sh
│   ├── start-all-services.sh
│   └── stop-all-services.sh
├── test-utils/              # Testing utilities
│   ├── test-eureka-integration.sh
│   ├── test-full-stack.sh
│   ├── test-ratelimit.sh
│   ├── test-routing.sh
│   ├── TestJwtGenerator.java
│   └── generate-jwt-token.kt
├── service-configs/         # Service configurations
│   └── *.yml
├── nginx/                   # Nginx configurations
├── docker-compose.yml       # Main Docker Compose
└── README.md
```

## 🚀 Quick Start

### Using Docker Compose
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down
```

### Using Scripts
```bash
# Start all services
./scripts/start-all-services.sh

# Stop all services
./scripts/stop-all-services.sh

# Run tests
./test-utils/test-routing.sh
```

## 📡 Service Endpoints

| Service | Port | Endpoint |
|---------|------|----------|
| Gateway | 8080 | http://localhost:8080 |
| Eureka | 8761 | http://localhost:8761 |
| Account | 8081 | /api/accounts |
| Deposit | 8084 | /api/deposits |
| Loan | 8082 | /api/loans |
| Card | 8083 | /api/cards |

## 🔧 Configuration

### Gateway Routes
Routes are configured in `RouteConfiguration.kt`:
- `/api/accounts/**` → Account Service
- `/api/deposits/**` → Deposit Service
- `/api/loans/**` → Loan Service
- `/api/cards/**` → Card Service

### Environment Variables
Create `.env` file:
```env
SPRING_PROFILES_ACTIVE=default
REDIS_PASSWORD=yourpassword
JWT_SECRET=your-secret-key
```

## 📚 Documentation

Additional documentation in `/docs`:
- Service integration guides
- Testing procedures
- Configuration details

## 🧪 Testing

```bash
# Test Gateway routing
curl http://localhost:8080/api/accounts

# Check service health
curl http://localhost:8080/actuator/health

# View registered routes
curl http://localhost:8080/actuator/gateway/routes
```

## 🛠️ Development

### Build
```bash
./gradlew clean build
```

### Run locally
```bash
./gradlew bootRun
```

### Run with Docker
```bash
docker build -t blue-bank-gateway .
docker run -p 8080:8080 blue-bank-gateway
```