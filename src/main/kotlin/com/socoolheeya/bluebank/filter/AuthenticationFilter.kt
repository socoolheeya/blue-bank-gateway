package com.socoolheeya.bluebank.filter

import com.socoolheeya.bluebank.domain.JwtProvider
import org.springframework.cloud.gateway.filter.GatewayFilterChain
import org.springframework.cloud.gateway.filter.GlobalFilter
import org.springframework.core.Ordered
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.server.ServerWebExchange
import reactor.core.publisher.Mono

@Component
class AuthenticationFilter(
    private val jwtProvider: JwtProvider
): GlobalFilter, Ordered {
    override fun filter(exchange: ServerWebExchange,
                        chain: GatewayFilterChain): Mono<Void> {
        val path = exchange.request.path.value()
        if (isPublicPath(path)) {
            return chain.filter(exchange)
        }

        val token = exchange.request.headers
            .getFirst(HttpHeaders.AUTHORIZATION)
            ?.removePrefix("Bearer ")

        if(token == null || !jwtProvider.validate(token)) {
            exchange.response.statusCode = HttpStatus.UNAUTHORIZED
            return exchange.response.setComplete()
        }

        val claims = jwtProvider.claims(token)

        val mutatedRequest = exchange.request.mutate()
            .header("X-User-Id", claims.subject)
            .header("X-User-Role", claims.get("role", String::class.java))
            .build()

        return chain.filter(exchange.mutate().request(mutatedRequest).build())

    }

    override fun getOrder(): Int {
        return -100
    }

    private fun isPublicPath(path: String): Boolean {
        return path.startsWith("/health")
            || path.startsWith("/auth")
            || path.startsWith("/payment")  // Temporary: for testing
            || path.startsWith("/search")   // Temporary: for testing
            || path.startsWith("/httpbin")  // Temporary: for testing
            || path.startsWith("/actuator") // Actuator endpoints
            || path.startsWith("/api")      // API endpoints - for testing without auth
    }

}