package com.example.hey_helpy.arlabel

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import java.io.ByteArrayOutputStream

/**
 * Шаг 31: кадр камеры ARCore (YUV_420_888) → JPEG ≤ 1280 px, повёрнутый «как
 * видит человек». Снимок живёт только в памяти: уходит в photo-identify и, если
 * человек сам нажмёт «Создать заявку», — фото «до» новой заявки.
 */
object CameraJpeg {
    class Nv21(val bytes: ByteArray, val width: Int, val height: Int)

    /** Скопировать кадр (быстро, в потоке GL — Image надо сразу закрыть). */
    fun copy(image: Image): Nv21 {
        val w = image.width
        val h = image.height
        val out = ByteArray(w * h * 3 / 2)
        val y = image.planes[0]
        val yBuf = y.buffer
        for (row in 0 until h) {
            val base = row * y.rowStride
            for (col in 0 until w) out[row * w + col] = yBuf.get(base + col * y.pixelStride)
        }
        val u = image.planes[1]
        val v = image.planes[2]
        val uBuf = u.buffer
        val vBuf = v.buffer
        var o = w * h
        for (row in 0 until h / 2) {
            for (col in 0 until w / 2) {
                out[o++] = vBuf.get(row * v.rowStride + col * v.pixelStride)
                out[o++] = uBuf.get(row * u.rowStride + col * u.pixelStride)
            }
        }
        return Nv21(out, w, h)
    }

    /** NV21 → JPEG: повернуть на [rotation]°, вписать в [max] px, качество 80 %. */
    fun toJpeg(frame: Nv21, rotation: Int, max: Int = 1280): ByteArray {
        val raw = ByteArrayOutputStream()
        YuvImage(frame.bytes, ImageFormat.NV21, frame.width, frame.height, null)
            .compressToJpeg(Rect(0, 0, frame.width, frame.height), 92, raw)
        val src = BitmapFactory.decodeByteArray(raw.toByteArray(), 0, raw.size())
        val scale = ArLabelLogic.fitScale(frame.width, frame.height, max).toFloat()
        val m = Matrix().apply {
            postScale(scale, scale)
            postRotate(rotation.toFloat())
        }
        val out = Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
        if (out !== src) src.recycle()
        val jpeg = ByteArrayOutputStream()
        out.compress(Bitmap.CompressFormat.JPEG, 80, jpeg)
        out.recycle()
        return jpeg.toByteArray()
    }
}
