package com.example.hey_helpy.arcommon

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Шаг 28 → 31 (общий модуль): запросы к Supabase с JWT пользователя — всё под
 * RLS, без service-ключей. Блокирующие: вызывать не из главного потока.
 */
class SupabaseRest(
    private val baseUrl: String,
    private val anonKey: String,
    private val jwt: String,
) {
    class HttpError(val code: Int) : IOException("http $code")

    /** PostgREST: `rest/v1/<path>`. */
    fun rest(method: String, path: String, body: String? = null, prefer: String? = null): String =
        call(method, "rest/v1/$path", body, prefer, readTimeoutMs = 25_000)

    /** Edge Function: `functions/v1/<name>` (POST JSON). */
    fun function(name: String, body: String, readTimeoutMs: Int): String =
        call("POST", "functions/v1/$name", body, null, readTimeoutMs)

    private fun call(method: String, path: String, body: String?, prefer: String?, readTimeoutMs: Int): String {
        val c = URL("${baseUrl.trimEnd('/')}/$path").openConnection() as HttpURLConnection
        try {
            c.requestMethod = method
            c.connectTimeout = 15_000
            c.readTimeout = readTimeoutMs
            c.setRequestProperty("apikey", anonKey)
            c.setRequestProperty("Authorization", "Bearer $jwt")
            c.setRequestProperty("Accept", "application/json")
            if (prefer != null) c.setRequestProperty("Prefer", prefer)
            if (body != null) {
                c.doOutput = true
                c.setRequestProperty("Content-Type", "application/json")
                c.outputStream.use { it.write(body.toByteArray()) }
            }
            val code = c.responseCode
            if (code !in 200..299) throw HttpError(code)
            return c.inputStream.use { it.readBytes().toString(Charsets.UTF_8) }.ifBlank { "[]" }
        } finally {
            c.disconnect()
        }
    }
}
