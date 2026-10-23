package com.example.hey_helpy.arcommon

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ArTextsTest {
    @Test
    fun colors() {
        assertEquals(0xFF0B7A62.toInt(), ArTexts.parseColor("#0B7A62"))
        assertEquals(0xFF0B7A62.toInt(), ArTexts.parseColor("0b7a62"))
        assertEquals(ArTexts.BRAND, ArTexts.parseColor("red"))
        assertEquals(ArTexts.BRAND, ArTexts.parseColor(null))
    }

    @Test
    fun texts() {
        assertEquals(mapOf("a" to "Б"), ArTexts.parseTexts("""{"a":"Б"}"""))
        assertTrue(ArTexts.parseTexts("не json").isEmpty())
        assertTrue(ArTexts.parseTexts(null).isEmpty())
    }
}
