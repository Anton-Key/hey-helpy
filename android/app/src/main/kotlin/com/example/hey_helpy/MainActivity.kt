package com.example.hey_helpy

import android.content.Context
import android.location.LocationManager
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Шаг 27: «честные» часы для работы без сети (lib/features/offline/device_clock.dart).
/// mono — миллисекунды с загрузки телефона (не меняются при переводе часов),
/// boot — номер загрузки, gps_time / gps_elapsed — время спутников последнего
/// GPS-фикса и момент фикса по монотонным часам.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hey_helpy/clock")
            .setMethodCallHandler { call, result ->
                if (call.method != "read") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val m = HashMap<String, Any?>()
                m["wall"] = System.currentTimeMillis()
                m["mono"] = SystemClock.elapsedRealtime()
                if (Build.VERSION.SDK_INT >= 24) {
                    try {
                        m["boot"] = Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT)
                    } catch (_: Exception) {
                    }
                }
                try {
                    val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    val loc = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    if (loc != null) {
                        m["gps_time"] = loc.time
                        m["gps_elapsed"] = loc.elapsedRealtimeNanos / 1_000_000
                    }
                } catch (_: SecurityException) {
                } catch (_: Exception) {
                }
                result.success(m)
            }
    }
}
