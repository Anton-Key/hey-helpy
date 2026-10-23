package com.example.hey_helpy.arlabel

import org.json.JSONArray
import org.json.JSONObject

// Шаг 31: «AR-метки» V0 — чистые функции (без ARCore и Android-View,
// тесты ArLabelLogicTest): ответ photo-identify, выбор кандидата, текст
// таблички RU / EN, рамка ИИ → точка экрана, «переставить, а не дублировать».

/** Рамка оборудования от ИИ — доли 0..1 от снимка (как его видит человек). */
data class Box(val x: Double, val y: Double, val w: Double, val h: Double) {
    val cx get() = x + w / 2
    val cy get() = y + h / 2
}

data class Candidate(
    val assetId: String,
    val name: String,
    val locationId: String,
    val locationLabel: String,
    val score: Double,
)

/** Ответ Edge Function photo-identify (те же поля, что читает Flutter). */
data class IdentifyReply(
    val kind: String,
    val kindLabel: String,
    val layerId: String?,
    val confidence: Double?,
    val noEquipment: Boolean,
    val candidates: List<Candidate>,
    val box: Box?,
    val model: String?,
    val ms: Int?,
    /** Ответ целиком — Flutter соберёт из него заголовок и описание заявки. */
    val raw: String,
) {
    val top: Candidate? get() = candidates.firstOrNull()
}

object ArLabelLogic {
    /** Не больше табличек за сессию (самая старая уступает место). */
    const val MAX_LABELS = 10

    /** Табличка висит чуть выше точки, куда смотрел прицел. */
    const val LABEL_LIFT_M = 0.12

    /**
     * Насколько первый кандидат должен опережать второго, чтобы поставить
     * табличку сразу. Баллы функции (_shared/identify.ts): вид 35, помещение 30,
     * этаж 12, система 10, объект 5, открытая заявка 5; модель 45, серийный 100.
     * 0,15 — «то же помещение против соседнего этажа» уже уверенно, а два
     * одинаковых кондиционера в одной комнате — шторка «Что это?».
     */
    const val CONFIDENT_LEAD = 0.15

    private fun str(o: JSONObject, k: String): String? =
        if (o.isNull(k)) null else o.optString(k).trim().ifEmpty { null }

    fun parseReply(json: String): IdentifyReply? = try {
        val o = JSONObject(json)
        if (o.optString("source") != "ai") {
            null
        } else {
            val list = o.optJSONArray("candidates") ?: JSONArray()
            val cands = (0 until list.length()).mapNotNull { i ->
                val c = list.optJSONObject(i) ?: return@mapNotNull null
                val id = str(c, "asset_id") ?: return@mapNotNull null
                Candidate(
                    assetId = id,
                    name = str(c, "name") ?: "",
                    locationId = str(c, "location_id") ?: "",
                    locationLabel = str(c, "location_label") ?: "",
                    score = c.optDouble("score", 0.0).let { if (it.isNaN()) 0.0 else it },
                )
            }
            val conf = if (o.isNull("confidence")) null else o.optDouble("confidence").takeUnless { it.isNaN() }
            IdentifyReply(
                kind = str(o, "kind") ?: "other",
                kindLabel = str(o, "kind_label") ?: "",
                layerId = str(o, "layer_id"),
                confidence = conf,
                noEquipment = o.optBoolean("no_equipment", false),
                candidates = cands,
                box = parseBox(o.optJSONObject("box")),
                model = str(o, "model"),
                ms = if (o.has("ms")) o.optInt("ms") else null,
                raw = json,
            )
        }
    } catch (_: Exception) {
        null
    }

    /** Рамка: доли 0..1, площадь > 0; иначе null (функция проверяет то же). */
    fun parseBox(o: JSONObject?): Box? {
        if (o == null) return null
        val v = listOf("x", "y", "w", "h").map { o.optDouble(it, Double.NaN) }
        if (v.any { it.isNaN() || it.isInfinite() }) return null
        val (x, y, w, h) = v
        if (x < 0 || y < 0 || w <= 0 || h <= 0 || x + w > 1.0001 || y + h > 1.0001) return null
        return Box(x, y, w, h)
    }

