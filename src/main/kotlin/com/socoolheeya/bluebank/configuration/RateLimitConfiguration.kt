package com.socoolheeya.bluebank.configuration

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import reactor.core.publisher.Mono

@Configuration
class RateLimitConfiguration {

    @Bean
    fun ipKeyResolver(): KeyResolver {
        return KeyResolver { exchange ->
            val ip = exchange.request.headers.getFirst("X-Forwarded-For")
                ?: exchange.request.remoteAddress?.address?.hostAddress
                ?: "unknown"
            Mono.just(ip)
        }
    }
}