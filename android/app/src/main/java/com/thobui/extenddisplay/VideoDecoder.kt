package com.thobui.extenddisplay

import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Build
import android.util.Log
import android.view.Surface
import kotlin.concurrent.thread

/** Giai đoạn 5: giải mã H.264 (Annex B) và render thẳng ra Surface. */
class VideoDecoder(
    private val surface: Surface,
    private val width: Int,
    private val height: Int,
) {
    private var codec: MediaCodec? = null
    private var config: ByteArray? = null
    private var outputThread: Thread? = null
    @Volatile private var running = false

    fun onConfig(data: ByteArray) {
        if (codec != null && config?.contentEquals(data) == true) return
        release()
        config = data

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            if (Build.VERSION.SDK_INT >= 30) setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
            setInteger(MediaFormat.KEY_PRIORITY, 0) // realtime
        }
        val c = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        c.configure(format, surface, null, 0)
        c.start()
        codec = c
        running = true
        queue(data, 0, MediaCodec.BUFFER_FLAG_CODEC_CONFIG)
        outputThread = thread(name = "decoder-output") { drain(c) }
    }

    /** @return false nếu phải bỏ frame (chưa có config hoặc decoder bận) -> nên xin keyframe. */
    fun onFrame(data: ByteArray, ptsUs: Long): Boolean {
        if (codec == null) return false
        return queue(data, ptsUs, 0)
    }

    private fun queue(data: ByteArray, ptsUs: Long, flags: Int): Boolean {
        val c = codec ?: return false
        return try {
            val index = c.dequeueInputBuffer(10_000)
            if (index < 0) return false
            val buf = c.getInputBuffer(index) ?: return false
            if (data.size > buf.capacity()) {
                c.queueInputBuffer(index, 0, 0, ptsUs, 0)
                return false
            }
            buf.clear()
            buf.put(data)
            c.queueInputBuffer(index, 0, data.size, ptsUs, flags)
            true
        } catch (e: IllegalStateException) {
            Log.w(TAG, "queue lỗi", e)
            false
        }
    }

    private fun drain(c: MediaCodec) {
        val info = MediaCodec.BufferInfo()
        while (running) {
            val index = try {
                c.dequeueOutputBuffer(info, 10_000)
            } catch (e: IllegalStateException) {
                break
            }
            // Render ngay, không giữ frame lại.
            if (index >= 0) c.releaseOutputBuffer(index, true)
        }
    }

    fun release() {
        running = false
        outputThread?.join(300)
        outputThread = null
        codec?.let {
            try { it.stop() } catch (_: IllegalStateException) {}
            it.release()
        }
        codec = null
        config = null
    }

    companion object {
        private const val TAG = "VideoDecoder"
    }
}
