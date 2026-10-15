package com.example.hey_helpy.vps

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.google.ar.core.ArCoreApk
import org.json.JSONArray
import org.json.JSONObject

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

    fun putArgs(intent: Intent, args: Map<String, Any?>) {
        for ((k, v) in args) {
            when (v) {
                is String -> intent.putExtra(k, v)
                is Boolean -> intent.putExtra(k, v)
                is Int -> intent.putExtra(k, v)
                is Long -> intent.putExtra(k, v)
            }
        }
    }

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

    fun parseTexts(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return try {
            val o = JSONObject(json)
            o.keys().asSequence().associateWith { o.optString(it) }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    /** «#RRGGBB» → ARGB; иначе бирюзовый бренда. */
    fun parseColor(s: String?): Int {
        val h = s?.trim()?.removePrefix("#") ?: ""
        return if (h.length == 6 && h.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) {
            (0xFF000000 or h.toLong(16)).toInt()
        } else {
            0xFF2DB89A.toInt()
        }
    }
}
