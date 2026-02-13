#!/bin/bash

echo "🧪 Testing Rate Limiting on /search endpoint"
echo "=============================================="
echo ""
echo "Rate Limit Config:"
echo "  - replenishRate: 2/sec"
echo "  - burstCapacity: 1"
echo "  - requestedTokens: 1"
echo ""

PASSED=0
FAILED=0
RATE_LIMITED=0

for i in {1..10}; do
    RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost/search/test 2>&1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Request $i: HTTP $HTTP_CODE - OK"
        PASSED=$((PASSED + 1))
    elif [ "$HTTP_CODE" = "429" ]; then
        echo "🚫 Request $i: HTTP $HTTP_CODE - RATE LIMITED"
        echo "   Response: $BODY"
        RATE_LIMITED=$((RATE_LIMITED + 1))
    else
        echo "❌ Request $i: HTTP $HTTP_CODE - UNEXPECTED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=============================================="
echo "📊 Results:"
echo "  ✅ Successful: $PASSED"
echo "  🚫 Rate Limited: $RATE_LIMITED"
echo "  ❌ Failed: $FAILED"
echo ""

if [ $RATE_LIMITED -gt 0 ]; then
    echo "✅ Rate Limiting is WORKING!"
else
    echo "⚠️  No rate limiting detected"
fi
