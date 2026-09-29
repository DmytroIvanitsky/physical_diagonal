package dev.ivanitsky.physical_diagonal

import android.app.Activity
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import android.os.Build
import android.util.DisplayMetrics
import androidx.window.layout.WindowMetricsCalculator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.math.pow
import kotlin.math.sqrt

class PhysicalDiagonalPlugin :
    FlutterPlugin, MethodCallHandler, ActivityAware, ComponentCallbacks2,
    EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "physical_diagonal")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "physical_diagonal_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getMetrics" -> result.success(calculateMetrics())
            else -> result.notImplemented()
        }
    }

    private fun calculateMetrics(): Map<String, Double> {
        val currentActivity = activity
            ?: return mapOf("deviceDiagonal" to -1.0, "windowDiagonal" to -1.0)

        val displayMetrics = DisplayMetrics()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            currentActivity.display?.getRealMetrics(displayMetrics)
        } else {
            @Suppress("DEPRECATION")
            currentActivity.windowManager.defaultDisplay.getRealMetrics(displayMetrics)
        }
        if (displayMetrics.xdpi <= 0f || displayMetrics.ydpi <= 0f) {
            return mapOf("deviceDiagonal" to -1.0, "windowDiagonal" to -1.0)
        }

        val calculator = WindowMetricsCalculator.getOrCreate()
        val maxBounds = calculator.computeMaximumWindowMetrics(currentActivity).bounds
        val currentBounds = calculator.computeCurrentWindowMetrics(currentActivity).bounds

        fun diagonalInches(widthPx: Int, heightPx: Int): Double {
            val wIn = widthPx / displayMetrics.xdpi.toDouble()
            val hIn = heightPx / displayMetrics.ydpi.toDouble()
            return sqrt(wIn.pow(2.0) + hIn.pow(2.0))
        }

        return mapOf(
            "deviceDiagonal" to diagonalInches(maxBounds.width(), maxBounds.height()),
            "windowDiagonal" to diagonalInches(currentBounds.width(), currentBounds.height()),
        )
    }

    private fun pushMetricsSafely() {
        val metrics = calculateMetrics()
        val device = metrics["deviceDiagonal"] ?: -1.0
        val window = metrics["windowDiagonal"] ?: -1.0
        
        if (device > 0.0 && window > 0.0) {
            eventSink?.success(metrics)
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        pushMetricsSafely()
    }

    override fun onLowMemory() {}

    override fun onTrimMemory(level: Int) {}

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (activity != null) pushMetricsSafely()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activity?.registerComponentCallbacks(this)
        pushMetricsSafely()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity?.unregisterComponentCallbacks(this)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activity?.registerComponentCallbacks(this)
        pushMetricsSafely()
    }

    override fun onDetachedFromActivity() {
        activity?.unregisterComponentCallbacks(this)
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}