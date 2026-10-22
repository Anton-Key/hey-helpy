package com.example.hey_helpy.vps

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.example.hey_helpy.arcommon.ArTexts
import com.google.ar.core.ArCoreApk
import org.json.JSONArray

/** Шаг 28: что Flutter передаёт экрану VPS и что получает обратно. */
object VpsContract {
    const val URL = "url"
    const val ANON_KEY = "anonKey"
    const val JWT = "jwt"
    const val LOCATION_ID = "locationId"
    const val LOCATION_NAME = "locationName"
    const val LOCALE = "locale"
    const val CAN_EDIT = "canEdit"
    const val ASSETS = "assets" // JSON [{id, name, line, color}] — подписи меток (готовит Flutter)
    const val TEXTS = "texts" // JSON {ключ: текст} — все строки экрана из lib/l10n
    const val RESULT_ASSET = "assetId"

    fun putArgs(intent: Intent, args: Map<String, Any?>) = ArTexts.putArgs(intent, args)

    fun readResult(resultCode: Int, data: Intent?): Map<String, Any?> {
        val m = HashMap<String, Any?>()
        if (resultCode == Activity.RESULT_OK) {
            data?.getStringExtra(RESULT_ASSET)?.let { m[RESULT_ASSET] = it }
        }
        return m
    }

    fun status(context: Context): Map<String, Any?> {
        val m = HashMap<String, Any?>()
        m["available"] = true
        m["nsdk"] = BuildConfig.NSDK_VERSION
        val now = System.currentTimeMillis() / 1000
        m["token"] = when (VpsToken.state(BuildConfig.NIANTIC_TOKEN, now)) {
            VpsToken.State.MISSING -> "missing"
            VpsToken.State.EXPIRED -> "expired"
            VpsToken.State.OK -> "ok"
        }
        VpsToken.expiresAt(BuildConfig.NIANTIC_TOKEN)?.let { m["tokenExpiresAt"] = it * 1000 }
        m["arcore"] = try {
            val a = ArCoreApk.getInstance().checkAvailability(context)
            when {
                a.isSupported -> "supported"
                a.isTransient -> "unknown"
                else -> "unsupported"
            }
        } catch (_: Exception) {
            "unknown"
        }
        return m
    }

    data class AssetLabel(val id: String, val name: String, val line: String, val color: Int)

    fun parseAssets(json: String?): List<AssetLabel> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val a = JSONArray(json)
            (0 until a.length()).map { i ->
                val o = a.getJSONObject(i)
                AssetLabel(
                    id = o.getString("id"),
                    name = o.optString("name"),
                    line = o.optString("line"),
                    color = parseColor(o.optString("color")),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun parseTexts(json: String?): Map<String, String> = ArTexts.parseTexts(json)

    /** «#RRGGBB» → ARGB; иначе бирюзовый бренда. */
    fun parseColor(s: String?): Int = ArTexts.parseColor(s)
}
