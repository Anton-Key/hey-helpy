package com.example.hey_helpy.vps

import org.json.JSONObject

// Шаг 28: developer token Niantic (JWT) — проверяем срок до запуска сессии,
// чтобы сказать «Токен VPS истёк», а не молча не находить место.
object VpsToken {
    enum class State { MISSING, EXPIRED, OK }

    /** Срок действия (секунды Unix) из поля exp; null — не JWT или нет поля. */
    fun expiresAt(token: String, parse: (String) -> Long? = ::expFromJson): Long? {
        val parts = token.trim().split('.')
        if (parts.size != 3) return null
        val json = decodeBase64Url(parts[1]) ?: return null
        return parse(json)
    }

    fun state(token: String, nowSec: Long, parse: (String) -> Long? = ::expFromJson): State {
        if (token.isBlank()) return State.MISSING
        val exp = expiresAt(token, parse) ?: return State.OK // срок неизвестен — пусть решит сервер
        return if (exp <= nowSec) State.EXPIRED else State.OK
    }

    private fun expFromJson(json: String): Long? = try {
        val o = JSONObject(json)
        if (o.has("exp")) o.getLong("exp") else null
    } catch (_: Exception) {
        null
    }

    private const val ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    /** base64url без выравнивания → строка UTF-8 (своё, чтобы работало и в JUnit без Android). */
    fun decodeBase64Url(s: String): String? {
        val clean = s.trimEnd('=').replace('+', '-').replace('/', '_')
        val out = java.io.ByteArrayOutputStream()
        var buf = 0
        var bits = 0
        for (c in clean) {
            val v = ALPHABET.indexOf(c)
            if (v < 0) return null
            buf = (buf shl 6) or v
            bits += 6
            if (bits >= 8) {
                bits -= 8
                out.write((buf shr bits) and 0xFF)
            }
        }
        return out.toString("UTF-8")
    }
}
