package com.example.hey_helpy.arlabel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ArLabelLogicTest {
    private fun c(id: String, score: Double) = Candidate(id, "Кондиционер $id", "loc", "301 Переговорная", score)

    private val ru = mapOf(
        "arOrdersOne" to "{n} открытая заявка",
        "arOrdersFew" to "{n} открытые заявки",
        "arOrdersMany" to "{n} открытых заявок",
        "arNoOpenOrders" to "Открытых заявок нет",
        "arMaintenanceDue" to "ТО до {date}",
        "arMaintenanceOverdue" to "ТО просрочено",
    )
    private val en = mapOf(
        "arOrdersOne" to "{n} open work order",
        "arOrdersFew" to "{n} open work orders",
        "arOrdersMany" to "{n} open work orders",
        "arNoOpenOrders" to "No open work orders",
        "arMaintenanceDue" to "Maintenance due {date}",
        "arMaintenanceOverdue" to "Maintenance overdue",
    )

    @Test
    fun chooseCandidate() {
        assertEquals(ArLabelLogic.PickKind.NONE, ArLabelLogic.choose(emptyList()).kind)
        val one = ArLabelLogic.choose(listOf(c("a", 0.4)))
        assertEquals(ArLabelLogic.PickKind.CONFIDENT, one.kind)
        assertEquals("a", one.candidate!!.assetId)
        // То же помещение (0,75) против соседнего этажа (0,57) — уверенно.
        assertEquals(ArLabelLogic.PickKind.CONFIDENT, ArLabelLogic.choose(listOf(c("a", 0.75), c("b", 0.57))).kind)
        // Два одинаковых в одной комнате — выбор человеком.
        assertEquals(ArLabelLogic.PickKind.SEVERAL, ArLabelLogic.choose(listOf(c("a", 0.75), c("b", 0.70))).kind)
        assertEquals(ArLabelLogic.PickKind.SEVERAL, ArLabelLogic.choose(listOf(c("a", 0.75), c("b", 0.75))).kind)
    }

    @Test
    fun factsLineRu() {
        assertEquals("1 открытая заявка · ТО до 31.10", ArLabelLogic.factsLine(1, "31.10", false, "ru", ru))
        assertEquals("3 открытые заявки", ArLabelLogic.factsLine(3, null, false, "ru", ru))
        assertEquals("5 открытых заявок · ТО просрочено", ArLabelLogic.factsLine(5, "01.10", true, "ru", ru))
        assertEquals("11 открытых заявок", ArLabelLogic.factsLine(11, null, false, "ru", ru))
        assertEquals("21 открытая заявка", ArLabelLogic.factsLine(21, null, false, "ru", ru))
        assertEquals("Открытых заявок нет", ArLabelLogic.factsLine(0, "", false, "ru", ru))
    }

    @Test
    fun factsLineEn() {
        assertEquals("1 open work order · Maintenance due Oct 31", ArLabelLogic.factsLine(1, "Oct 31", false, "en", en))
        assertEquals("2 open work orders · Maintenance overdue", ArLabelLogic.factsLine(2, null, true, "en", en))
        assertEquals("No open work orders", ArLabelLogic.factsLine(0, null, false, "en", en))
    }

    @Test
    fun plural() {
        assertEquals("One", ArLabelLogic.pluralKey(1, "ru"))
        assertEquals("Few", ArLabelLogic.pluralKey(22, "ru"))
        assertEquals("Many", ArLabelLogic.pluralKey(12, "ru"))
        assertEquals("Many", ArLabelLogic.pluralKey(0, "ru"))
        assertEquals("One", ArLabelLogic.pluralKey(1, "en"))
        assertEquals("Many", ArLabelLogic.pluralKey(2, "en"))
    }

    @Test
    fun parseReplyFull() {
        val r = ArLabelLogic.parseReply(
            """{"source":"ai","kind":"ac","kind_label":"Кондиционер","layer_id":"L","confidence":0.92,
               "no_equipment":false,"model":"main","ms":4100,
               "box":{"x":0.2,"y":0.1,"w":0.5,"h":0.3},
               "candidates":[{"asset_id":"A","name":"Кондиционер КД-301","location_id":"R","location_label":"301 Переговорная","score":0.75},
                             {"name":"без id"}]}""",
        )!!
        assertEquals("ac", r.kind)
        assertEquals(0.92, r.confidence!!, 1e-9)
        assertEquals(1, r.candidates.size)
        assertEquals("A", r.top!!.assetId)
        assertEquals(0.45, r.box!!.cx, 1e-9)
        assertEquals(0.25, r.box!!.cy, 1e-9)
        assertEquals(4100, r.ms)
        assertNull(ArLabelLogic.parseReply("""{"error":"ai_unavailable"}"""))
        assertNull(ArLabelLogic.parseReply("не json"))
        val none = ArLabelLogic.parseReply("""{"source":"ai","kind":"other","no_equipment":true,"candidates":[],"confidence":null}""")!!
        assertTrue(none.noEquipment)
        assertNull(none.confidence)
        assertNull(none.box)
    }

    @Test
    fun badBoxIgnored() {
        fun box(s: String) = ArLabelLogic.parseReply("""{"source":"ai","box":$s}""")!!.box
        assertNull(box("null"))
        assertNull(box("""{"x":0.6,"y":0.1,"w":0.5,"h":0.3}""")) // за правым краем
        assertNull(box("""{"x":0.1,"y":0.1,"w":0,"h":0.3}"""))
        assertNull(box("""{"x":-0.1,"y":0.1,"w":0.2,"h":0.3}"""))
        assertNull(box("""{"x":"a","y":0.1,"w":0.2,"h":0.3}"""))
        assertNotNull(box("""{"x":0,"y":0,"w":1,"h":1}"""))
    }

    @Test
    fun outcome() {
        val r = ArLabelLogic.parseReply("""{"source":"ai","candidates":[{"asset_id":"A","location_id":"R"},{"asset_id":"B","location_id":"R"}]}""")!!
        assertEquals("matched_top", ArLabelLogic.outcome(r, "A"))
        assertEquals("matched_other", ArLabelLogic.outcome(r, "B"))
        assertEquals("dismissed", ArLabelLogic.outcome(r, null))
    }

    @Test
    fun rotations() {
        assertEquals(90, ArLabelLogic.imageRotation(90, 0))
        assertEquals(0, ArLabelLogic.imageRotation(90, 90))
        assertEquals(180, ArLabelLogic.imageRotation(90, 270))
        // Снимок повёрнут на 90° по часовой: верх-право снимка = верх-лево кадра.
        assertEquals(Pair(0.0, 0.0), ArLabelLogic.uprightToSensor(1.0, 0.0, 90))
        assertEquals(Pair(1.0, 0.0), ArLabelLogic.uprightToSensor(1.0, 1.0, 90))
        assertEquals(Pair(0.5, 0.5), ArLabelLogic.uprightToSensor(0.5, 0.5, 270))
        assertEquals(Pair(0.75, 0.25), ArLabelLogic.uprightToSensor(0.25, 0.75, 180))
        assertEquals(Pair(0.3, 0.6), ArLabelLogic.uprightToSensor(0.3, 0.6, 0))
        // 90 и 270 — взаимно обратные.
        val (a, b) = ArLabelLogic.uprightToSensor(0.2, 0.7, 90)
        val back = ArLabelLogic.uprightToSensor(1 - b, a, 0)
        assertEquals(0.2, back.first, 1e-9); assertEquals(0.7, back.second, 1e-9)
    }

    @Test
    fun boxToScreen() {
        // Портрет 1080×2400, кадр 640×480 (сенсор повёрнут на 90°), обрезан по бокам.
        // ARCore дал опорные точки: (0,0) → (1080+d, 0), (1,0) → (1080+d, 2400), (0,1) → (-d, 0).
        // Масштаб 2400 / 640 = 3,75; ширина снимка на экране 480 · 3,75 = 1800.
        val d = ((1800 - 1080) / 2).toFloat()
        val ref = floatArrayOf(1080f + d, 0f, 1080f + d, 2400f, -d, 0f)
        // Центр снимка — центр экрана.
        val c = ArLabelLogic.boxCenterOnView(Box(0.4, 0.4, 0.2, 0.2), 90, ref, 1080, 2400)!!
        assertEquals(540f, c.first, 0.5f)
        assertEquals(1200f, c.second, 0.5f)
        // Левый верх снимка (портрет) — левый верх экрана со сдвигом обрезки.
        val lt = ArLabelLogic.sensorToView(ArLabelLogic.uprightToSensor(0.5, 0.0, 90).first, ArLabelLogic.uprightToSensor(0.5, 0.0, 90).second, ref)
        assertEquals(540f, lt.first, 0.5f)
        assertEquals(0f, lt.second, 0.5f)
        // Рамка у самого края снимка, который обрезан, — за экраном.
        assertNull(ArLabelLogic.boxCenterOnView(Box(0.0, 0.45, 0.04, 0.1), 90, ref, 1080, 2400))
    }

    @Test
    fun imageSizeAndScale() {
        assertEquals(1, ArLabelLogic.pickImageSize(listOf(640 to 480, 1920 to 1080, 4032 to 3024)))
        assertEquals(0, ArLabelLogic.pickImageSize(listOf(4032 to 3024)))
        assertEquals(1.0, ArLabelLogic.fitScale(640, 480, 1280), 1e-9)
        assertEquals(1280.0 / 1920, ArLabelLogic.fitScale(1080, 1920, 1280), 1e-9)
    }

    @Test
    fun slotsReplaceNotDuplicate() {
        val s = LabelSlots<String>(3)
        assertNull(s.put("a", "anchor1").replaced)
        val again = s.put("a", "anchor2")
        assertEquals("anchor1", again.replaced)
        assertNull(again.evicted)
        assertEquals(1, s.size)
        assertEquals("anchor2", s["a"])
        s.put("b", "b1"); s.put("c", "c1")
        val full = s.put("d", "d1")
        assertEquals("a" to "anchor2", full.evicted)
        assertEquals(listOf("b", "c", "d"), s.ids)
        // Переставить существующую при полном списке — никого не вытесняет.
        assertNull(s.put("b", "b2").evicted)
        assertEquals(listOf("c", "d", "b"), s.ids)
        assertEquals("c1", s.remove("c"))
        assertFalse(s.ids.contains("c"))
    }

    @Test
    fun journalRow() {
        val r = ArLabelLogic.parseReply("""{"source":"ai","kind":"ac","confidence":0.9,"model":"lite","candidates":[{"asset_id":"de300000-0000-4000-8000-000000000708","location_id":"R"}]}""")!!
        val row = ArLabelLogic.journalRow("id1", "co", "u", "de300000-0000-4000-8000-000000000010", "bad", null, r, 700_000)
        assertEquals("de300000-0000-4000-8000-000000000010", row.getString("object_id"))
        assertTrue(row.isNull("floor_id"))
        assertTrue(row.isNull("location_id"))
        assertEquals("de300000-0000-4000-8000-000000000708", row.getString("top_asset_id"))
        assertEquals("lite", row.getString("model"))
        assertEquals(600_000, row.getInt("ms"))
    }

    @Test
    fun errors() {
        assertEquals("arNoNetwork", ArLabelLogic.httpErrorKey(null))
        assertEquals("arSessionExpired", ArLabelLogic.httpErrorKey(401))
        assertEquals("arFailed", ArLabelLogic.httpErrorKey(502))
    }
}

class ArLabelContractTest {
    @Test
    fun assets() {
        val a = ArLabelContract.parseAssets(
            """[{"id":"A","name":"КД-301","openCount":1,"due":"31.10","overdue":false,"color":"#0B7A62","layerId":"L","locationId":"R"},
                {"id":"B","name":"Щит","due":null,"layerId":null}]""",
        )
        assertEquals(2, a.size)
        assertEquals(1, a[0].openCount)
        assertEquals("31.10", a[0].due)
        assertEquals(0xFF0B7A62.toInt(), a[0].color)
        assertNull(a[1].due)
        assertNull(a[1].layerId)
        assertTrue(ArLabelContract.parseAssets("[{]").isEmpty())
    }
}
