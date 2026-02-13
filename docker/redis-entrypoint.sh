#!/bin/sh
# Redis 조건부 비밀번호 설정 스크립트

if [ -n "$REDIS_PASSWORD" ]; then
    echo "Starting Redis with password authentication..."
    exec redis-server --appendonly yes --requirepass "$REDIS_PASSWORD"
else
    echo "Starting Redis without password (development mode)..."
    exec redis-server --appendonly yes
fi
