package com.example.hey_helpy

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine

/// Шаг 28: обычная сборка — VPS-эксперимента нет. Канал hey_helpy/vps не
/// регистрируется, Flutter получает MissingPluginException и кнопок не показывает.
object VpsHook {
    fun register(activity: Activity, engine: FlutterEngine) {}

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean = false
}
