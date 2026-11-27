package com.swiftmart.swiftmart_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient

class MainActivity : FlutterActivity() {
    private var printView: WebView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
