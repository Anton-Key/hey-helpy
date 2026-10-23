package com.example.hey_helpy.arcommon

import android.content.Intent
import org.json.JSONObject

/**
 * Шаг 28 → 31: аргументы нативных AR-экранов. Своих строк в Kotlin нет — все
 * тексты приходят из lib/l10n (Flutter: vpsNativeTexts / arLabelNativeTexts).
 */
object ArTexts {
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

    fun parseTexts(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return try {
            val o = JSONObject(json)
            o.keys().asSequence().associateWith { o.optString(it) }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    /** Бирюзовый бренда (#2DB89A). */
    const val BRAND = 0xFF2DB89A.toInt()

    /** «#RRGGBB» → ARGB; иначе бирюзовый бренда. */
    fun parseColor(s: String?): Int {
        val h = s?.trim()?.removePrefix("#") ?: ""
        return if (h.length == 6 && h.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) {
            (0xFF000000 or h.toLong(16)).toInt()
        } else {
            BRAND
        }
    }
}
