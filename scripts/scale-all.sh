#!/bin/bash

# 모든 서비스 스케일링 스크립트

if [ -z "$1" ]; then
    echo "사용법: $0 [인스턴스 수]"
    echo "예: $0 10   # 모든 서비스를 각각 10개 인스턴스로 조정"
    exit 1
fi

count=$1

echo "🚀 모든 서비스를 각각 ${count}개 인스턴스로 조정합니다..."
echo ""

./service-manager.sh scale account $count
echo ""
./service-manager.sh scale deposit $count
echo ""
./service-manager.sh scale loan $count
echo ""
./service-manager.sh scale card $count
echo ""

echo "✅ 스케일링 완료!"
./service-manager.sh status