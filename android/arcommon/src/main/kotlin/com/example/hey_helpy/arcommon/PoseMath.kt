package com.example.hey_helpy.arcommon

import kotlin.math.abs
import kotlin.math.sqrt

// Шаг 28: чистая математика меток VPS (без ARCore — проверяется JUnit-тестами).
// Шаг 31: общий модуль arcommon — её же используют «AR-метки» (android/arlabel):
// проекция табличек на экран, масштаб по расстоянию, луч из точки экрана.
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

    /** Чем крупнее табличка, тем ближе оборудование (0.6…1.2). */
    fun labelScale(distanceM: Double): Float =
        (1.5 / distanceM.coerceAtLeast(0.1)).coerceIn(0.6, 1.2).toFloat()

    /** Обратная матрица 4×4 (по столбцам); null — вырожденная. */
    fun invert(m: FloatArray): FloatArray? {
        val a = DoubleArray(16) { m[it].toDouble() }
        val inv = DoubleArray(16)
        inv[0] = a[5] * a[10] * a[15] - a[5] * a[11] * a[14] - a[9] * a[6] * a[15] +
            a[9] * a[7] * a[14] + a[13] * a[6] * a[11] - a[13] * a[7] * a[10]
        inv[4] = -a[4] * a[10] * a[15] + a[4] * a[11] * a[14] + a[8] * a[6] * a[15] -
            a[8] * a[7] * a[14] - a[12] * a[6] * a[11] + a[12] * a[7] * a[10]
        inv[8] = a[4] * a[9] * a[15] - a[4] * a[11] * a[13] - a[8] * a[5] * a[15] +
            a[8] * a[7] * a[13] + a[12] * a[5] * a[11] - a[12] * a[7] * a[9]
        inv[12] = -a[4] * a[9] * a[14] + a[4] * a[10] * a[13] + a[8] * a[5] * a[14] -
            a[8] * a[6] * a[13] - a[12] * a[5] * a[10] + a[12] * a[6] * a[9]
        inv[1] = -a[1] * a[10] * a[15] + a[1] * a[11] * a[14] + a[9] * a[2] * a[15] -
            a[9] * a[3] * a[14] - a[13] * a[2] * a[11] + a[13] * a[3] * a[10]
        inv[5] = a[0] * a[10] * a[15] - a[0] * a[11] * a[14] - a[8] * a[2] * a[15] +
            a[8] * a[3] * a[14] + a[12] * a[2] * a[11] - a[12] * a[3] * a[10]
        inv[9] = -a[0] * a[9] * a[15] + a[0] * a[11] * a[13] + a[8] * a[1] * a[15] -
            a[8] * a[3] * a[13] - a[12] * a[1] * a[11] + a[12] * a[3] * a[9]
        inv[13] = a[0] * a[9] * a[14] - a[0] * a[10] * a[13] - a[8] * a[1] * a[14] +
            a[8] * a[2] * a[13] + a[12] * a[1] * a[10] - a[12] * a[2] * a[9]
        inv[2] = a[1] * a[6] * a[15] - a[1] * a[7] * a[14] - a[5] * a[2] * a[15] +
            a[5] * a[3] * a[14] + a[13] * a[2] * a[7] - a[13] * a[3] * a[6]
        inv[6] = -a[0] * a[6] * a[15] + a[0] * a[7] * a[14] + a[4] * a[2] * a[15] -
            a[4] * a[3] * a[14] - a[12] * a[2] * a[7] + a[12] * a[3] * a[6]
        inv[10] = a[0] * a[5] * a[15] - a[0] * a[7] * a[13] - a[4] * a[1] * a[15] +
            a[4] * a[3] * a[13] + a[12] * a[1] * a[7] - a[12] * a[3] * a[5]
        inv[14] = -a[0] * a[5] * a[14] + a[0] * a[6] * a[13] + a[4] * a[1] * a[14] -
            a[4] * a[2] * a[13] - a[12] * a[1] * a[6] + a[12] * a[2] * a[5]
        inv[3] = -a[1] * a[6] * a[11] + a[1] * a[7] * a[10] + a[5] * a[2] * a[11] -
            a[5] * a[3] * a[10] - a[9] * a[2] * a[7] + a[9] * a[3] * a[6]
        inv[7] = a[0] * a[6] * a[11] - a[0] * a[7] * a[10] - a[4] * a[2] * a[11] +
            a[4] * a[3] * a[10] + a[8] * a[2] * a[7] - a[8] * a[3] * a[6]
        inv[11] = -a[0] * a[5] * a[11] + a[0] * a[7] * a[9] + a[4] * a[1] * a[11] -
            a[4] * a[3] * a[9] - a[8] * a[1] * a[7] + a[8] * a[3] * a[5]
        inv[15] = a[0] * a[5] * a[10] - a[0] * a[6] * a[9] - a[4] * a[1] * a[10] +
            a[4] * a[2] * a[9] + a[8] * a[1] * a[6] - a[8] * a[2] * a[5]
        val det = a[0] * inv[0] + a[1] * inv[4] + a[2] * inv[8] + a[3] * inv[12]
        if (abs(det) < 1e-12) return null
        return FloatArray(16) { (inv[it] / det).toFloat() }
    }

    /**
     * Луч из камеры через точку экрана (пиксели) по обратной матрице
     * «проекция · вид»: начало — на ближней плоскости, направление — единичное.
     * Нужен, чтобы попасть в оборудование по рамке ИИ уже после того, как кадр
     * сменился (Frame.hitTest(origin, direction) в ARCore).
     */
    fun rayThrough(invViewProj: FloatArray, sx: Float, sy: Float, width: Int, height: Int): Pair<Vec3, Vec3>? {
        if (width <= 0 || height <= 0) return null
        val nx = 2.0 * sx / width - 1.0
        val ny = 1.0 - 2.0 * sy / height
        fun unproject(nz: Double): Vec3? {
            val m = invViewProj
            val x = m[0] * nx + m[4] * ny + m[8] * nz + m[12]
            val y = m[1] * nx + m[5] * ny + m[9] * nz + m[13]
            val z = m[2] * nx + m[6] * ny + m[10] * nz + m[14]
            val w = m[3] * nx + m[7] * ny + m[11] * nz + m[15]
            if (abs(w) < 1e-9) return null
            return Vec3(x / w, y / w, z / w)
        }
        val near = unproject(-1.0) ?: return null
        val far = unproject(1.0) ?: return null
        val d = far - near
        val len = d.length()
        if (len < 1e-9) return null
        return Pair(near, Vec3(d.x / len, d.y / len, d.z / len))
    }
}
