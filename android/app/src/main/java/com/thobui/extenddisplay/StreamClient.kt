package com.thobui.extenddisplay

import android.os.SystemClock
import android.view.Surface
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.IOException
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import kotlin.concurrent.thread

/**
 * Giai đoạn 4–5: kết nối tới Mac qua localhost:7000 (adb reverse chuyển qua cáp USB),
 * gửi HELLO, nhận CONFIG/FRAME và đưa vào decoder. Tự kết nối lại khi rớt.
 */
class StreamClient(
    private val surface: Surface,
    val width: Int,
    val height: Int,
    private val dpi: Int,
    private val onStatus: (String) -> Unit,
) {
    @Volatile private var running = false
    @Volatile private var socket: Socket? = null
    @Volatile private var output: OutputStream? = null
    private var readThread: Thread? = null
    private val writer = Executors.newSingleThreadExecutor()
    private var lastKeyframeRequest = 0L

    fun start() {
        running = true
        readThread = thread(name = "stream-client") { loop() }
    }

    fun stop() {
        running = false
        try { socket?.close() } catch (_: IOException) {}
        readThread?.join(500)
        writer.shutdownNow()
    }

    fun send(bytes: ByteArray) {
        try {
            writer.execute {
                try {
                    output?.apply { write(bytes); flush() }
                } catch (_: IOException) {
                }
            }
        } catch (_: RejectedExecutionException) {
        }
    }

    private fun loop() {
        while (running) {
            val decoder = VideoDecoder(surface, width, height)
            try {
                onStatus("Đang kết nối tới Mac (localhost:${Protocol.PORT})…")
                Socket().use { s ->
                    socket = s
                    s.tcpNoDelay = true
                    s.connect(InetSocketAddress("127.0.0.1", Protocol.PORT), 2000)
                    val input = DataInputStream(BufferedInputStream(s.getInputStream(), 1 shl 16))
                    output = BufferedOutputStream(s.getOutputStream())
                    send(Protocol.hello(width, height, dpi))
                    onStatus("Đã kết nối – đang chờ hình…")

                    var gotFrame = false
                    val header = ByteArray(Protocol.HEADER_SIZE)
                    while (running) {
                        input.readFully(header)
                        val bb = ByteBuffer.wrap(header)
                        val type = bb.get()
                        val length = bb.int
                        val pts = bb.long
                        val payload = ByteArray(length)
                        input.readFully(payload)

                        when (type) {
                            Protocol.CONFIG -> decoder.onConfig(payload)
                            Protocol.FRAME -> {
                                if (!decoder.onFrame(payload, pts)) {
                                    requestKeyframe()
                                } else if (!gotFrame) {
                                    gotFrame = true
                                    onStatus("")
                                }
                            }
                        }
                    }
                }
            } catch (e: IOException) {
                if (running) onStatus("Chưa kết nối được (${e.message}). Thử lại…")
            } finally {
                output = null
                socket = null
                decoder.release()
            }
            if (running) SystemClock.sleep(1000)
        }
    }

    private fun requestKeyframe() {
        val now = SystemClock.uptimeMillis()
        if (now - lastKeyframeRequest < 500) return
        lastKeyframeRequest = now
        send(Protocol.keyframeRequest())
    }
}
