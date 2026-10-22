package com.example.hey_helpy.vps

import com.example.hey_helpy.arcommon.PoseMath

// Шаг 28: состояния экрана VPS — чистые функции (тесты VpsStateTest).
// Имена состояний NSDK передаются строками (enum.name), чтобы проверять без SDK.

enum class Indicator { IDLE, SEARCHING, COARSE, PRECISE }

object VpsState {
    /**
     * Индикатор: красный «Ищу…» / жёлтый «Примерно» / зелёный «Точно ✓».
     * localization — Vps2TrackingState (UNAVAILABLE | COARSE | PRECISE),
     * anchor — AnchorTrackingState якоря помещения (NOT_TRACKED | LIMITED | TRACKED).
     * «Точно» — только когда якорь помещения отслеживается полностью.
     */
    fun indicator(started: Boolean, localization: String?, anchor: String?): Indicator {
        if (!started) return Indicator.IDLE
        if (anchor == "TRACKED") return Indicator.PRECISE
        if (anchor == "LIMITED" || localization == "PRECISE" || localization == "COARSE") {
            return Indicator.COARSE
        }
        return Indicator.SEARCHING
    }

    /**
     * Метки показываем, когда хоть раз было «Точно» и якорь не потерян
     * (иначе при LIMITED ↔ TRACKED метки мигали бы).
     */
    fun marksVisible(everPrecise: Boolean, anchor: String?): Boolean =
        everPrecise && (anchor == "TRACKED" || anchor == "LIMITED")

    /** Ошибка запроса локализации (Vps2LocalizationError) → ключ текста; null — молчим. */
    fun errorKey(error: String?): String? = when (error) {
        "AUTH_FAILURE", "PERMISSION_DENIED" -> "vpsAuthFailed"
        "BAD_NETWORK_CONNECTION" -> "vpsNoNetwork"
        "QUOTA_EXCEEDED", "REQUESTS_LIMIT_EXCEEDED" -> "vpsQuota"
        "NO_MAP_FOUND" -> "vpsNoMap"
        "BAD_TRACKING", "BAD_CAMERA_ANGLE" -> "vpsMoveSlowly"
        else -> null // LOCALIZATION_FAILED и др. — обычное «ещё ищу»
    }

    /** Ошибка REST Supabase → ключ текста. */
    fun httpErrorKey(code: Int?): String = when (code) {
        null -> "vpsNoNetwork"
        401 -> "vpsSessionExpired"
        else -> "vpsFailed"
    }

    /** Чем крупнее табличка, тем ближе оборудование (0.6…1.2). */
    fun labelScale(distanceM: Double): Float = PoseMath.labelScale(distanceM)
}
