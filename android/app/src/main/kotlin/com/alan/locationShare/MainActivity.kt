package com.alan.locationShare

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.alan.locationShare/amap_privacy",
        ).setMethodCallHandler { call, result ->
            if (call.method == "syncMapPrivacy") {
                syncAmapMapPrivacy(applicationContext)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun syncAmapMapPrivacy(context: Context) {
        try {
            val clazz = Class.forName("com.amap.api.maps.MapsInitializer")
            val show = clazz.getMethod(
                "updatePrivacyShow",
                Context::class.java,
                Boolean::class.javaPrimitiveType,
                Boolean::class.javaPrimitiveType,
            )
            show.invoke(null, context, true, true)
            val agree = clazz.getMethod(
                "updatePrivacyAgree",
                Context::class.java,
                Boolean::class.javaPrimitiveType,
            )
            agree.invoke(null, context, true)
        } catch (_: Throwable) {
        }
    }
}
