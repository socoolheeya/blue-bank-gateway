package com.socoolheeya.bluebank

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class BlueBankGatewayApplication

fun main(args: Array<String>) {
    runApplication<BlueBankGatewayApplication>(*args)
}
