package br.com.medicaoai3d.medicao_ai_3d

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Session
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ArCoreChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "br.com.medicaoai3d/arcore")
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkAvailability" -> checkAvailability(result, attempt = 0)
            "requestInstall" -> {
                try {
                    val installStatus = ArCoreApk.getInstance().requestInstall(activity, true)
                    result.success(
                        mapOf(
                            "installed" to (installStatus == ArCoreApk.InstallStatus.INSTALLED),
                            "status" to installStatus.name,
                        ),
                    )
                } catch (e: Throwable) {
                    result.error(
                        "ARCORE_INSTALL_ERROR",
                        "Não foi possível solicitar instalação do ARCore: ${e.message}",
                        null,
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun checkAvailability(result: MethodChannel.Result, attempt: Int) {
        try {
            val availability = ArCoreApk.getInstance().checkAvailability(activity)
            if (availability.isTransient && attempt < 5) {
                mainHandler.postDelayed({ checkAvailability(result, attempt + 1) }, 220)
                return
            }

            val isSupported = availability.isSupported
            val isInstalled = availability == ArCoreApk.Availability.SUPPORTED_INSTALLED
            var depthSupported = false

            if (isInstalled) {
                try {
                    val session = Session(activity)
                    depthSupported = session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
                    session.close()
                } catch (_: Throwable) {
                    depthSupported = false
                }
            }

            result.success(
                mapOf(
                    "status" to availability.name,
                    "isSupported" to isSupported,
                    "isInstalled" to isInstalled,
                    "needsInstall" to (
                        availability == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED ||
                            availability == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD
                        ),
                    "depthSupported" to depthSupported,
                ),
            )
        } catch (e: Throwable) {
            result.success(
                mapOf(
                    "status" to "UNAVAILABLE",
                    "isSupported" to false,
                    "isInstalled" to false,
                    "needsInstall" to false,
                    "depthSupported" to false,
                    "error" to e.message,
                ),
            )
        }
    }
}
