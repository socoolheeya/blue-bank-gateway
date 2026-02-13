package com.socoolheeya.bluebank.filter

import org.springframework.cloud.gateway.filter.GatewayFilterChain
import org.springframework.cloud.gateway.filter.GlobalFilter
import org.springframework.core.Ordered
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.server.ServerWebExchange
import reactor.core.publisher.Mono

@Component
class AuthorizationFilter: GlobalFilter, Ordered {
    override fun filter(exchange: ServerWebExchange,
                        chain: GatewayFilterChain): Mono<Void> {
        val role = exchange.request.headers.getFirst("X-User-Role")

        if (exchange.request.path.value().startsWith("/api/v1/accounts") && role != "admin") {
            exchange.response.statusCode = HttpStatus.FORBIDDEN
            return exchange.response.setComplete()
        }
        return chain.filter(exchange)
    }

    override fun getOrder(): Int {
        return -90
    }
}