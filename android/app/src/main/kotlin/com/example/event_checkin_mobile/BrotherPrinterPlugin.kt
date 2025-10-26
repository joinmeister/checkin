package com.example.event_checkin_mobile

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.brother.ptouch.sdk.*
import com.brother.ptouch.sdk.Printer
import java.util.*
import kotlin.collections.HashMap

class BrotherPrinterPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    private var printer: Printer? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private val discoveredPrinters = mutableListOf<Map<String, Any>>()
    private var isScanning = false
    
    companion object {
        const val CHANNEL_NAME = "brother_printer"
        const val EVENT_CHANNEL_NAME = "brother_printer_events"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "discoverPrinters" -> discoverPrinters(result)
            "connectToPrinter" -> connectToPrinter(call, result)
            "disconnect" -> disconnect(result)
            "printBadge" -> printBadge(call, result)
            "getPrinterStatus" -> getPrinterStatus(result)
            "getPrinterCapabilities" -> getPrinterCapabilities(call, result)
            "testConnection" -> testConnection(result)
            "setPrintSettings" -> setPrintSettings(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun initialize(result: Result) {
        try {
            // Initialize Brother SDK
            printer = Printer()
            bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
            
            if (bluetoothAdapter == null) {
                result.error("NO_BLUETOOTH", "Bluetooth not supported on this device", null)
                return
            }
            
            result.success(true)
            sendEvent("initialized", mapOf("success" to true))
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize Brother SDK: ${e.message}", null)
        }
    }

    private fun discoverPrinters(result: Result) {
        if (isScanning) {
            result.success(discoveredPrinters.toList())
            return
        }
        
        try {
            discoveredPrinters.clear()
            isScanning = true
            
            // Check Bluetooth permissions
            if (!hasBluetoothPermissions()) {
                result.error("NO_PERMISSION", "Bluetooth permissions not granted", null)
                return
            }
            
            // Discover Bluetooth printers
            discoverBluetoothPrinters()
            
            // Discover WiFi printers
            discoverWifiPrinters()
            
            // Return discovered printers after a delay to allow discovery
            Handler(Looper.getMainLooper()).postDelayed({
                isScanning = false
                result.success(discoveredPrinters.toList())
            }, 5000) // 5 second discovery timeout
            
        } catch (e: Exception) {
            isScanning = false
            result.error("DISCOVERY_ERROR", "Failed to discover printers: ${e.message}", null)
        }
    }

    private fun discoverBluetoothPrinters() {
        try {
            if (bluetoothAdapter?.isEnabled != true) {
                return
            }
            
            // Get paired devices
            if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                val pairedDevices = bluetoothAdapter?.bondedDevices
                pairedDevices?.forEach { device ->
                    if (isBrotherPrinter(device)) {
                        val printerInfo = createPrinterInfo(device)
                        discoveredPrinters.add(printerInfo)
                        sendEvent("printerDiscovered", printerInfo)
                    }
                }
            }
            
            // Start discovery for new devices
            bluetoothAdapter?.startDiscovery()
            
        } catch (e: Exception) {
            println("Bluetooth discovery error: ${e.message}")
        }
    }

    private fun discoverWifiPrinters() {
        try {
            // Use Brother SDK to discover network printers
            Thread {
                try {
                    val netPrinters = printer?.getNetPrinters("255.255.255.255")
                    netPrinters?.forEach { netPrinter ->
                        val printerInfo = mapOf(
                            "id" to "wifi_${netPrinter.ipAddress}",
                            "name" to (netPrinter.modelName ?: "Brother Printer"),
                            "model" to (netPrinter.modelName ?: "Unknown"),
                            "connectionType" to "wifi",
                            "ipAddress" to netPrinter.ipAddress,
                            "status" to "disconnected",
                            "isMfiCertified" to false,
                            "capabilities" to getDefaultCapabilities(),
                            "connectionData" to mapOf(
                                "ipAddress" to netPrinter.ipAddress,
                                "macAddress" to (netPrinter.macAddress ?: "")
                            ),
                            "lastSeen" to System.currentTimeMillis()
                        )
                        
                        discoveredPrinters.add(printerInfo)
                        sendEvent("printerDiscovered", printerInfo)
                    }
                } catch (e: Exception) {
                    println("WiFi discovery error: ${e.message}")
                }
            }.start()
            
        } catch (e: Exception) {
            println("WiFi discovery setup error: ${e.message}")
        }
    }

    private fun connectToPrinter(call: MethodCall, result: Result) {
        val printerId = call.argument<String>("printerId")
        val connectionType = call.argument<String>("connectionType")
        
        if (printerId == null || connectionType == null) {
            result.error("INVALID_ARGS", "Missing printerId or connectionType", null)
            return
        }
        
        try {
            val printerInfo = discoveredPrinters.find { it["id"] == printerId }
            if (printerInfo == null) {
                result.error("PRINTER_NOT_FOUND", "Printer not found: $printerId", null)
                return
            }
            
            Thread {
                try {
                    val success = when (connectionType) {
                        "bluetooth" -> connectBluetooth(printerInfo)
                        "wifi" -> connectWifi(printerInfo)
                        "usb" -> connectUsb(printerInfo)
                        else -> false
                    }
                    
                    Handler(Looper.getMainLooper()).post {
                        if (success) {
                            result.success(true)
                            sendEvent("statusChanged", mapOf("status" to "connected"))
                        } else {
                            result.success(false)
                            sendEvent("statusChanged", mapOf("status" to "error"))
                        }
                    }
                } catch (e: Exception) {
                    Handler(Looper.getMainLooper()).post {
                        result.error("CONNECTION_ERROR", "Failed to connect: ${e.message}", null)
                    }
                }
            }.start()
            
        } catch (e: Exception) {
            result.error("CONNECTION_ERROR", "Connection setup failed: ${e.message}", null)
        }
    }

    private fun connectBluetooth(printerInfo: Map<String, Any>): Boolean {
        return try {
            val bluetoothAddress = printerInfo["bluetoothAddress"] as? String
            if (bluetoothAddress != null) {
                printer?.setBluetooth(bluetoothAddress)
                printer?.startCommunication() == PrinterDriverGenerator.ErrorCode.ERROR_NONE
            } else {
                false
            }
        } catch (e: Exception) {
            println("Bluetooth connection error: ${e.message}")
            false
        }
    }

    private fun connectWifi(printerInfo: Map<String, Any>): Boolean {
        return try {
            val ipAddress = printerInfo["ipAddress"] as? String
            if (ipAddress != null) {
                printer?.setIPAddress(ipAddress)
                printer?.startCommunication() == PrinterDriverGenerator.ErrorCode.ERROR_NONE
            } else {
                false
            }
        } catch (e: Exception) {
            println("WiFi connection error: ${e.message}")
            false
        }
    }

    private fun connectUsb(printerInfo: Map<String, Any>): Boolean {
        return try {
            // USB connection implementation would go here
            // This requires USB host mode and proper device detection
            false
        } catch (e: Exception) {
            println("USB connection error: ${e.message}")
            false
        }
    }

    private fun disconnect(result: Result) {
        try {
            printer?.endCommunication()
            result.success(true)
            sendEvent("statusChanged", mapOf("status" to "disconnected"))
        } catch (e: Exception) {
            result.error("DISCONNECT_ERROR", "Failed to disconnect: ${e.message}", null)
        }
    }

    private fun printBadge(call: MethodCall, result: Result) {
        val imageData = call.argument<ByteArray>("imageData")
        val printSettings = call.argument<Map<String, Any>>("printSettings")
        
        if (imageData == null || printSettings == null) {
            result.error("INVALID_ARGS", "Missing imageData or printSettings", null)
            return
        }
        
        Thread {
            try {
                // Configure print settings
                configurePrintSettings(printSettings)
                
                // Send image to printer
                val printResult = printer?.printImage(imageData)
                val success = printResult == PrinterDriverGenerator.ErrorCode.ERROR_NONE
                
                Handler(Looper.getMainLooper()).post {
                    if (success) {
                        result.success(mapOf(
                            "success" to true,
                            "message" to "Print completed successfully"
                        ))
                        sendEvent("statusChanged", mapOf("status" to "connected"))
                    } else {
                        result.success(mapOf(
                            "success" to false,
                            "error" to "Print failed",
                            "errorCode" to printResult?.toString()
                        ))
                        sendEvent("statusChanged", mapOf("status" to "error"))
                    }
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf(
                        "success" to false,
                        "error" to "Print exception: ${e.message}",
                        "errorCode" to "PRINT_EXCEPTION"
                    ))
                }
            }
        }.start()
    }

    private fun configurePrintSettings(settings: Map<String, Any>) {
        try {
            // Configure label size
            val labelSize = settings["labelSize"] as? Map<String, Any>
            if (labelSize != null) {
                val widthMm = (labelSize["widthMm"] as? Number)?.toInt() ?: 62
                val heightMm = (labelSize["heightMm"] as? Number)?.toInt() ?: 29
                
                // Set appropriate Brother label type based on dimensions
                when {
                    widthMm == 62 && heightMm == 29 -> printer?.setPrinterModel(PrinterModel.QL_820NWB)
                    widthMm == 62 && heightMm == 100 -> printer?.setPrinterModel(PrinterModel.QL_820NWB)
                    else -> printer?.setPrinterModel(PrinterModel.QL_820NWB) // Default
                }
            }
            
            // Configure other settings
            val copies = (settings["copies"] as? Number)?.toInt() ?: 1
            val autoCut = settings["autoCut"] as? Boolean ?: true
            val quality = settings["quality"] as? String ?: "normal"
            
            printer?.setNumberOfCopies(copies)
            printer?.setAutoCut(autoCut)
            
            // Set print quality
            when (quality) {
                "draft" -> printer?.setPrintQuality(PrintQuality.FAST)
                "high" -> printer?.setPrintQuality(PrintQuality.HIGH_QUALITY)
                "best" -> printer?.setPrintQuality(PrintQuality.BEST)
                else -> printer?.setPrintQuality(PrintQuality.NORMAL)
            }
            
        } catch (e: Exception) {
            println("Print settings configuration error: ${e.message}")
        }
    }

    private fun getPrinterStatus(result: Result) {
        try {
            val status = printer?.getPrinterStatus()
            val connected = status?.communicationStatus == CommunicationStatus.GOOD
            
            result.success(mapOf(
                "connected" to connected,
                "status" to if (connected) "connected" else "disconnected",
                "batteryLevel" to (status?.batteryLevel ?: 0),
                "errorCode" to (status?.errorCode?.toString() ?: "")
            ))
        } catch (e: Exception) {
            result.success(mapOf(
                "connected" to false,
                "error" to e.message
            ))
        }
    }

    private fun getPrinterCapabilities(call: MethodCall, result: Result) {
        val printerId = call.argument<String>("printerId")
        
        if (printerId == null) {
            result.error("INVALID_ARGS", "Missing printerId", null)
            return
        }
        
        try {
            // Return default capabilities for Brother printers
            result.success(getDefaultCapabilities())
        } catch (e: Exception) {
            result.error("CAPABILITIES_ERROR", "Failed to get capabilities: ${e.message}", null)
        }
    }

    private fun testConnection(result: Result) {
        try {
            Thread {
                try {
                    val status = printer?.getPrinterStatus()
                    val connected = status?.communicationStatus == CommunicationStatus.GOOD
                    
                    Handler(Looper.getMainLooper()).post {
                        result.success(connected)
                    }
                } catch (e: Exception) {
                    Handler(Looper.getMainLooper()).post {
                        result.success(false)
                    }
                }
            }.start()
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun setPrintSettings(call: MethodCall, result: Result) {
        try {
            val settings = call.arguments as? Map<String, Any>
            if (settings != null) {
                configurePrintSettings(settings)
                result.success(true)
            } else {
                result.error("INVALID_ARGS", "Invalid settings", null)
            }
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", "Failed to set settings: ${e.message}", null)
        }
    }

    private fun isBrotherPrinter(device: BluetoothDevice): Boolean {
        val name = device.name?.lowercase() ?: ""
        return name.contains("brother") || 
               name.contains("ql-") || 
               name.contains("pt-") || 
               name.contains("td-")
    }

    private fun createPrinterInfo(device: BluetoothDevice): Map<String, Any> {
        return mapOf(
            "id" to "bt_${device.address}",
            "name" to (device.name ?: "Brother Printer"),
            "model" to (device.name ?: "Unknown"),
            "connectionType" to "bluetooth",
            "bluetoothAddress" to device.address,
            "status" to "disconnected",
            "isMfiCertified" to false,
            "capabilities" to getDefaultCapabilities(),
            "connectionData" to mapOf(
                "bluetoothAddress" to device.address,
                "deviceName" to (device.name ?: "")
            ),
            "lastSeen" to System.currentTimeMillis()
        )
    }

    private fun getDefaultCapabilities(): Map<String, Any> {
        return mapOf(
            "supportedLabelSizes" to listOf(
                mapOf(
                    "id" to "62x29",
                    "name" to "Address Label (62x29mm)",
                    "widthMm" to 62,
                    "heightMm" to 29,
                    "isRoll" to true
                ),
                mapOf(
                    "id" to "62x100",
                    "name" to "Shipping Label (62x100mm)",
                    "widthMm" to 62,
                    "heightMm" to 100,
                    "isRoll" to true
                )
            ),
            "maxResolutionDpi" to 300,
            "supportsColor" to false,
            "supportsCutting" to true,
            "maxPrintWidth" to 62,
            "supportedFormats" to listOf("PNG", "BMP"),
            "supportsBluetooth" to true,
            "supportsWifi" to true,
            "supportsUsb" to false
        )
    }

    private fun hasBluetoothPermissions(): Boolean {
        return ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED &&
               ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED &&
               ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun sendEvent(type: String, data: Map<String, Any>) {
        eventSink?.success(mapOf(
            "type" to type,
            "data" to data,
            "timestamp" to System.currentTimeMillis()
        ))
    }
}