package com.socoolheeya.bluebank.configuration

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver
import org.springframework.cloud.gateway.filter.ratelimit.RedisRateLimiter
import org.springframework.cloud.gateway.route.RouteLocator
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.beans.factory.annotation.Value

@Configuration
class RouteConfiguration {

    @Bean
    fun redisRateLimiter(): RedisRateLimiter {
        return RedisRateLimiter(1, 1, 1)  // replenishRate=2, burstCapacity=5, requestedTokens=1
    }

    @Bean
    fun customRouteLocator(
        builder: RouteLocatorBuilder,
        redisRateLimiter: RedisRateLimiter,
        ipKeyResolver: KeyResolver,
        @Value("\${services.account.url:http://account:8100}") accountUrl: String,
        @Value("\${services.deposit.url:http://deposit:8200}") depositUrl: String,
        @Value("\${services.loan.url:http://loan:8300}") loanUrl: String,
        @Value("\${services.card.url:http://card:8400}") cardUrl: String
    ): RouteLocator {
        fun org.springframework.cloud.gateway.route.builder.GatewayFilterSpec.policies(name: String, fallback: String) =
            requestRateLimiter { config ->
                config.setRateLimiter(redisRateLimiter)
                config.setKeyResolver(ipKeyResolver)
            }.circuitBreaker { config ->
                config.setName(name)
                config.setFallbackUri("forward:/fallback/$fallback")
            }

        return builder.routes()
            // Account Service - 계좌 관리
            .route("account-service") { r ->
                r.path("/api/accounts/**")
                    .filters { it.policies("accountCB", "account") }
                    .uri(accountUrl)
            }
            // Deposit Service - 예금 관리
            .route("deposit-service") { r ->
                r.path("/api/deposits/**")
                    .filters { it.policies("depositCB", "deposit") }
                    .uri(depositUrl)
            }
            // Loan Service - 대출 관리
            .route("loan-service") { r ->
                r.path("/api/loans/**")
                    .filters { it.policies("loanCB", "loan") }
                    .uri(loanUrl)
            }
            // Card Service - 카드 관리
            .route("card-service") { r ->
                r.path("/api/cards/**")
                    .filters { it.policies("cardCB", "card") }
                    .uri(cardUrl)
            }
            // Internal Account Service (for inter-service communication)
            .route("internal-account-service") { r ->
                r.path("/internal/accounts/**")
                    .filters { f ->
                        f.addRequestHeader("X-Internal-Request", "true")
                    }
                    .uri(accountUrl)
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
