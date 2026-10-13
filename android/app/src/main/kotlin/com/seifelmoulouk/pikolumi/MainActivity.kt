package com.seifelmoulouk.pikolumi

import com.google.android.gms.ads.MobileAds
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.seifelmoulouk.pikolumi/ads_privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "disablePublisherFirstPartyId" -> {
                        try {
                            result.success(MobileAds.putPublisherFirstPartyIdEnabled(false))
                        } catch (error: Exception) {
                            result.error("publisher-id-setting-failed", error.javaClass.simpleName, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