    enum class PickKind { NONE, CONFIDENT, SEVERAL }

    data class Pick(val kind: PickKind, val candidate: Candidate? = null)

    /** Один кандидат или явный лидер — табличка сразу; иначе выбор «Это он». */
    fun choose(candidates: List<Candidate>): Pick {
        val top = candidates.firstOrNull() ?: return Pick(PickKind.NONE)
        val second = candidates.getOrNull(1) ?: return Pick(PickKind.CONFIDENT, top)
        return if (top.score - second.score >= CONFIDENT_LEAD - 1e-9) {
            Pick(PickKind.CONFIDENT, top)
        } else {
            Pick(PickKind.SEVERAL)
        }
    }

    /** Итог для журнала 0017 — как outcomeFor во Flutter. */
    fun outcome(reply: IdentifyReply, chosenAssetId: String?): String = when {
        chosenAssetId == null -> "dismissed"
        chosenAssetId == reply.top?.assetId -> "matched_top"
        else -> "matched_other"
    }

    /** Ключ формы множественного числа: ru — one / few / many, en — one / many. */
    fun pluralKey(n: Int, locale: String): String {
        if (locale != "ru") return if (n == 1) "One" else "Many"
        val m10 = n % 10
        val m100 = n % 100
        return when {
            m10 == 1 && m100 != 11 -> "One"
            m10 in 2..4 && m100 !in 12..14 -> "Few"
            else -> "Many"
        }
    }

    /**
     * Строка таблички: «1 открытая заявка · ТО до 31.10» / «ТО просрочено».
     * Шаблоны — из lib/l10n: arOrdersOne / Few / Many («{n} …»),
     * arNoOpenOrders, arMaintenanceDue («ТО до {date}»), arMaintenanceOverdue.
     */
    fun factsLine(
        openCount: Int,
        dueLabel: String?,
        overdue: Boolean,
        locale: String,
        texts: Map<String, String>,
    ): String {
        fun t(k: String) = texts[k] ?: ""
        val orders = if (openCount > 0) {
            t("arOrders" + pluralKey(openCount, locale)).replace("{n}", openCount.toString())
        } else {
            t("arNoOpenOrders")
        }
        val ppr = when {
            overdue -> t("arMaintenanceOverdue")
            !dueLabel.isNullOrBlank() -> t("arMaintenanceDue").replace("{date}", dueLabel)
            else -> ""
        }
        return listOf(orders, ppr).filter { it.isNotBlank() }.joinToString(" · ")
    }

    // ---------------------------------------------------------- снимок и экран

    /** Поворот снимка до «как видит человек»: задняя камера, экран повёрнут на display°. */
    fun imageRotation(sensorOrientation: Int, displayDegrees: Int): Int =
        ((sensorOrientation - displayDegrees) % 360 + 360) % 360

    /**
     * Точка снимка, повёрнутого на [rotation]° по часовой (доли 0..1) → та же
     * точка в исходном кадре камеры (IMAGE_NORMALIZED ARCore).
     */
    fun uprightToSensor(u: Double, v: Double, rotation: Int): Pair<Double, Double> = when (rotation) {
        90 -> Pair(v, 1 - u)
        180 -> Pair(1 - u, 1 - v)
        270 -> Pair(1 - v, u)
        else -> Pair(u, v)
    }

    /**
     * Кадр камеры (доли) → пиксели экрана по трём опорным точкам, которые
     * ARCore пересчитал при снимке (Frame.transformCoordinates2d
     * IMAGE_NORMALIZED → VIEW для (0,0), (1,0), (0,1)): поворот, масштаб и
     * обрезка кадра под экран — одно аффинное преобразование.
     */
    fun sensorToView(u: Double, v: Double, ref: FloatArray): Pair<Float, Float> {
        val ox = ref[0]; val oy = ref[1]
        val ux = ref[2] - ox; val uy = ref[3] - oy
        val vx = ref[4] - ox; val vy = ref[5] - oy
        return Pair((ox + u * ux + v * vx).toFloat(), (oy + u * uy + v * vy).toFloat())
    }

