package com.socoolheeya.bluebank.configuration

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver
import org.springframework.cloud.gateway.filter.ratelimit.RedisRateLimiter
import org.springframework.cloud.gateway.route.RouteLocator
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class RouteConfiguration {

    @Bean
    fun redisRateLimiter(): RedisRateLimiter {
        return RedisRateLimiter(1, 1, 1)  // replenishRate=2, burstCapacity=5, requestedTokens=1
    }

    @Bean
    fun customRouteLocator(builder: RouteLocatorBuilder, redisRateLimiter: RedisRateLimiter, ipKeyResolver: KeyResolver): RouteLocator {
        return builder.routes()
            // Account Service - 계좌 관리
            .route("account-service") { r ->
                r.path("/api/accounts/**")
                    .uri("lb://ACCOUNT")  // Service Discovery를 통한 로드 밸런싱
            }
            // Deposit Service - 예금 관리
            .route("deposit-service") { r ->
                r.path("/api/deposits/**")
                    .uri("lb://DEPOSIT")  // Service Discovery를 통한 로드 밸런싱
            }
            // Loan Service - 대출 관리
            .route("loan-service") { r ->
                r.path("/api/loans/**")
                    .uri("lb://LOAN")  // Service Discovery를 통한 로드 밸런싱
            }
            // Card Service - 카드 관리
            .route("card-service") { r ->
                r.path("/api/cards/**")
                    .uri("lb://CARD")  // Service Discovery를 통한 로드 밸런싱
            }
            // Internal Account Service (for inter-service communication)
            .route("internal-account-service") { r ->
                r.path("/internal/accounts/**")
                    .filters { f ->
                        f.addRequestHeader("X-Internal-Request", "true")
                    }
                    .uri("lb://ACCOUNT")
            }
            // Test route to httpbin.org
            .route("test-route") { r ->
                r.path("/httpbin/**")
                    .filters { f -> f.stripPrefix(1) }
                    .uri("https://httpbin.org")
            }
            .build()
    }
}