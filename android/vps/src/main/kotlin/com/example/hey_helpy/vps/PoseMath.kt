package com.example.hey_helpy.vps

import kotlin.math.abs
import kotlin.math.sqrt

// Шаг 28: чистая математика меток VPS (без ARCore — проверяется JUnit-тестами).
//
// Метка хранится в базе ОТНОСИТЕЛЬНО VPS-якоря помещения (vps_marks: pos_*, rot_*):
//   метка_отн = якорь⁻¹ ∘ метка_мир        (сохранить, PoseMath.relativeTo)
//   метка_мир = якорь ∘ метка_отн          (показать, PoseMath.toWorld)
// «Мир» — локальная система ARCore этого запуска; якорь в ней даёт NSDK
// (AnchorUpdate.anchorToLocalTrackingTransform). После перезапуска мир другой,
// а якорь — то же место в комнате, поэтому метка встаёт туда же.

data class Vec3(val x: Double, val y: Double, val z: Double) {
    operator fun plus(o: Vec3) = Vec3(x + o.x, y + o.y, z + o.z)
    operator fun minus(o: Vec3) = Vec3(x - o.x, y - o.y, z - o.z)
    operator fun unaryMinus() = Vec3(-x, -y, -z)
    fun length() = sqrt(x * x + y * y + z * z)
}

/** Поворот — единичный кватернион (x, y, z, w), как в ARCore Pose. */
data class Quat(val x: Double, val y: Double, val z: Double, val w: Double) {
    fun norm() = sqrt(x * x + y * y + z * z + w * w)

    fun normalized(): Quat {
        val n = norm()
        return if (n < 1e-9) IDENTITY else Quat(x / n, y / n, z / n, w / n)
    }

    fun conjugate() = Quat(-x, -y, -z, w)

    operator fun times(o: Quat) = Quat(
        w * o.x + x * o.w + y * o.z - z * o.y,
        w * o.y - x * o.z + y * o.w + z * o.x,
        w * o.z + x * o.y - y * o.x + z * o.w,
        w * o.w - x * o.x - y * o.y - z * o.z,
    )

    /** Повернуть вектор: q · v · q⁻¹. */
    fun rotate(v: Vec3): Vec3 {
        val r = this * Quat(v.x, v.y, v.z, 0.0) * conjugate()
        return Vec3(r.x, r.y, r.z)
    }

    companion object {
        val IDENTITY = Quat(0.0, 0.0, 0.0, 1.0)
    }
}

/** Жёсткая поза: сначала поворот, потом сдвиг (как ARCore Pose). */
data class RigidPose(val p: Vec3, val q: Quat) {
    fun compose(o: RigidPose) = RigidPose(p + q.rotate(o.p), (q * o.q).normalized())

    fun inverse(): RigidPose {
        val qi = q.conjugate()
        return RigidPose(-qi.rotate(p), qi)
    }

    fun transform(v: Vec3) = p + q.rotate(v)

    companion object {
        val IDENTITY = RigidPose(Vec3(0.0, 0.0, 0.0), Quat.IDENTITY)
    }
}

object PoseMath {
    /** Дальше этого от якоря метку не сохраняем (помещение, не здание). */
    const val MAX_DISTANCE_M = 50.0

    /** Метки дальше этого от камеры не рисуем. */
    const val MAX_VISIBLE_M = 15.0

    /** Табличка висит чуть выше точки касания. */
    const val LABEL_LIFT_M = 0.15

    fun relativeTo(anchor: RigidPose, world: RigidPose): RigidPose = anchor.inverse().compose(world)

    fun toWorld(anchor: RigidPose, relative: RigidPose): RigidPose = anchor.compose(relative)

    /** Можно ли сохранить такую позу (то же проверяет база в 0025). */
    fun isValidRelative(rel: RigidPose): Boolean {
        val coords = listOf(rel.p.x, rel.p.y, rel.p.z, rel.q.x, rel.q.y, rel.q.z, rel.q.w)
        if (coords.any { it.isNaN() || it.isInfinite() }) return false
        return abs(rel.p.x) <= MAX_DISTANCE_M && abs(rel.p.y) <= MAX_DISTANCE_M &&
            abs(rel.p.z) <= MAX_DISTANCE_M && abs(rel.q.norm() - 1.0) < 0.01
    }

    /** Произведение матриц 4×4 по столбцам (как OpenGL и ARCore): a · b. */
    fun multiply(a: FloatArray, b: FloatArray): FloatArray {
        val r = FloatArray(16)
        for (col in 0 until 4) {
            for (row in 0 until 4) {
                var s = 0f
                for (k in 0 until 4) s += a[k * 4 + row] * b[col * 4 + k]
                r[col * 4 + row] = s
            }
        }
        return r
    }

    /**
     * Точка мира → пиксели экрана по матрице «проекция · вид» (по столбцам).
     * null — точка позади камеры или за пределами видимости.
     */
    fun project(viewProj: FloatArray, p: Vec3, width: Int, height: Int): Pair<Float, Float>? {
        val x = viewProj[0] * p.x + viewProj[4] * p.y + viewProj[8] * p.z + viewProj[12]
        val y = viewProj[1] * p.x + viewProj[5] * p.y + viewProj[9] * p.z + viewProj[13]
        val w = viewProj[3] * p.x + viewProj[7] * p.y + viewProj[11] * p.z + viewProj[15]
        if (w <= 1e-6) return null
        val nx = x / w
        val ny = y / w
        if (nx < -1.2 || nx > 1.2 || ny < -1.2 || ny > 1.2) return null
        return Pair(((nx + 1) / 2 * width).toFloat(), ((1 - ny) / 2 * height).toFloat())
    }
}
