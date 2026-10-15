package com.example.hey_helpy.vps

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VpsStateTest {
    @Test
    fun indicator() {
        assertEquals(Indicator.IDLE, VpsState.indicator(false, "PRECISE", "TRACKED"))
        assertEquals(Indicator.SEARCHING, VpsState.indicator(true, "UNAVAILABLE", "NOT_TRACKED"))
        assertEquals(Indicator.SEARCHING, VpsState.indicator(true, null, null))
        assertEquals(Indicator.COARSE, VpsState.indicator(true, "COARSE", "NOT_TRACKED"))
        assertEquals(Indicator.COARSE, VpsState.indicator(true, "PRECISE", "LIMITED"))
        assertEquals(Indicator.PRECISE, VpsState.indicator(true, "PRECISE", "TRACKED"))
    }

    @Test
    fun marksVisible() {
        assertFalse(VpsState.marksVisible(false, "TRACKED"))
        assertTrue(VpsState.marksVisible(true, "TRACKED"))
        assertTrue(VpsState.marksVisible(true, "LIMITED"))
        assertFalse(VpsState.marksVisible(true, "NOT_TRACKED"))
    }

    @Test
    fun errors() {
        assertEquals("vpsAuthFailed", VpsState.errorKey("AUTH_FAILURE"))
        assertEquals("vpsNoMap", VpsState.errorKey("NO_MAP_FOUND"))
        assertEquals("vpsQuota", VpsState.errorKey("QUOTA_EXCEEDED"))
        assertNull(VpsState.errorKey("LOCALIZATION_FAILED"))
        assertEquals("vpsSessionExpired", VpsState.httpErrorKey(401))
        assertEquals("vpsNoNetwork", VpsState.httpErrorKey(null))
        assertEquals("vpsFailed", VpsState.httpErrorKey(403))
    }

    @Test
    fun scale() {
        assertEquals(1.2f, VpsState.labelScale(0.5), 1e-6f)
        assertEquals(0.6f, VpsState.labelScale(10.0), 1e-6f)
        assertEquals(0.75f, VpsState.labelScale(2.0), 1e-6f)
    }
}
