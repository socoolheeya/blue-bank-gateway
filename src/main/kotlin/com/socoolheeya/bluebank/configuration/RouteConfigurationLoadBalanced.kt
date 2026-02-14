package com.socoolheeya.bluebank.configuration

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver
import org.springframework.cloud.gateway.filter.ratelimit.RedisRateLimiter
import org.springframework.cloud.gateway.route.RouteLocator
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Primary
import org.springframework.context.annotation.Profile

@Configuration
@Profile("lb") // 로드 밸런싱 프로파일
class RouteConfigurationLoadBalanced {

    @Bean
    fun redisRateLimiter(): RedisRateLimiter {
        return RedisRateLimiter(1, 1, 1)
    }

    @Bean
    @Primary
    fun customRouteLocator(builder: RouteLocatorBuilder, redisRateLimiter: RedisRateLimiter, ipKeyResolver: KeyResolver): RouteLocator {
        return builder.routes()
            // Account Service - 로드 밸런싱
            .route("account-service-lb") { r ->
                r.path("/api/accounts/**")
                    .filters { f ->
                        f.addRequestHeader("X-Service-Name", "ACCOUNT")
                        f.addResponseHeader("X-Instance-Id", "\${spring.cloud.gateway.route.id}")
                    }
                    .uri("lb://ACCOUNT")  // Eureka 서비스 디스커버리 + 로드 밸런싱
            }
            // Deposit Service - 로드 밸런싱
            .route("deposit-service-lb") { r ->
                r.path("/api/deposits/**")
                    .filters { f ->
                        f.addRequestHeader("X-Service-Name", "DEPOSIT")
                        f.addResponseHeader("X-Instance-Id", "\${spring.cloud.gateway.route.id}")
                    }
                    .uri("lb://DEPOSIT")  // Eureka 서비스 디스커버리 + 로드 밸런싱
            }
            // Loan Service - 로드 밸런싱
            .route("loan-service-lb") { r ->
                r.path("/api/loans/**")
                    .filters { f ->
                        f.addRequestHeader("X-Service-Name", "LOAN")
                        f.addResponseHeader("X-Instance-Id", "\${spring.cloud.gateway.route.id}")
                    }
                    .uri("lb://LOAN")  // Eureka 서비스 디스커버리 + 로드 밸런싱
            }
            // Card Service - 로드 밸런싱
            .route("card-service-lb") { r ->
                r.path("/api/cards/**")
                    .filters { f ->
                        f.addRequestHeader("X-Service-Name", "CARD")
                        f.addResponseHeader("X-Instance-Id", "\${spring.cloud.gateway.route.id}")
                    }
                    .uri("lb://CARD")  // Eureka 서비스 디스커버리 + 로드 밸런싱
            }
            // Internal Account Service
            .route("internal-account-service") { r ->
                r.path("/internal/accounts/**")
                    .filters { f ->
                        f.addRequestHeader("X-Internal-Request", "true")
                    }
                    .uri("lb://ACCOUNT")
            }
            // Test route
            .route("test-route") { r ->
                r.path("/httpbin/**")
                    .filters { f -> f.stripPrefix(1) }
                    .uri("https://httpbin.org")
            }
            .build()
    }
}