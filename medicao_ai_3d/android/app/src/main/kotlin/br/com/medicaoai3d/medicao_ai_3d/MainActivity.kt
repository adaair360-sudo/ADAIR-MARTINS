package br.com.medicaoai3d.medicao_ai_3d

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var openCvChannel: OpenCvChannel? = null
    private var arCoreChannel: ArCoreChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        openCvChannel = OpenCvChannel(applicationContext, messenger)
        arCoreChannel = ArCoreChannel(this, messenger)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "br.com.medicaoai3d/arcore_view",
            ArCoreViewFactory(this, messenger),
        )
    }
}
