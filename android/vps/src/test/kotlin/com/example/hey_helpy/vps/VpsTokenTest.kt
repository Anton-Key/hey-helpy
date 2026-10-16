package com.example.hey_helpy.vps

import org.junit.Assert.assertEquals
import org.junit.Test

class VpsTokenTest {
    // org.json в JUnit без Android — заглушка, поэтому exp читаем регуляркой.
    private val parse: (String) -> Long? = { json ->
        Regex("\"exp\"\\s*:\\s*(\\d+)").find(json)?.groupValues?.get(1)?.toLong()
    }

    private fun b64(s: String) = java.util.Base64.getUrlEncoder().withoutPadding()
        .encodeToString(s.toByteArray())

    private fun jwt(payload: String) = "${b64("{\"alg\":\"none\"}")}.${b64(payload)}.sig"

    @Test
    fun states() {
        val now = 1_760_000_000L
        assertEquals(VpsToken.State.MISSING, VpsToken.state("", now, parse))
        assertEquals(VpsToken.State.OK, VpsToken.state(jwt("{\"exp\":${now + 60}}"), now, parse))
        assertEquals(VpsToken.State.EXPIRED, VpsToken.state(jwt("{\"exp\":${now - 1}}"), now, parse))
        // не JWT — срок неизвестен, решит сервер
        assertEquals(VpsToken.State.OK, VpsToken.state("opaque-token", now, parse))
    }

    @Test
    fun decode() {
        assertEquals("{\"exp\":1}", VpsToken.decodeBase64Url(b64("{\"exp\":1}")))
        assertEquals("привет", VpsToken.decodeBase64Url(b64("привет")))
    }
}
