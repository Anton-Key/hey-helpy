package com.example.hey_helpy.arlabel

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import com.google.ar.core.ArCoreApk
import org.json.JSONArray

/** Шаг 31: что Flutter передаёт экрану «AR-метки» и что получает обратно. */
object ArLabelContract {
    const val URL = "url"
    const val ANON_KEY = "anonKey"
    const val JWT = "jwt"
    const val COMPANY_ID = "companyId"
    const val USER_ID = "userId"
    const val OBJECT_ID = "objectId"
    const val FLOOR_ID = "floorId"
    const val LOCATION_ID = "locationId"
    const val LOCALE = "locale"
    const val ROLE = "role"

    /** JSON [{id, name, openCount, due, overdue, color, layerId, locationId}] — готовит Flutter под RLS. */
    const val ASSETS = "assets"

    /** JSON {ключ: текст} — все строки экрана из lib/l10n. */
    const val TEXTS = "texts"

    // Ответ: что выбрал человек на табличке.
    const val RESULT_ACTION = "action" // "asset" | "order"
    const val RESULT_ASSET = "assetId"
    const val RESULT_IDENTIFY = "identify" // ответ photo-identify (JSON)
    const val RESULT_PHOTO = "photoPath" // снимок для фото «до» (файл в cache, Flutter удаляет)
    const val RESULT_TAKEN_AT = "takenAt"
    const val RESULT_JOURNAL = "journalId"

    fun readResult(resultCode: Int, data: Intent?): Map<String, Any?> {
        val m = HashMap<String, Any?>()
        if (resultCode != Activity.RESULT_OK || data == null) return m
        for (k in listOf(RESULT_ACTION, RESULT_ASSET, RESULT_IDENTIFY, RESULT_PHOTO, RESULT_JOURNAL)) {
            data.getStringExtra(k)?.let { m[k] = it }
        }
        if (data.hasExtra(RESULT_TAKEN_AT)) m[RESULT_TAKEN_AT] = data.getLongExtra(RESULT_TAKEN_AT, 0L)
        return m
    }

    /**
     * Есть ли ARCore и камера. Проверка ARCore бывает «ещё не знаю» — ждём до
     * ~2 с (вызывать не из главного потока).
     */
    fun status(context: Context): Map<String, Any?> {
        val m = HashMap<String, Any?>()
        var a: ArCoreApk.Availability? = null
        try {
            for (i in 0 until 10) {
                a = ArCoreApk.getInstance().checkAvailability(context)
                if (a?.isTransient != true) break
                Thread.sleep(200)
            }
        } catch (_: Exception) {
        }
        val arcore = when {
            a == null -> "unknown"
            a!!.isSupported -> "supported"
            a!!.isTransient -> "unknown"
            else -> "unsupported"
        }
        m["arcore"] = arcore
        m["installed"] = a == ArCoreApk.Availability.SUPPORTED_INSTALLED
        m["camera"] = if (context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            "granted"
        } else {
            "ask"
        }
        // Кнопка — только на телефонах с ARCore (если «Сервисы Google Play для AR»
        // не стоят или устарели — экран сам предложит поставить их из Play Маркета).
        m["available"] = arcore == "supported"
        return m
    }

    data class AssetLabel(
        val id: String,
        val name: String,
        val openCount: Int,
        val due: String?,
        val overdue: Boolean,
        val color: Int,
        val layerId: String?,
        val locationId: String?,
    )

    fun parseAssets(json: String?): List<AssetLabel> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val a = JSONArray(json)
            (0 until a.length()).map { i ->
                val o = a.getJSONObject(i)
                AssetLabel(
                    id = o.getString("id"),
                    name = o.optString("name"),
                    openCount = o.optInt("openCount", 0),
                    due = if (o.isNull("due")) null else o.optString("due").ifBlank { null },
                    overdue = o.optBoolean("overdue", false),
                    color = com.example.hey_helpy.arcommon.ArTexts.parseColor(o.optString("color")),
                    layerId = if (o.isNull("layerId")) null else o.optString("layerId").ifBlank { null },
                    locationId = if (o.isNull("locationId")) null else o.optString("locationId").ifBlank { null },
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
