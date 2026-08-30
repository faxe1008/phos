package com.phos.phos

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Host-side USB transport for the Nikon PTP/MTP protocol.
 *
 * Exposes the raw bulk IN/OUT byte streams of the camera's MTP interface
 * (USB class 0x06, subclass 0x01) over the "phos.mtp_usb" method channel.
 * All PTP framing, session handling and picture control encoding live in
 * Dart (phos_core's camera module); this class only moves bytes.
 *
 * Expected to be verified against a real Z50II over USB-OTG; the wire
 * protocol itself is covered by unit tests in the core package.
 */
class MtpUsbPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "phos.mtp_usb"
        const val TIMEOUT_MS = 10_000
        private const val TAG = "MtpUsbPlugin"

        private const val CLASS_MASS_STORAGE = 0x06
        private const val SUBCLASS_PTP = 0x01

        // Android 16 (API 36) removed these USB host constants from the
        // public API (UsbEndpoint.TYPE_BULK, UsbDevice.USB_DIR_IN,
        // UsbManager.ACTION_USB_PERMISSION). The underlying values and the
        // runtime permission flow are unchanged, so use them directly.
        private const val EP_TYPE_BULK = 0x02
        private const val EP_DIR_IN = 0x80
        private const val ACTION_USB_PERMISSION =
            "android.hardware.usb.action.USB_PERMISSION"
    }

    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var activity: Activity? = null
    private var receiverActivity: Activity? = null
    private var channel: MethodChannel? = null
    private var usb: UsbManager? = null

    private var device: UsbDevice? = null
    private var connection: UsbDeviceConnection? = null
    private var mtpInterface: UsbInterface? = null
    private var epIn: UsbEndpoint? = null
    private var epOut: UsbEndpoint? = null

    private var permissionResult: MethodChannel.Result? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            if (intent?.action != ACTION_USB_PERMISSION) return
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            val dev: UsbDevice? = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
            }
            val r = permissionResult
            permissionResult = null
            r?.success(dev != null && granted && usb?.hasPermission(dev) == true)
        }
    }

    // ------------------------------------------------------- FlutterPlugin --

    override fun onAttachedToEngine(flutterBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterBinding
        val appContext = flutterBinding.applicationContext
        usb = appContext.getSystemService(Context.USB_SERVICE) as UsbManager
        if (channel == null) {
            channel = MethodChannel(flutterBinding.binaryMessenger, CHANNEL)
            channel?.setMethodCallHandler(this)
        }
        registerReceiverIfNeeded()
    }

    override fun onDetachedFromEngine(flutterBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = null
        unregisterReceiver()
        closeQuietly()
        channel?.setMethodCallHandler(null)
        channel = null
        usb = null
    }

    // ----------------------------------------------------------- ActivityAware --

    override fun onAttachedToActivity(activityBinding: ActivityPluginBinding) {
        activity = activityBinding.activity
        registerReceiverIfNeeded()
    }

    override fun onReattachedToActivityForConfigChanges(activityBinding: ActivityPluginBinding) {
        activity = activityBinding.activity
        registerReceiverIfNeeded()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unregisterReceiver()
    }

    override fun onDetachedFromActivity() {
        unregisterReceiver()
        activity = null
    }

    private fun registerReceiverIfNeeded() {
        val a = activity ?: return
        if (receiverActivity === a) return
        unregisterReceiver()
        a.registerReceiver(receiver, IntentFilter(ACTION_USB_PERMISSION))
        receiverActivity = a
    }

    private fun unregisterReceiver() {
        val a = receiverActivity ?: return
        try {
            a.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
        receiverActivity = null
    }

    // ---------------------------------------------------------- method channel --

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "listDevices" -> result.success(listDevices())
                "requestPermission" ->
                    requestPermission(call.argument<String>("name")!!, result)
                "open" -> openDevice(call.argument<String>("name")!!, result)
                "write" -> {
                    val list =
                        call.argument<List<Int>>("bytes")
                            ?: throw IllegalArgumentException("bytes")
                    val bytes = ByteArray(list.size) { i -> list[i].toByte() }
                    writeBytes(bytes, result)
                }
                "read" -> readBytes(call.argument<Int>("count") ?: 0, result)
                "recover" -> recover(result)
                "close" -> {
                    closeQuietly()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w(TAG, "method ${call.method} failed", e)
            result.error("MtpError", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun listDevices(): List<Map<String, Any?>> {
        val m = usb ?: return emptyList()
        val out = mutableListOf<Map<String, Any?>>()
        for ((name, dev) in m.deviceList) {
            val hasMtp = (0 until dev.interfaceCount).any { i ->
                val iface = dev.getInterface(i)
                iface.interfaceClass == CLASS_MASS_STORAGE &&
                    iface.interfaceSubclass == SUBCLASS_PTP
            }
            if (hasMtp) {
                val label = listOfNotNull(dev.manufacturerName, dev.productName)
                    .joinToString(" ")
                    .ifEmpty { "Camera ${dev.deviceName}" }
                out.add(
                    mapOf(
                        "name" to name,
                        "label" to label,
                        "vendorId" to dev.vendorId,
                        "productId" to dev.productId,
                        "granted" to m.hasPermission(dev),
                    )
                )
            }
        }
        return out
    }

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val ctx = binding?.applicationContext
            ?: throw IllegalStateException("not attached")
        val m = usb ?: throw IllegalStateException("no UsbManager")
        val dev = m.deviceList[name] ?: throw IllegalStateException("device not found: $name")
        if (m.hasPermission(dev)) {
            result.success(true)
            return
        }
        permissionResult = result
        val flags = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
        val pi = PendingIntent.getBroadcast(
            ctx,
            0,
            Intent(ACTION_USB_PERMISSION),
            flags
        )
        // On API 36 requestPermission returns void; a refusal (or an
        // ignored dialog) simply never delivers the broadcast, in which
        // case the Dart side times out waiting for the channel reply.
        m.requestPermission(dev, pi)
    }

    private fun openDevice(name: String, result: MethodChannel.Result) {
        val m = usb ?: throw IllegalStateException("no UsbManager")
        val dev = m.deviceList[name] ?: throw IllegalStateException("device not found: $name")
        if (!m.hasPermission(dev)) {
            throw IllegalStateException("no USB permission for $name")
        }
        closeQuietly()
        val conn = m.openDevice(dev) ?: throw IllegalStateException("openDevice returned null")
        val ifaces = (0 until dev.interfaceCount).map { dev.getInterface(it) }
        val iface =
            ifaces.firstOrNull {
                it.interfaceClass == CLASS_MASS_STORAGE &&
                    it.interfaceSubclass == SUBCLASS_PTP &&
                    it.interfaceProtocol == 0x01
            }
                ?: ifaces.firstOrNull {
                    it.interfaceClass == CLASS_MASS_STORAGE && it.interfaceSubclass == SUBCLASS_PTP
                }
                ?: throw IllegalStateException("no MTP interface on $name")
        if (!conn.claimInterface(iface, true)) {
            conn.close()
            throw IllegalStateException("claimInterface failed")
        }
        var inEp: UsbEndpoint? = null
        var outEp: UsbEndpoint? = null
        for (i in 0 until iface.endpointCount) {
            val ep = iface.getEndpoint(i)
            if (ep.type != EP_TYPE_BULK) continue
            if ((ep.direction and EP_DIR_IN) != 0) {
                inEp = inEp ?: ep
            } else {
                outEp = outEp ?: ep
            }
        }
        if (inEp == null || outEp == null) {
            conn.releaseInterface(iface)
            conn.close()
            throw IllegalStateException("MTP interface lacks bulk IN/OUT endpoints")
        }
        device = dev
        connection = conn
        mtpInterface = iface
        epIn = inEp
        epOut = outEp
        result.success(null)
    }

    private fun writeBytes(data: ByteArray, result: MethodChannel.Result) {
        val conn = connection ?: throw IllegalStateException("device not open")
        val ep = epOut ?: throw IllegalStateException("no bulk OUT endpoint")
        var offset = 0
        while (offset < data.size) {
            val chunk = data.copyOfRange(offset, data.size)
            val n = conn.bulkTransfer(ep, chunk, chunk.size, TIMEOUT_MS)
            if (n <= 0) {
                throw IllegalStateException(
                    if (n == -1) "bulk OUT timed out (camera gone or stalled?)"
                    else "bulk OUT made no progress"
                )
            }
            offset += n
        }
        result.success(null)
    }

    private fun readBytes(count: Int, result: MethodChannel.Result) {
        if (count <= 0 || count > (1 shl 20)) {
            throw IllegalArgumentException("count out of range: $count")
        }
        val conn = connection ?: throw IllegalStateException("device not open")
        val ep = epIn ?: throw IllegalStateException("no bulk IN endpoint")
        val buf = ByteArray(count)
        var offset = 0
        while (offset < count) {
            val n = conn.bulkTransfer(ep, buf, offset, count - offset, TIMEOUT_MS)
            if (n <= 0) {
                throw IllegalStateException(
                    if (n == -1) "bulk IN timed out (camera gone or stalled?)"
                    else "bulk IN made no progress"
                )
            }
            offset += n
        }
        result.success(buf.toList())
    }

    private fun recover(result: MethodChannel.Result) {
        val conn = connection
        val iface = mtpInterface
        if (conn != null && iface != null) {
            conn.releaseInterface(iface)
            if (!conn.claimInterface(iface, true)) {
                closeQuietly()
                throw IllegalStateException("re-claim failed after recovery")
            }
        }
        result.success(null)
    }

    private fun closeQuietly() {
        try {
            val conn = connection
            val iface = mtpInterface
            if (conn != null && iface != null) {
                conn.releaseInterface(iface)
            }
            conn?.close()
        } catch (_: Exception) {
        }
        connection = null
        mtpInterface = null
        epIn = null
        epOut = null
        device = null
    }
}