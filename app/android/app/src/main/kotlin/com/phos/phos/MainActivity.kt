package com.phos.phos

import android.app.Activity
import android.content.Context
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.SaveHandle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry

class MainActivity : FlutterActivity() {
    private val mtpUsbPlugin = MtpUsbPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mtpUsbPlugin.onAttachedToActivity(
            object : PluginRegistry.ActivityAware.ActivityBinding {
                override fun activity(): Activity = this@MainActivity

                override fun applicationContext(): Context = this@MainActivity.applicationContext

                override fun lifecycle(): Lifecycle = this@MainActivity.lifecycle

                override fun saveHandle(): SaveHandle = SaveHandle()

                override fun binaryMessenger(): BinaryMessenger =
                    flutterEngine.dartExecutor.binaryMessenger
            }
        )
    }
}