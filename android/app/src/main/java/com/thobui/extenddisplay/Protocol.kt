package com.thobui.extenddisplay

import java.nio.ByteBuffer

/** Gói tin: [type 1B][length 4B BE][pts 8B BE][payload] — khớp với Protocol.swift */
object Protocol {
    const val PORT = 27183 // 7000 bị AirPlay Receiver của macOS chiếm
    const val HEADER_SIZE = 13

    const val HELLO: Byte = 1
    const val CONFIG: Byte = 2
    const val FRAME: Byte = 3
    const val INPUT: Byte = 4
    const val KEYFRAME_REQ: Byte = 5

    const val ACTION_DOWN: Byte = 0
    const val ACTION_MOVE: Byte = 1
    const val ACTION_UP: Byte = 2
    const val ACTION_SCROLL: Byte = 3
    const val ACTION_RIGHT_CLICK: Byte = 4

    fun packet(type: Byte, pts: Long, payload: ByteArray): ByteArray =
        ByteBuffer.allocate(HEADER_SIZE + payload.size)
            .put(type).putInt(payload.size).putLong(pts).put(payload)
            .array()

    fun hello(width: Int, height: Int, dpi: Int): ByteArray =
        packet(HELLO, 0, ByteBuffer.allocate(12).putInt(width).putInt(height).putInt(dpi).array())

    /** x, y chuẩn hoá 0..1; dx, dy là pixel (dùng cho cuộn). */
    fun input(action: Byte, x: Float, y: Float, dx: Float = 0f, dy: Float = 0f): ByteArray =
        packet(
            INPUT, 0,
            ByteBuffer.allocate(17).put(action).putFloat(x).putFloat(y).putFloat(dx).putFloat(dy).array()
        )

    fun keyframeRequest(): ByteArray = packet(KEYFRAME_REQ, 0, ByteArray(0))
}
