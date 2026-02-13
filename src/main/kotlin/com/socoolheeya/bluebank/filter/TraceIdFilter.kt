package com.socoolheeya.bluebank.filter

import org.springframework.cloud.gateway.filter.GatewayFilterChain
import org.springframework.cloud.gateway.filter.GlobalFilter
import org.springframework.core.Ordered
import org.springframework.stereotype.Component
import org.springframework.web.server.ServerWebExchange
import reactor.core.publisher.Mono
import java.util.UUID

@Component
class TraceIdFilter: GlobalFilter, Ordered {
    override fun filter(exchange: ServerWebExchange,
                        chain: GatewayFilterChain): Mono<Void> {
        val traceId = exchange.request.headers
            .getFirst("X-Trace-Id")
            ?: UUID.randomUUID().toString()

        val request = exchange.request.mutate()
            .header("X-Trace-Id", traceId)
            .build()

        return chain.filter(exchange.mutate().request(request).build())
    }

    override fun getOrder(): Int {
        return -200
    }
}