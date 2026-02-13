package com.socoolheeya.bluebank.filter

import org.springframework.cloud.gateway.filter.GatewayFilterChain
import org.springframework.cloud.gateway.filter.GlobalFilter
import org.springframework.context.annotation.Primary
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.stereotype.Component
import org.springframework.web.server.ServerWebExchange
import reactor.core.publisher.Mono

@Primary
@Component
class RateLimitExceededFilter: GlobalFilter {
    override fun filter(exchange: ServerWebExchange,
                        chain: GatewayFilterChain): Mono<Void> {
        if (exchange.response.statusCode == HttpStatus.TOO_MANY_REQUESTS) {
            exchange.response.headers.contentType = MediaType.APPLICATION_JSON
            val body = """
                {
                    "code": "RATE_LIMIT_EXCEEDED",
                    "message": "요청이 너무 많습니다. 잠시 후 다시 시도해주세요"
                }
            """.trimIndent()

            val buffer = exchange.response.bufferFactory()
                .wrap(body.toByteArray())

            return exchange.response.writeWith(Mono.just(buffer))
        }

        return chain.filter(exchange)
    }
}