package com.example.event_checkin_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register Brother Printer Plugin
        flutterEngine.plugins.add(BrotherPrinterPlugin())
    }
}
