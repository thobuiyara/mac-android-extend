import CoreMedia
import Foundation
import VideoToolbox

enum EncoderError: Error {
    case createFailed(OSStatus)
}

/// Giai đoạn 3: nén H.264 bằng phần cứng, xuất Annex B.
/// Mọi lời gọi encode/requestKeyframe phải trên cùng một queue (pipeline).
final class VideoEncoder {
    private var session: VTCompressionSession?
    private var forceNextKeyframe = true
    private static let startCode: [UInt8] = [0, 0, 0, 1]

    /// SPS + PPS (Annex B), gửi trước mỗi keyframe.
    var onConfig: ((Data) -> Void)?
    /// (dữ liệu Annex B, pts micro giây, là keyframe?)
    var onFrame: ((Data, Int64, Bool) -> Void)?

    init(width: Int, height: Int, fps: Int = 60, bitrate: Int = 20_000_000) throws {
        let spec: [CFString: Any] = [kVTVideoEncoderSpecification_EnableLowLatencyRateControl: true]
        var s: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil, width: Int32(width), height: Int32(height),
            codecType: kCMVideoCodecType_H264, encoderSpecification: spec as CFDictionary,
            imageBufferAttributes: nil, compressedDataAllocator: nil,
            outputCallback: nil, refcon: nil, compressionSessionOut: &s)
        guard status == noErr, let s else { throw EncoderError.createFailed(status) }
        session = s

        set(kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)
        set(kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_ConstrainedHigh_AutoLevel)
        set(kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse) // không B-frame
        set(kVTCompressionPropertyKey_MaxKeyFrameInterval, NSNumber(value: 60))
        set(kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: fps))
        set(kVTCompressionPropertyKey_AverageBitRate, NSNumber(value: bitrate))
        VTCompressionSessionPrepareToEncodeFrames(s)
    }

    deinit { invalidate() }

    func invalidate() {
        if let session { VTCompressionSessionInvalidate(session) }
        session = nil
    }

    func requestKeyframe() {
        forceNextKeyframe = true
    }

    func encode(_ pixelBuffer: CVPixelBuffer) {
        guard let session else { return }
        let pts = CMClockGetTime(CMClockGetHostTimeClock())
        var props: CFDictionary?
        if forceNextKeyframe {
            let p: [CFString: Any] = [kVTEncodeFrameOptionKey_ForceKeyFrame: true]
            props = p as CFDictionary
            forceNextKeyframe = false
        }
        VTCompressionSessionEncodeFrame(
            session, imageBuffer: pixelBuffer, presentationTimeStamp: pts,
            duration: .invalid, frameProperties: props, infoFlagsOut: nil
        ) { [weak self] status, _, sampleBuffer in
            guard status == noErr, let sampleBuffer else { return }
            self?.handle(sampleBuffer)
        }
    }

    private func set(_ key: CFString, _ value: CFTypeRef?) {
        guard let session, let value else { return }
        let st = VTSessionSetProperty(session, key: key, value: value)
        if st != noErr { logInfo("VT property \(key) lỗi \(st)") }
    }

    private func handle(_ sb: CMSampleBuffer) {
        var isKey = true
        if let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[CFString: Any]],
           let notSync = arr.first?[kCMSampleAttachmentKey_NotSync] as? Bool {
            isKey = !notSync
        }

        if isKey, let fmt = CMSampleBufferGetFormatDescription(sb) {
            onConfig?(Self.parameterSets(fmt))
        }

        guard let block = CMSampleBufferGetDataBuffer(sb) else { return }
        let length = CMBlockBufferGetDataLength(block)
        var avcc = Data(count: length)
        let copyStatus = avcc.withUnsafeMutableBytes {
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
        }
        guard copyStatus == noErr else { return }

        // AVCC (4 byte độ dài) -> Annex B (start code 00 00 00 01)
        var annexB = Data(capacity: length + 16)
        var offset = 0
        while offset + 4 <= avcc.count {
            let nalLength = Int(avcc.uint32BE(at: offset))
            offset += 4
            guard nalLength > 0, offset + nalLength <= avcc.count else { break }
            annexB.append(contentsOf: Self.startCode)
            annexB.append(avcc[offset..<(offset + nalLength)])
            offset += nalLength
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sb)
        let ptsUs = Int64(CMTimeGetSeconds(pts) * 1_000_000)
        onFrame?(annexB, ptsUs, isKey)
    }

    private static func parameterSets(_ fmt: CMFormatDescription) -> Data {
        var count = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            fmt, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil,
            parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
        var out = Data()
        for i in 0..<count {
            var ptr: UnsafePointer<UInt8>?
            var size = 0
            let st = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                fmt, parameterSetIndex: i, parameterSetPointerOut: &ptr, parameterSetSizeOut: &size,
                parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
            if st == noErr, let ptr {
                out.append(contentsOf: startCode)
                out.append(ptr, count: size)
            }
        }
        return out
    }
}
