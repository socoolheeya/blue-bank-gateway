package com.socoolheeya.bluebank.controller

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import reactor.core.publisher.Mono

@RestController
class FallbackController {

    @GetMapping("/fallback/account")
    fun accountFallback(): Mono<ResponseEntity<Map<String, Any>>> {
        return Mono.just(
            ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(mapOf(
                    "error" to "SERVICE_UNAVAILABLE",
                    "message" to "계좌 서비스가 일시적으로 이용 불가능합니다",
                    "service" to "account",
                    "timestamp" to System.currentTimeMillis()
                ))
        )
    }

    @GetMapping("/fallback/deposit")
    fun depositFallback(): Mono<ResponseEntity<Map<String, Any>>> {
        return Mono.just(
            ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(mapOf(
                    "error" to "SERVICE_UNAVAILABLE",
                    "message" to "예금 서비스가 일시적으로 이용 불가능합니다",
                    "service" to "deposit",
                    "timestamp" to System.currentTimeMillis()
                ))
        )
    }

    @GetMapping("/fallback/loan")
    fun loanFallback(): Mono<ResponseEntity<Map<String, Any>>> {
        return Mono.just(
            ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(mapOf(
                    "error" to "SERVICE_UNAVAILABLE",
                    "message" to "대출 서비스가 일시적으로 이용 불가능합니다",
                    "service" to "loan",
                    "timestamp" to System.currentTimeMillis()
                ))
        )
    }

    @GetMapping("/fallback/card")
    fun cardFallback(): Mono<ResponseEntity<Map<String, Any>>> {
        return Mono.just(
            ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(mapOf(
                    "error" to "SERVICE_UNAVAILABLE",
                    "message" to "카드 서비스가 일시적으로 이용 불가능합니다",
                    "service" to "card",
                    "timestamp" to System.currentTimeMillis()
                ))
        )
    }

    @GetMapping("/test/ratelimit")
    fun testRateLimit(): Mono<ResponseEntity<String>> {
        return Mono.just(
            ResponseEntity
                .status(HttpStatus.TOO_MANY_REQUESTS)
                .header("Content-Type", "application/json")
                .body("""{"code":"RATE_LIMIT_EXCEEDED","message":"요청이 너무 많습니다. 잠시 후 다시 시도해주세요"}""")
        )
    }
}