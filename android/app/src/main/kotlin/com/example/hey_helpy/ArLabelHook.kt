package com.example.hey_helpy

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.example.hey_helpy.arcommon.ArTexts
import com.example.hey_helpy.arlabel.ArLabelActivity
import com.example.hey_helpy.arlabel.ArLabelContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Шаг 31: «AR-метки» — в основной сборке. Канал hey_helpy/arlabel:
///   status → {available, arcore: supported|unsupported|unknown, installed, camera: granted|ask}
///   open(args) → открывает ArLabelActivity; ответ, когда экран закрыт:
///     {action: asset|order, assetId, identify?, photoPath?, takenAt?, journalId?} или {}
object ArLabelHook {
    private const val REQUEST = 3101
    private var pending: MethodChannel.Result? = null

    fun register(activity: Activity, engine: FlutterEngine) {
        val main = Handler(Looper.getMainLooper())
        MethodChannel(engine.dartExecutor.binaryMessenger, "hey_helpy/arlabel")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Проверка ARCore может ждать до ~2 с — не в главном потоке.
                    "status" -> Thread {
                        val m = try {
                            ArLabelContract.status(activity)
                        } catch (_: Exception) {
                            mapOf("available" to false)
                        }
                        main.post { result.success(m) }
                    }.start()
                    "open" -> {
                        if (pending != null) {
                            result.error("busy", null, null)
                            return@setMethodCallHandler
                        }
                        @Suppress("UNCHECKED_CAST")
                        val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                        val intent = Intent(activity, ArLabelActivity::class.java)
                        ArTexts.putArgs(intent, args)
                        pending = result
                        @Suppress("DEPRECATION")
                        activity.startActivityForResult(intent, REQUEST)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val r = pending
        pending = null
        r?.success(ArLabelContract.readResult(resultCode, data))
        return true
    }
}
