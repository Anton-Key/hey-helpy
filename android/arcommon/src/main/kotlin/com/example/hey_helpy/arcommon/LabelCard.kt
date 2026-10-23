package com.example.hey_helpy.arcommon

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Шаг 28 → 31: табличка над оборудованием — обычный Android-View поверх камеры
 * (белая карточка, рамка цвета системы, название и строка под ним).
 * Положение на экране считает PoseMath.project — без 3D-материалов.
 */
object LabelCard {
    fun create(context: Context, name: String, line: String, color: Int, onTap: () -> Unit): LinearLayout {
        fun dp(v: Int) = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), context.resources.displayMetrics,
        ).toInt()
        val box = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = GradientDrawable().apply {
                setColor(0xF2FFFFFF.toInt())
                cornerRadius = dp(12).toFloat()
                setStroke(dp(3), color)
            }
            elevation = dp(4).toFloat()
            setOnClickListener { onTap() }
            visibility = View.GONE
        }
        box.addView(TextView(context).apply {
            text = name.ifBlank { "—" }
            setTextColor(0xFF111111.toInt())
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
        })
        box.addView(TextView(context).apply {
            text = line
            setTextColor(0xFF3A3A3C.toInt())
            textSize = 13f
            visibility = if (line.isBlank()) View.GONE else View.VISIBLE
        })
        return box
    }

    /** Поменять текст и цвет уже показанной таблички (переставили на другое оборудование). */
    fun update(box: LinearLayout, name: String, line: String, color: Int) {
        (box.getChildAt(0) as? TextView)?.text = name.ifBlank { "—" }
        (box.getChildAt(1) as? TextView)?.apply {
            text = line
            visibility = if (line.isBlank()) View.GONE else View.VISIBLE
        }
        (box.background as? GradientDrawable)?.setStroke(
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 3f, box.resources.displayMetrics).toInt(),
            color,
        )
    }
}
