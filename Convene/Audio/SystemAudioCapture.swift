import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import AppKit
import CoreMedia
import CoreGraphics

enum SystemAudioPermissionState: String {
    case notDetermined
    case granted
    case requiresSystemSettings
    case requiresRelaunch

    var isGranted: Bool { self == .granted }
}

/// Captures system audio via ScreenCaptureKit (macOS 13+) — the audio coming out of the
/// laptop speakers / headphones, excluding our own process. Converts to 24 kHz PCM mono
/// to match what the OpenAI Realtime API expects.
///
/// This is the "Others" half of the meeting capture: anyone speaking on the remote end
/// of a Zoom/Meet/Teams call gets captured here.
final class SystemAudioCapture: NSObject, ObservableObject, SCStreamOutput, SCStreamDelegate {
    @MainActor @Published private(set) var isStreaming = false
    @MainActor @Published private(set) var permissionState: SystemAudioPermissionState = .notDetermined

    /// Set before `start()`. Called from a non-main background queue per chunk.
    var onPCM16: (@Sendable (Data) -> Void)?
    var onFloat32: (@Sendable (UnsafePointer<Float>, Int) -> Void)?
    var onStoppedWithError: (@Sendable (Error) -> Void)?

    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "co.blode.convene.systemaudio")
    private static let permissionRequestedKey = "systemAudioPermissionRequested"
    private static let permissionRequiresRelaunchKey = "systemAudioPermissionRequiresRelaunch"
    /// Per-stream conversion state, confined to the audio queue.
    private let processorBox = ProcessorBox()

    override init() {
        super.init()
        Task { @MainActor in self.refreshPermissionState() }
    }

    @MainActor
    var hasScreenRecordingPermission: Bool {
        permissionState.isGranted
    }

    /// Non-prompting permission state read.
    @MainActor
    func refreshPermissionState() {
        if CGPreflightScreenCaptureAccess() {
            Self.clearPermissionRequiresRelaunch()
            permissionState = .granted
        } else {
            permissionState = if Self.permissionRequiresRelaunch {
                .requiresRelaunch
            } else if Self.hasRequestedPermission {
                .requiresSystemSettings
            } else {
                .notDetermined
            }
        }
    }

    /// Triggers the macOS Screen Recording TCC prompt if needed. Returns true if access is
    /// available after the call.
    @MainActor
    @discardableResult
    func requestPermission() async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            Self.clearPermissionRequiresRelaunch()
            permissionState = .granted
            return true
        }
        Self.markPermissionRequested()
        let granted = CGRequestScreenCaptureAccess()

        if await Self.canReadShareableContent() {
            Self.clearPermissionRequiresRelaunch()
            permissionState = .granted
            return true
        }

        if granted {
            Self.markPermissionRequiresRelaunch()
            permissionState = .requiresRelaunch
            return false
        }

        permissionState = .requiresSystemSettings
        return false
    }

    @MainActor
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    func start() async throws {
        guard !isStreaming else { return }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            Self.clearPermissionRequiresRelaunch()
            permissionState = .granted
        } catch {
            Self.markPermissionRequested()
            permissionState = Self.permissionRequiresRelaunch ? .requiresRelaunch : .requiresSystemSettings
            throw NSError(
                domain: "co.blode.convene.systemaudio",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Screen recording permission required: \(error.localizedDescription)"]
            )
        }

        guard let display = Self.preferredDisplay(from: content.displays) else {
            throw NSError(domain: "co.blode.convene.systemaudio", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        let ourBundleID = Bundle.main.bundleIdentifier ?? "co.blode.convene"
        let excludedApps = content.applications.filter { $0.bundleIdentifier == ourBundleID }
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        logInfo("SystemAudioCapture: using display \(display.displayID) (\(display.width)x\(display.height)); excluding \(excludedApps.count) app(s)")

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = Int(MicAudioConstants.sampleRate)
        config.channelCount = 1
        // Minimal video config — we don't need video frames, but ScreenCaptureKit requires them.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 5

        // Reset per-session conversion state on the audio queue before adding the output —
        // sync ensures the processor is fully primed before any sample buffers arrive.
        let pcm16 = onPCM16
        let f32 = onFloat32
        audioQueue.sync {
            processorBox.reset(onPCM16: pcm16, onFloat32: f32)
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream.startCapture()

        self.stream = stream
        self.isStreaming = true
        logInfo("SystemAudioCapture: started")
    }

    @MainActor
    func stop() async {
        guard let stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            logError("SystemAudioCapture: stop error: \(error.localizedDescription)")
        }
        self.stream = nil
        self.isStreaming = false
        // Synchronize the reset with the audio queue so any in-flight sample-buffer
        // callbacks finish before we drop the closures (otherwise we'd race a closure
        // load on the audioQueue against a nil-store on MainActor).
        audioQueue.sync {
            processorBox.reset(onPCM16: nil, onFloat32: nil)
        }
        logInfo("SystemAudioCapture: stopped")
    }

    // MARK: - SCStreamOutput (audioQueue)

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, sampleBuffer.dataReadiness == .ready else { return }
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }
        var asbd = asbdPointer.pointee
        guard let inputFormat = AVAudioFormat(streamDescription: &asbd) else { return }

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, bufferListNoCopy: &audioBufferList) else { return }
        inputBuffer.frameLength = frameCount

        // Already on audioQueue per addStreamOutput's sampleHandlerQueue; process synchronously.
        processorBox.process(buffer: inputBuffer, inputFormat: inputFormat)
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        logError("SystemAudioCapture: stream stopped with error: \(error.localizedDescription)")
        audioQueue.async { [processorBox] in
            processorBox.reset(onPCM16: nil, onFloat32: nil)
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stream = nil
            self.isStreaming = false
            self.onStoppedWithError?(error)
        }
    }

    private static var hasRequestedPermission: Bool {
        UserDefaults.standard.bool(forKey: permissionRequestedKey)
    }

    private static var permissionRequiresRelaunch: Bool {
        UserDefaults.standard.bool(forKey: permissionRequiresRelaunchKey)
    }

    private static func markPermissionRequested() {
        UserDefaults.standard.set(true, forKey: permissionRequestedKey)
    }

    private static func markPermissionRequiresRelaunch() {
        UserDefaults.standard.set(true, forKey: permissionRequiresRelaunchKey)
    }

    private static func clearPermissionRequiresRelaunch() {
        UserDefaults.standard.removeObject(forKey: permissionRequiresRelaunchKey)
    }

    private static func canReadShareableContent() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }

    private static func preferredDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        guard !displays.isEmpty else { return nil }
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let mainDisplayID = (NSScreen.main?.deviceDescription[screenNumberKey] as? NSNumber)?.uint32Value
        if let mainDisplayID,
           let display = displays.first(where: { $0.displayID == mainDisplayID }) {
            return display
        }
        return displays.first
    }
}

