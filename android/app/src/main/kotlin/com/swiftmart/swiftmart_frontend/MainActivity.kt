package com.swiftmart.swiftmart_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.ActivityNotFoundException
import android.content.Intent
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient

class MainActivity : FlutterActivity() {
    private var printView: WebView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.swiftmart/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareOrder" && call.method != "shareReceipt") {
                    result.notImplemented()
                } else {
                    val text = call.arguments as? String
                    if (text.isNullOrBlank()) {
                        result.error("invalid_order", "Order text is missing", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            val title = if (call.method == "shareReceipt") "Share receipt" else "Share order with the shop"
                            startActivity(Intent.createChooser(intent, title))
                            result.success(null)
                        } catch (error: ActivityNotFoundException) {
                            result.error("sharing_unavailable", "No app can share this order", null)
                        } catch (error: SecurityException) {
                            result.error("sharing_denied", "Sharing was blocked by the device", null)
                        }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.swiftmart/printing")
            .setMethodCallHandler { call, result ->
                if (call.method != "printReceipt") {
                    result.notImplemented()
                } else {
                    val html = call.arguments as? String
                    if (html == null) {
                        result.error("invalid_receipt", "Receipt content is missing", null)
                    } else {
                        val view = WebView(this)
                        printView = view
                        view.webViewClient = object : WebViewClient() {
                            override fun onPageFinished(view: WebView, url: String?) {
                                val manager = getSystemService(Context.PRINT_SERVICE) as PrintManager
                                manager.print("SwiftMart receipt", view.createPrintDocumentAdapter("SwiftMart receipt"), null)
                            }
                        }
                        view.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
                        result.success(null)
                    }
                }
            }
    }
}
