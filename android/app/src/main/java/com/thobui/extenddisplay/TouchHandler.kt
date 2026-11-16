package com.thobui.extenddisplay

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Cảm ứng -> Mac.
 * - Chạm nhanh: click trái
 * - Giữ lâu (500ms) không di chuyển: click phải
 * - Một ngón kéo: cuộn (khi đang zoom thì pan màn hình phóng to)
 * - Hai ngón: chụm/mở = zoom cục bộ trên Android, kéo = cuộn
 */
class TouchHandler(
    context: Context,
    private val zoomTarget: View,
    private val send: (ByteArray) -> Unit,
) {
    private enum class State { IDLE, PENDING, SCROLL1, PAN, MULTI, CONSUMED }

    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private val handler = Handler(Looper.getMainLooper())
    private var state = State.IDLE
    private var viewW = 1f
    private var viewH = 1f
    private var downX = 0f
    private var downY = 0f
    private var lastX = 0f
    private var lastY = 0f
    private var lastSpan = 0f
    private var rebase = false

    private var scale = 1f
    private var tx = 0f
    private var ty = 0f

    init {
        zoomTarget.pivotX = 0f
        zoomTarget.pivotY = 0f
    }

    private val longPress = Runnable {
        if (state == State.PENDING) {
            send(Protocol.input(Protocol.ACTION_RIGHT_CLICK, nx(downX), ny(downY)))
            state = State.CONSUMED
        }
    }

    fun onTouch(v: View, e: MotionEvent): Boolean {
        viewW = v.width.toFloat().coerceAtLeast(1f)
        viewH = v.height.toFloat().coerceAtLeast(1f)

        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = e.x; downY = e.y
                lastX = e.x; lastY = e.y
                state = State.PENDING
                handler.postDelayed(longPress, 500)
            }

            MotionEvent.ACTION_POINTER_DOWN -> {
                handler.removeCallbacks(longPress)
                state = State.MULTI
                rebase = true
            }

            MotionEvent.ACTION_POINTER_UP -> {
                if (state == State.MULTI) rebase = true
            }

            MotionEvent.ACTION_MOVE -> when (state) {
                State.PENDING -> if (hypot(e.x - downX, e.y - downY) > slop) {
                    handler.removeCallbacks(longPress)
                    state = if (scale > 1f) State.PAN else State.SCROLL1
                    lastX = e.x; lastY = e.y
                }

                State.SCROLL1 -> {
                    send(Protocol.input(Protocol.ACTION_SCROLL, nx(e.x), ny(e.y), e.x - lastX, e.y - lastY))
                    lastX = e.x; lastY = e.y
                }

                State.PAN -> {
                    tx += e.x - lastX
                    ty += e.y - lastY
                    lastX = e.x; lastY = e.y
                    applyZoom()
                }

                State.MULTI -> if (e.pointerCount >= 2) onMultiMove(e)

                else -> Unit
            }

            MotionEvent.ACTION_UP -> {
                handler.removeCallbacks(longPress)
                if (state == State.PENDING) {
                    send(Protocol.input(Protocol.ACTION_DOWN, nx(downX), ny(downY)))
                    send(Protocol.input(Protocol.ACTION_UP, nx(downX), ny(downY)))
                }
                state = State.IDLE
            }

            MotionEvent.ACTION_CANCEL -> {
                handler.removeCallbacks(longPress)
                state = State.IDLE
            }
        }
        return true
    }

    private fun onMultiMove(e: MotionEvent) {
        val cx = (e.getX(0) + e.getX(1)) / 2
        val cy = (e.getY(0) + e.getY(1)) / 2
        val span = hypot(e.getX(0) - e.getX(1), e.getY(0) - e.getY(1))
        if (rebase) {
            rebase = false
            lastX = cx; lastY = cy; lastSpan = span
            return
        }

        val dSpan = span - lastSpan
        val dCentroid = hypot(cx - lastX, cy - lastY)
        if (abs(dSpan) > dCentroid && lastSpan > 0f) {
            val newScale = (scale * span / lastSpan).coerceIn(MIN_SCALE, MAX_SCALE)
            // Giữ điểm dưới tâm hai ngón đứng yên khi đổi tỉ lệ.
            val lx = (lastX - tx) / scale
            val ly = (lastY - ty) / scale
            scale = newScale
            tx = cx - lx * scale
            ty = cy - ly * scale
            applyZoom()
        } else {
            send(Protocol.input(Protocol.ACTION_SCROLL, nx(cx), ny(cy), cx - lastX, cy - lastY))
        }
        lastX = cx; lastY = cy; lastSpan = span
    }

    private fun applyZoom() {
        tx = tx.coerceIn(viewW * (1f - scale), 0f)
        ty = ty.coerceIn(viewH * (1f - scale), 0f)
        zoomTarget.scaleX = scale
        zoomTarget.scaleY = scale
        zoomTarget.translationX = tx
        zoomTarget.translationY = ty
    }

    /** Toạ độ chạm (trên root) -> 0..1 theo màn hình Mac, có tính zoom/pan. */
    private fun nx(x: Float) = (((x - tx) / scale) / viewW).coerceIn(0f, 1f)
    private fun ny(y: Float) = (((y - ty) / scale) / viewH).coerceIn(0f, 1f)

    private companion object {
        const val MIN_SCALE = 1f
        const val MAX_SCALE = 4f
    }
}
