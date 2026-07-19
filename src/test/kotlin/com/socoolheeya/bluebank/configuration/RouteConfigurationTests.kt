package com.socoolheeya.bluebank.configuration

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.cloud.gateway.route.RouteLocator

@SpringBootTest(
    properties = [
        "services.account.url=http://account-test:8100",
        "services.deposit.url=http://deposit-test:8200",
        "services.loan.url=http://loan-test:8300",
        "services.card.url=http://card-test:8400"
    ]
)
class RouteConfigurationTests @Autowired constructor(
    private val routeLocator: RouteLocator
) {
    @Test
    fun `business routes use configured Kubernetes service URLs`() {
        val routes = routeLocator.routes.collectList().block()!!.associateBy { it.id }

        assertEquals("http://account-test:8100", routes.getValue("account-service").uri.toString())
        assertEquals("http://deposit-test:8200", routes.getValue("deposit-service").uri.toString())
        assertEquals("http://loan-test:8300", routes.getValue("loan-service").uri.toString())
        assertEquals("http://card-test:8400", routes.getValue("card-service").uri.toString())
        assertFalse(routes.values.any { it.uri.scheme == "lb" })
    }
}
