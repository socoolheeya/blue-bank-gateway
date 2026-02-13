package com.socoolheeya.bluebank.filter

import org.slf4j.LoggerFactory
import org.springframework.cloud.gateway.filter.GatewayFilterChain
import org.springframework.cloud.gateway.filter.GlobalFilter
import org.springframework.core.Ordered
import org.springframework.stereotype.Component
import org.springframework.web.server.ServerWebExchange
import reactor.core.publisher.Mono

@Component
class AccessLogFilter: GlobalFilter, Ordered {

    private val log = LoggerFactory.getLogger("AccessLogFilter")

    override fun filter(exchange: ServerWebExchange,
                        chain: GatewayFilterChain): Mono<Void> {
        val start = System.nanoTime()

        val request = exchange.request
        val traceId = request.headers.getFirst("X-Trace-Id") ?: "N/A"
        val userId = request.headers.getFirst("X-User-Id") ?: "anonymous"
        val clientIp = request.headers.getFirst("X-Forwarded-For")
            ?: request.remoteAddress?.address?.hostAddress
            ?: "Unknown"

        return chain.filter(exchange).doFinally {
            val elapsed = (System.nanoTime() - start) / 1000000

            log.info("traceId=$traceId " +
                    "method=${request.method} " +
                    "path=${request.uri.path} " +
                    "status=${exchange.response.statusCode} " +
                    "latency=${elapsed}ms " +
                    "userId=$userId " +
                    "clientIp=$clientIp")
        }
    }

    override fun getOrder(): Int {
        return Ordered.LOWEST_PRECEDENCE
    }
}