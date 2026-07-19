package com.socoolheeya.bluebank

import org.junit.jupiter.api.Test
import org.springframework.boot.test.context.SpringBootTest
import kotlin.io.encoding.Base64

@SpringBootTest
class BlueBankGatewayApplicationTests {

    @Test
    fun contextLoads() {
    }

    @Test
    fun test() {
        val str = "blue-bank-too-long-jwt-secret-key"
        val encoded = Base64.encode(str.encodeToByteArray())
        println(encoded)
    }

}
