package com.shootingstar.shootingstar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shootingstar/commerce_config")
            .setMethodCallHandler { call, result ->
                if (call.method == "admobAppId") {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    result.success(info.metaData?.getString("com.google.android.gms.ads.APPLICATION_ID") ?: "")
                } else result.notImplemented()
            }
    }
}
