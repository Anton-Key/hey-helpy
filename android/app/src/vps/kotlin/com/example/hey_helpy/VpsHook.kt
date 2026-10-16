package com.example.hey_helpy

import android.app.Activity
import android.content.Intent
import com.example.hey_helpy.vps.VpsActivity
import com.example.hey_helpy.vps.VpsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Шаг 28: VPS-сборка (-PwithVps=true). Канал hey_helpy/vps:
///   status → {available, token: ok|missing|expired, tokenExpiresAt, arcore: supported|unsupported|unknown}
///   open(args) → открывает VpsActivity; ответ, когда экран закрыт: {assetId?}
object VpsHook {
    private const val REQUEST = 2807
    private var pending: MethodChannel.Result? = null

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "hey_helpy/vps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(VpsContract.status(activity))
                    "open" -> {
                        if (pending != null) {
                            result.error("busy", null, null)
                            return@setMethodCallHandler
                        }
                        @Suppress("UNCHECKED_CAST")
                        val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                        val intent = Intent(activity, VpsActivity::class.java)
                        VpsContract.putArgs(intent, args)
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
        r?.success(VpsContract.readResult(resultCode, data))
        return true
    }
}
