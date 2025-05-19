package com.example.flutter_wrapper

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.Keep
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

@Keep
class FlutterModuleWrapper private constructor() {
    companion object {
        private const val ENGINE_ID = "flutter_module_engine"
        private const val CHANNEL = "com.example.flutter_wrapper/platform_channel"
        private var instance: FlutterModuleWrapper? = null
        private lateinit var flutterEngine: FlutterEngine
        private var methodChannel: MethodChannel? = null
        private val pendingMessages = mutableListOf<String>()

        @JvmStatic
        fun getInstance(context: Context): FlutterModuleWrapper {
            if (instance == null) {
                instance = FlutterModuleWrapper()
                initializeFlutter(context.applicationContext)
            }
            return instance!!
        }

        private fun initializeFlutter(context: Context) {
            // Initialize Flutter engine
            flutterEngine = FlutterEngine(context)
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            // Cache the engine
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
            
            // Set up method channel
            setupMethodChannel(context)
        }

        private fun setupMethodChannel(context: Context) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            
            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendMessage" -> {
                        val message = call.argument<String>("message")
                        val timestamp = call.argument<String>("timestamp")
                        
                        val processedMessage = "Android received: $message at $timestamp"
                        result.success(processedMessage)
                    }
                    
                    "getBatteryLevel" -> {
                        val batteryLevel = getBatteryLevel(context)
                        
                        if (batteryLevel != -1) {
                            result.success(batteryLevel)
                        } else {
                            result.error("UNAVAILABLE", "Battery level not available.", null)
                        }
                    }
                    
                    "getPendingMessages" -> {
                        result.success(pendingMessages.toList())
                        pendingMessages.clear()
                    }
                    
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        private fun getBatteryLevel(context: Context): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            } else {
                val intent = ContextWrapper(context)
                    .registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                
                val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                
                if (level != -1 && scale != -1) {
                    (level * 100 / scale.toFloat()).toInt()
                } else {
                    -1
                }
            }
        }
        
        // Added method to access the method channel
        @JvmStatic
        fun sendMessageToFlutterInternal(message: String) {
            if (methodChannel != null) {
                // Ensure this runs on the main thread
                Handler(Looper.getMainLooper()).post {
                    methodChannel?.invokeMethod(
                        "messageFromNative",
                        mapOf("message" to message)
                    )
                }
            } else {
                pendingMessages.add(message)
            }
        }
        
        // Method to add pending messages
        @JvmStatic
        fun addPendingMessage(message: String) {
            pendingMessages.add(message)
        }
    }

    /**
     * Open the Flutter module with an optional message
     */
    fun openFlutterModule(context: Context, message: String? = null) {
        message?.let {
            addPendingMessage(it)
        }
        
        val intent = FlutterActivity
            .withCachedEngine(ENGINE_ID)
            .build(context)
        
        context.startActivity(intent)
    }

    /**
     * Send a message directly to Flutter if it's currently visible
     */
    fun sendMessageToFlutter(message: String) {
        sendMessageToFlutterInternal(message)
    }
} 