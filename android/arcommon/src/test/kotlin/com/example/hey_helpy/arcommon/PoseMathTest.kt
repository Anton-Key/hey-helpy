package com.example.hey_helpy.arcommon

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class PoseMathTest {
    private fun yaw(deg: Double): Quat {
        val h = Math.toRadians(deg) / 2
        return Quat(0.0, sin(h), 0.0, cos(h))
    }

    private fun assertVec(e: Vec3, a: Vec3, eps: Double = 1e-6) {
        assertEquals(e.x, a.x, eps); assertEquals(e.y, a.y, eps); assertEquals(e.z, a.z, eps)
    }

    @Test
    fun relativeThenWorldRoundTrip() {
        val anchor = RigidPose(Vec3(1.0, 0.5, -2.0), yaw(90.0))
        val mark = RigidPose(Vec3(2.5, 1.7, -3.0), yaw(30.0))
        val rel = PoseMath.relativeTo(anchor, mark)
        val back = PoseMath.toWorld(anchor, rel)
        assertVec(mark.p, back.p)
        assertEquals(1.0, back.q.norm(), 1e-9)
    }

    @Test
    fun markFollowsAnchorAfterRestart() {
        // Запуск 1: якорь в одной системе ARCore, метку поставили.
        val anchor1 = RigidPose(Vec3(0.0, 0.0, -1.0), Quat.IDENTITY)
        val mark1 = RigidPose(Vec3(0.3, 1.2, -1.5), Quat.IDENTITY)
        val rel = PoseMath.relativeTo(anchor1, mark1)
        // Запуск 2: мир повёрнут на 90° и сдвинут — якорь найден там же в комнате.
        val shift = RigidPose(Vec3(5.0, 0.0, 2.0), yaw(90.0))
        val anchor2 = shift.compose(anchor1)
        val mark2 = PoseMath.toWorld(anchor2, rel)
        assertVec(shift.compose(mark1).p, mark2.p)
    }

    @Test
    fun relativeOfAnchorItselfIsIdentity() {
        val anchor = RigidPose(Vec3(3.0, 1.0, 4.0), yaw(45.0))
        val rel = PoseMath.relativeTo(anchor, anchor)
        assertVec(Vec3(0.0, 0.0, 0.0), rel.p)
        assertEquals(1.0, kotlin.math.abs(rel.q.w), 1e-9)
    }

    @Test
    fun validation() {
        assertTrue(PoseMath.isValidRelative(RigidPose(Vec3(1.0, 2.0, 3.0), Quat.IDENTITY)))
        assertFalse(PoseMath.isValidRelative(RigidPose(Vec3(51.0, 0.0, 0.0), Quat.IDENTITY)))
        assertFalse(PoseMath.isValidRelative(RigidPose(Vec3(0.0, 0.0, 0.0), Quat(0.0, 0.0, 0.0, 2.0))))
        assertFalse(PoseMath.isValidRelative(RigidPose(Vec3(Double.NaN, 0.0, 0.0), Quat.IDENTITY)))
    }

    @Test
    fun projectCenterAndBehind() {
        // Простая перспектива: x' = x, y' = y, w = -z (камера смотрит в -Z).
        val m = FloatArray(16)
        m[0] = 1f; m[5] = 1f; m[11] = -1f
        val c = PoseMath.project(m, Vec3(0.0, 0.0, -2.0), 1000, 2000)
        assertNotNull(c)
        assertEquals(500f, c!!.first, 0.01f)
        assertEquals(1000f, c.second, 0.01f)
        val up = PoseMath.project(m, Vec3(0.0, 1.0, -2.0), 1000, 2000)!!
        assertTrue(up.second < 1000f) // выше центра — меньше y на экране
        assertNull(PoseMath.project(m, Vec3(0.0, 0.0, 2.0), 1000, 2000)) // позади
    }

    @Test
    fun multiplyIdentity() {
        val id = FloatArray(16).also { it[0] = 1f; it[5] = 1f; it[10] = 1f; it[15] = 1f }
        val a = FloatArray(16) { it.toFloat() }
        assertTrue(a.contentEquals(PoseMath.multiply(id, a)))
        assertTrue(a.contentEquals(PoseMath.multiply(a, id)))
    }

    // Шаг 31: перспектива как у ARCore (камера в начале координат, смотрит в -Z).
    private fun perspective(fovYDeg: Double, aspect: Double, near: Double, far: Double): FloatArray {
        val f = 1.0 / kotlin.math.tan(Math.toRadians(fovYDeg) / 2)
        val m = FloatArray(16)
        m[0] = (f / aspect).toFloat(); m[5] = f.toFloat()
        m[10] = ((far + near) / (near - far)).toFloat(); m[11] = -1f
        m[14] = (2 * far * near / (near - far)).toFloat()
        return m
    }

    @Test
    fun invertRoundTrip() {
        val p = perspective(60.0, 0.5, 0.05, 100.0)
        val inv = PoseMath.invert(p)!!
        val id = PoseMath.multiply(p, inv)
        for (i in 0 until 16) assertEquals(if (i % 5 == 0) 1f else 0f, id[i], 1e-4f)
        assertNull(PoseMath.invert(FloatArray(16)))
    }

    @Test
    fun rayThroughCenterLooksForward() {
        val inv = PoseMath.invert(perspective(60.0, 0.5, 0.05, 100.0))!!
        val (o, d) = PoseMath.rayThrough(inv, 500f, 1000f, 1000, 2000)!!
        assertVec(Vec3(0.0, 0.0, -0.05), o, 1e-4)
        assertVec(Vec3(0.0, 0.0, -1.0), d, 1e-4)
    }

    @Test
    fun rayThroughProjectsBack() {
        // Точка экрана → луч → точка на луче проецируется в ту же точку экрана.
        val vp = perspective(60.0, 0.5, 0.05, 100.0)
        val inv = PoseMath.invert(vp)!!
        val (o, d) = PoseMath.rayThrough(inv, 120f, 1700f, 1000, 2000)!!
        val p = o + Vec3(d.x * 3, d.y * 3, d.z * 3)
        val s = PoseMath.project(vp, p, 1000, 2000)!!
        assertEquals(120f, s.first, 0.5f)
        assertEquals(1700f, s.second, 0.5f)
        assertNull(PoseMath.rayThrough(inv, 1f, 1f, 0, 0))
    }

    @Test
    fun labelScaleByDistance() {
        assertEquals(1.2f, PoseMath.labelScale(0.5), 1e-6f)
        assertEquals(0.6f, PoseMath.labelScale(10.0), 1e-6f)
        assertEquals(0.75f, PoseMath.labelScale(2.0), 1e-6f)
    }
}
