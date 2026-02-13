#!/usr/bin/env kotlin

@file:DependsOn("io.jsonwebtoken:jjwt-api:0.12.3")
@file:DependsOn("io.jsonwebtoken:jjwt-impl:0.12.3")
@file:DependsOn("io.jsonwebtoken:jjwt-jackson:0.12.3")

import io.jsonwebtoken.Jwts
import io.jsonwebtoken.security.Keys
import java.util.Date

// JWT Secret - application.yml의 기본값과 동일
val secret = "your-secret-key-must-be-at-least-256-bits-long-for-hs256-algorithm"
val key = Keys.hmacShaKeyFor(secret.toByteArray())

// 토큰 만료 시간 (1년)
val expirationTime = System.currentTimeMillis() + (365L * 24 * 60 * 60 * 1000)

// JWT 토큰 생성
val token = Jwts.builder()
    .subject("testuser")
    .claim("userId", "1")
    .claim("username", "testuser")
    .claim("roles", listOf("USER", "ADMIN"))
    .claim("customerId", 1)
    .issuedAt(Date())
    .expiration(Date(expirationTime))
    .signWith(key)
    .compact()

println("=== JWT Token Generated ===")
println()
println("Token:")
println(token)
println()
println("=== How to use ===")
println("1. In HTTP Header:")
println("   Authorization: Bearer $token")
println()
println("2. Test with curl:")
println("   curl -H \"Authorization: Bearer $token\" http://localhost:8080/api/accounts")
println()
println("3. Token Details:")
println("   - Subject: testuser")
println("   - User ID: 1")
println("   - Roles: USER, ADMIN")
println("   - Customer ID: 1")
println("   - Expires: ${Date(expirationTime)}")