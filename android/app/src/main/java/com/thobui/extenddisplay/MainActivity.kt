package com.thobui.extenddisplay

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import kotlin.math.roundToInt

class MainActivity : Activity(), SurfaceHolder.Callback {
    private var client: StreamClient? = null
    private lateinit var statusView: TextView
    private lateinit var touch: TouchHandler
    private val handler = Handler(Looper.getMainLooper())
    private var pendingStart: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= 28) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }

        val surfaceView = SurfaceView(this)
        statusView = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding(48, 48, 48, 48)
            text = "Đang khởi động…"
        }
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            addView(surfaceView, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            addView(statusView, FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
        }
        setContentView(root)

        touch = TouchHandler(this, surfaceView) { bytes -> client?.send(bytes) }
        root.setOnTouchListener { v, e -> touch.onTouch(v, e) }
        surfaceView.holder.addCallback(this)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemUi()
    }

    private fun hideSystemUi() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let {
                it.hide(WindowInsets.Type.systemBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) = Unit

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (width < height) return // chờ xoay ngang
        val w = width and 1.inv()
        val h = height and 1.inv()
        val current = client
        if (current != null && current.width == w && current.height == h) return

        // Debounce: kích thước surface đổi vài lần khi ẩn thanh hệ thống.
        pendingStart?.let { handler.removeCallbacks(it) }
        pendingStart = Runnable {
            client?.stop()
            val dpi = resources.displayMetrics.xdpi.roundToInt()
            client = StreamClient(holder.surface, w, h, dpi) { msg ->
                runOnUiThread {
                    statusView.text = msg
                    statusView.visibility = if (msg.isEmpty()) View.GONE else View.VISIBLE
                }
            }.also { it.start() }
        }.also { handler.postDelayed(it, 300) }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        pendingStart?.let { handler.removeCallbacks(it) }
        client?.stop()
        client = null
    }
}
