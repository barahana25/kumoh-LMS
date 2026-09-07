package ac.kumoh.kumoh_lms

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ac.kumoh.kumoh_lms/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryUnrestricted" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openAppSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("settings_unavailable", "설정을 열 수 없습니다.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
