package com.locationshare.location_share

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.locationshare.location_share/amap_privacy",
        ).setMethodCallHandler { call, result ->
            if (call.method == "syncMapPrivacy") {
                syncAmapMapPrivacy(applicationContext)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * 地图 SDK [com.amap.api.maps.MapsInitializer] 需在任意地图接口前调用；
     * 通过反射避免 app 模块再声明一份 3dmap 依赖，类由地图插件打入运行时 classpath。
     */
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
            // 与插件内 ConvertUtil 一致：失败时不阻断 Flutter；可结合 logcat 排查
        }
    }
}