    /**
     * Центр рамки ИИ → точка экрана; null — за пределами экрана или опорные
     * точки не получены (ARCore не пересчитал — тогда метка остаётся в прицеле).
     */
    fun boxCenterOnView(box: Box, rotation: Int, ref: FloatArray, width: Int, height: Int): Pair<Float, Float>? {
        if (ref.size < 6) return null
        val ux = ref[2] - ref[0]; val uy = ref[3] - ref[1]
        val vx = ref[4] - ref[0]; val vy = ref[5] - ref[1]
        if (kotlin.math.abs(ux * vy - uy * vx) < 1f) return null
        val (su, sv) = uprightToSensor(box.cx, box.cy, rotation)
        val p = sensorToView(su, sv, ref)
        if (p.first < 0 || p.second < 0 || p.first > width || p.second > height) return null
        return p
    }

    /** Размер кадра для узнавания: самый крупный не шире 1920 (иначе — первый). */
    fun pickImageSize(sizes: List<Pair<Int, Int>>): Int {
        var best = -1
        var bestArea = -1L
        sizes.forEachIndexed { i, (w, h) ->
            val long = maxOf(w, h)
            val area = w.toLong() * h
            if (long <= 1920 && area > bestArea) {
                best = i
                bestArea = area
            }
        }
        return if (best >= 0) best else 0
    }

    /** Вписать в [max] по длинной стороне (не увеличивать). */
    fun fitScale(width: Int, height: Int, max: Int): Double {
        val long = maxOf(width, height)
        return if (long <= max || long <= 0) 1.0 else max.toDouble() / long
    }

    /** Ошибка запроса → ключ текста. */
    fun httpErrorKey(code: Int?): String = when (code) {
        null -> "arNoNetwork"
        401 -> "arSessionExpired"
        else -> "arFailed"
    }

    /** Строка журнала узнаваний 0017 — те же поля, что IdentifyLog.row во Flutter. */
    fun journalRow(
        id: String,
        companyId: String,
        userId: String,
        objectId: String?,
        floorId: String?,
        locationId: String?,
        reply: IdentifyReply,
        ms: Int,
    ): JSONObject {
        val uuid = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        fun id(v: String?): Any = if (v != null && uuid.matches(v)) v else JSONObject.NULL
        return JSONObject()
            .put("id", id)
            .put("company_id", companyId)
            .put("user_id", userId)
            .put("object_id", id(objectId))
            .put("floor_id", id(floorId))
            .put("location_id", id(locationId))
            .put("kind", reply.kind)
            .put("confidence", reply.confidence ?: JSONObject.NULL)
            .put("top_asset_id", id(reply.top?.assetId))
            .put("model", if (reply.model == "lite") "lite" else "main")
            .put("ms", ms.coerceIn(0, 600_000))
    }
}

/**
 * Таблички сессии: одна на оборудование, не больше [max]. Повторное «Что это?»
 * по тому же оборудованию — переставить (вернётся прежний якорь, его снять);
 * новая сверх лимита вытесняет самую старую.
 */
class LabelSlots<T>(private val max: Int = ArLabelLogic.MAX_LABELS) {
    data class Put<T>(val replaced: T?, val evicted: Pair<String, T>?)

    private val items = LinkedHashMap<String, T>()

    val size get() = items.size
    val ids: List<String> get() = items.keys.toList()

    operator fun get(assetId: String): T? = items[assetId]

    fun entries(): List<Pair<String, T>> = items.entries.map { it.key to it.value }

    fun put(assetId: String, value: T): Put<T> {
        val old = items.remove(assetId)
        var evicted: Pair<String, T>? = null
        if (old == null && items.size >= max) {
            val first = items.entries.first()
            items.remove(first.key)
            evicted = first.key to first.value
        }
        items[assetId] = value
        return Put(old, evicted)
    }

    fun remove(assetId: String): T? = items.remove(assetId)
}