/// Audio-queue-confined conversion + emission. Holds the Float32 24 kHz target format and an
/// AVAudioConverter that's recreated whenever the input format changes.
private final class ProcessorBox: @unchecked Sendable {
    private let targetFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: MicAudioConstants.sampleRate,
        channels: 1,
        interleaved: false
    )!
    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?
    private var onPCM16: ((Data) -> Void)?
    private var onFloat32: ((UnsafePointer<Float>, Int) -> Void)?
    #if DEBUG
    private var debugChunkCount = 0
    #endif

    func reset(onPCM16: ((Data) -> Void)?, onFloat32: ((UnsafePointer<Float>, Int) -> Void)?) {
        self.converter = nil
        self.converterInputFormat = nil
        self.onPCM16 = onPCM16
        self.onFloat32 = onFloat32
        #if DEBUG
        self.debugChunkCount = 0
        #endif
    }

    func process(buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        if converter == nil || converterInputFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            converterInputFormat = inputFormat
        }
        guard let converter else { return }

        let outFrames = AVAudioFrameCount(ceil(Double(buffer.frameLength) * targetFormat.sampleRate / inputFormat.sampleRate))
        guard outFrames > 0,
              let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames) else { return }

        // Capture buffer in a non-Sendable manner via a wrapper closure.
        var consumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        var error: NSError?
        let status = converter.convert(to: out, error: &error, withInputFrom: inputBlock)
        if status == .error || error != nil {
            logError("SystemAudioCapture: conversion error: \(error?.localizedDescription ?? "unknown")")
            return
        }

        guard let floats = out.floatChannelData else { return }
        let frameCount = Int(out.frameLength)
        guard frameCount > 0 else { return }

        #if DEBUG
        if debugChunkCount < 6 {
            let inputRMS = buffer.floatChannelData.map { rmsLevel($0[0], frameCount: Int(buffer.frameLength)) }
            let outputRMS = rmsLevel(floats[0], frameCount: frameCount)
            logInfo(
                "SystemAudioCapture: chunk \(debugChunkCount + 1) input=\(formatSummary(inputFormat)) frames=\(buffer.frameLength) rms=\(inputRMS.map { "\($0)" } ?? "n/a") outputFrames=\(frameCount) outputRMS=\(outputRMS) status=\(status)"
            )
            debugChunkCount += 1
        }
        #endif

        onFloat32?(floats[0], frameCount)

        var data = Data(count: frameCount * 2)
        data.withUnsafeMutableBytes { raw in
            let int16 = raw.bindMemory(to: Int16.self)
            for i in 0..<frameCount {
                let scaled = Int32(floats[0][i] * 32767.0)
                int16[i] = Int16(max(-32768, min(32767, scaled))).littleEndian
            }
        }
        onPCM16?(data)
    }

    #if DEBUG
    private func rmsLevel(_ samples: UnsafePointer<Float>, frameCount: Int) -> Float {
        guard frameCount > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameCount { sum += samples[i] * samples[i] }
        return (sum / Float(frameCount)).squareRoot()
    }

    private func formatSummary(_ format: AVAudioFormat) -> String {
        "\(Int(format.sampleRate))Hz/\(format.channelCount)ch/\(format.commonFormat)/interleaved=\(format.isInterleaved)"
    }
    #endif
}
