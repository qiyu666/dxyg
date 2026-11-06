package com.qiyu666.ants

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.webkit.WebSettings
import android.webkit.WebView

class MainActivity : Activity() {

    private lateinit var web: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        web = WebView(this)
        val s: WebSettings = web.settings
        s.javaScriptEnabled = true
        s.domStorageEnabled = true          // 允许 localStorage 存档
        s.databaseEnabled = true
        s.setSupportMultipleWindows(false)
        web.setBackgroundColor(0xFF0D0804.toInt())  // 暗底，避免启动白闪

        setContentView(web)

        // 锁屏常亮：游戏中不熄屏
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // 全屏沉浸：隐藏状态栏/导航栏，下滑可临时露出
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val c = window.insetsController
            c?.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
            c?.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }

        // 竖屏已在 Manifest 锁定；加载离线自包含的游戏
        web.loadUrl("file:///android_asset/ant-kingdom.html")
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // 有网页导航栈（如从地图编辑器进入）先回退，否则退出 App
        if (web.canGoBack()) web.goBack() else super.onBackPressed()
    }

    override fun onResume() {
        super.onResume()
        web.onResume()
    }

    override fun onPause() {
        web.onPause()
        super.onPause()
    }
}
