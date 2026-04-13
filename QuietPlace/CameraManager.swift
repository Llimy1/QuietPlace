//
//  CameraManager.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import AVFoundation
import SwiftUI
import UIKit
import Combine

@MainActor
class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    // Published properties
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isUsingFrontCamera = false
    @Published var currentResolutionLabel = "-"
    @Published var currentZoomFactor: CGFloat = AppConstants.Camera.minimumZoomFactor
    @Published var isSwitchingCamera = false

    // Camera session
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let outputQueue = DispatchQueue(label: "camera.output", qos: .userInteractive)

    // Capture state (thread-safe, captureLock으로 보호)
    private let captureLock = NSLock()
    nonisolated(unsafe) private var _isCapturingPhoto = false
    nonisolated(unsafe) private var _isFrameReady = false
    nonisolated(unsafe) private var _isFrontCamera = false

    // 최근 프레임 버퍼 (셔터 직전 프레임들에서 즉시 선택)
    nonisolated(unsafe) private var recentFrameBuffer: [CVPixelBuffer] = []

    // ⚡️ 재사용 가능한 CIContext (Display P3 광색역, GPU 렌더링)
    private let ciContext: CIContext = {
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false,
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace
        ]
        return CIContext(options: options)
    }()
    
    // ⚡️ 프레임 준비 상태 (lock으로 보호)
    private nonisolated var isFrameReady: Bool {
        get {
            captureLock.lock()
            defer { captureLock.unlock() }
            return _isFrameReady
        }
        set {
            captureLock.lock()
            _isFrameReady = newValue
            captureLock.unlock()
        }
    }
    
    private nonisolated var isCapturingPhoto: Bool {
        get {
            captureLock.lock()
            defer { captureLock.unlock() }
            return _isCapturingPhoto
        }
        set {
            captureLock.lock()
            _isCapturingPhoto = newValue
            captureLock.unlock()
        }
    }

    private nonisolated var isFrontCamera: Bool {
        get {
            captureLock.lock()
            defer { captureLock.unlock() }
            return _isFrontCamera
        }
        set {
            captureLock.lock()
            _isFrontCamera = newValue
            captureLock.unlock()
        }
    }

    private override init() {
        super.init()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }
    
    // MARK: - Setup
    
    func setupCamera() async {
        let stabilizationEnabled = SettingsManager.shared.isStabilizationEnabled

        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // 이미 설정되어 있으면 스킵
                if !self.session.inputs.isEmpty {
                    continuation.resume()
                    return
                }
                
                self.session.beginConfiguration()
                
                // 최고 해상도 설정 (4K 우선, 폴백: 1080p → photo)
                let resolutionLabel: String
                if self.session.canSetSessionPreset(.hd4K3840x2160) {
                    self.session.sessionPreset = .hd4K3840x2160
                    resolutionLabel = "4K (3840×2160)"
                    debugPrint("📸 Using 4K resolution (3840x2160)")
                } else if self.session.canSetSessionPreset(.hd1920x1080) {
                    self.session.sessionPreset = .hd1920x1080
                    resolutionLabel = "Full HD (1920×1080)"
                    debugPrint("📸 Using Full HD resolution (1920x1080)")
                } else {
                    self.session.sessionPreset = .photo
                    resolutionLabel = "표준 (Photo)"
                    debugPrint("📸 Using photo preset")
                }
                Task { @MainActor in
                    self.currentResolutionLabel = resolutionLabel
                }
                
                do {
                    // 후면 카메라
                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw NSError(domain: "CameraManager", code: -1)
                    }
                    
                    // 입력 추가
                    let input = try AVCaptureDeviceInput(device: camera)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.videoDeviceInput = input
                    }
                    
                    // 비디오 출력 추가 (무음 촬영용)
                    if self.session.canAddOutput(self.videoOutput) {
                        self.session.addOutput(self.videoOutput)
                        
                        // YpCbCr: 4K에서 BGRA 대비 메모리 60% 절약, CIImage 네이티브 포맷
                        self.videoOutput.videoSettings = [
                            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                        ]
                        
                        // 최근 프레임 버퍼 캡처에서는 오래된 프레임을 버리고 최신 프레임 유지가 유리함
                        self.videoOutput.alwaysDiscardsLateVideoFrames = true
                        self.videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)
                        
                        self.configureVideoStabilization(
                            for: camera,
                            enabled: stabilizationEnabled
                        )
                    }
                    
                    // 자동 초점/노출 설정
                    try camera.lockForConfiguration()
                    
                    if camera.isFocusModeSupported(.continuousAutoFocus) {
                        camera.focusMode = .continuousAutoFocus
                    }
                    
                    if camera.isExposureModeSupported(.continuousAutoExposure) {
                        camera.exposureMode = .continuousAutoExposure
                    }
                    
                    if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        camera.whiteBalanceMode = .continuousAutoWhiteBalance
                    }

                    let appliedZoomFactor = self.clampedZoomFactor(
                        AppConstants.Camera.minimumZoomFactor,
                        for: camera
                    )
                    camera.videoZoomFactor = appliedZoomFactor
                    
                    camera.unlockForConfiguration()

                    Task { @MainActor in
                        self.currentZoomFactor = appliedZoomFactor
                    }
                    
                } catch {
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
                
                self.session.commitConfiguration()
                
                // ⚡️ CIContext 워밍업 (첫 촬영 렉 제거)
                self.warmupCIContext()
                
                continuation.resume()
            }
        }
    }
    
    // ⚡️ CIContext 워밍업 - GPU 파이프라인 미리 초기화
    private nonisolated func warmupCIContext() {
        print("🔥 Starting CIContext warmup...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 작은 더미 이미지로 GPU 파이프라인 워밍업 (더 현실적인 크기)
        let dummyImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
        _ = ciContext.createCGImage(dummyImage, from: dummyImage.extent)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ CIContext warmed up in \(String(format: "%.3f", elapsed))s")
    }
    
    // MARK: - Camera Switch
    
    func switchCamera() {
        // MainActor에서 즉시 오버레이 활성화 (sessionQueue 디스패치 전에 UI 업데이트)
        isSwitchingCamera = true
        resetRecentFrameBuffer()

        let currentZoomFactor = self.currentZoomFactor
        let stabilizationEnabled = SettingsManager.shared.isStabilizationEnabled

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let currentPosition = self.videoDeviceInput?.device.position ?? .back
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                Task { @MainActor in self.isSwitchingCamera = false }
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                let currentInput = self.videoDeviceInput

                self.session.beginConfiguration()

                if let currentInput {
                    self.session.removeInput(currentInput)
                }

                guard self.session.canAddInput(newInput) else {
                    if let currentInput, self.session.canAddInput(currentInput) {
                        self.session.addInput(currentInput)
                    }
                    self.session.commitConfiguration()
                    Task { @MainActor in self.isSwitchingCamera = false }
                    return
                }

                self.session.addInput(newInput)
                self.videoDeviceInput = newInput

                self.session.commitConfiguration()
                self.configureVideoStabilization(
                    for: newDevice,
                    enabled: stabilizationEnabled
                )
                let appliedZoomFactor = self.applyZoomFactor(currentZoomFactor, to: newDevice)

                self.isFrontCamera = (newPosition == .front)
                Task { @MainActor in
                    self.isUsingFrontCamera = (newPosition == .front)
                    self.currentZoomFactor = appliedZoomFactor
                }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(
                        nanoseconds: UInt64(
                            AppConstants.Camera.cameraSwitchOverlayHoldDuration * 1_000_000_000
                        )
                    )
                    guard let self else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        self.isSwitchingCamera = false
                    }
                }
            } catch {
                debugPrint("❌ Camera switch failed: \(error)")
                Task { @MainActor in self.isSwitchingCamera = false }
            }
        }
    }
    
    // MARK: - Session Control
    
    func startSession() {
        let stabilizationEnabled = SettingsManager.shared.isStabilizationEnabled

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.session.isRunning else {
                Task { @MainActor in
                    self.isSessionRunning = true
                }
                return
            }

            self.resetRecentFrameBuffer()
            self.session.startRunning()
            
            if let device = self.videoDeviceInput?.device {
                self.configureVideoStabilization(
                    for: device,
                    enabled: stabilizationEnabled
                )
            }
            
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
                self.resetRecentFrameBuffer()
                
                Task { @MainActor in
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Stabilization Control
    
    func updateStabilization(enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.videoDeviceInput?.device else { return }

            self.configureVideoStabilization(for: device, enabled: enabled)
        }
    }

    // MARK: - Zoom Control

    func setZoomFactor(_ zoomFactor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.videoDeviceInput?.device else { return }

            let appliedZoomFactor = self.applyZoomFactor(zoomFactor, to: device)

            Task { @MainActor in
                self.currentZoomFactor = appliedZoomFactor
            }
        }
    }

    private nonisolated func clampedZoomFactor(_ zoomFactor: CGFloat, for device: AVCaptureDevice) -> CGFloat {
        let minimumZoomFactor = max(
            device.minAvailableVideoZoomFactor,
            1.0
        )
        let maximumZoomFactor = min(
            device.maxAvailableVideoZoomFactor,
            5.0
        )

        return min(max(zoomFactor, minimumZoomFactor), max(maximumZoomFactor, minimumZoomFactor))
    }

    private nonisolated func applyZoomFactor(_ zoomFactor: CGFloat, to device: AVCaptureDevice) -> CGFloat {
        let clampedZoomFactor = clampedZoomFactor(zoomFactor, for: device)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedZoomFactor
            device.unlockForConfiguration()
            return clampedZoomFactor
        } catch {
            print("❌ Zoom update failed: \(error)")
            return device.videoZoomFactor
        }
    }

    private nonisolated func configureVideoStabilization(for device: AVCaptureDevice, enabled: Bool) {
        guard let connection = videoOutput.connection(with: .video) else { return }

        guard connection.isVideoStabilizationSupported else {
            print("⚠️ Video stabilization not supported on this connection")
            return
        }

        let mode = enabled ? preferredStabilizationMode(for: device) : .off
        connection.preferredVideoStabilizationMode = mode

        print("✅ Video stabilization requested: \(stabilizationModeDescription(mode))")
    }

    private nonisolated func preferredStabilizationMode(for device: AVCaptureDevice) -> AVCaptureVideoStabilizationMode {
        let format = device.activeFormat

        if #available(iOS 18.0, *),
           format.isVideoStabilizationModeSupported(.cinematicExtendedEnhanced) {
            return .cinematicExtendedEnhanced
        }

        if #available(iOS 13.0, *),
           format.isVideoStabilizationModeSupported(.cinematicExtended) {
            return .cinematicExtended
        }

        if format.isVideoStabilizationModeSupported(.cinematic) {
            return .cinematic
        }

        if format.isVideoStabilizationModeSupported(.standard) {
            return .standard
        }

        return .auto
    }

    private nonisolated func stabilizationModeDescription(_ mode: AVCaptureVideoStabilizationMode) -> String {
        switch mode {
        case .off:
            return "off"
        case .standard:
            return "standard"
        case .cinematic:
            return "cinematic"
        case .cinematicExtended:
            return "cinematicExtended"
        case .previewOptimized:
            return "previewOptimized"
        case .cinematicExtendedEnhanced:
            return "cinematicExtendedEnhanced"
        case .auto:
            return "auto"
        default:
            if #available(iOS 26.0, *), mode == .lowLatency {
                return "lowLatency"
            }

            return "unknown"
        }
    }
    
    // MARK: - Focus Control
    
    /// 특정 지점에 초점 맞추기 (탭 포커스)
    func focusAt(point: CGPoint, viewSize: CGSize) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.videoDeviceInput?.device else { return }
            
            // 화면 좌표 → 카메라 좌표 변환 (0.0 ~ 1.0)
            let focusPoint = CGPoint(
                x: point.y / viewSize.height,
                y: 1.0 - point.x / viewSize.width
            )
            
            do {
                try device.lockForConfiguration()
                
                // 탭한 지점에 초점
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }
                
                // 탭한 지점에 노출
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                }
                
                device.unlockForConfiguration()
                
                // 초점 고정 후 연속 자동 초점으로 복귀 (3초 후)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.sessionQueue.async {
                        guard let device = self.videoDeviceInput?.device else { return }
                        do {
                            try device.lockForConfiguration()
                            if device.isFocusModeSupported(.continuousAutoFocus) {
                                device.focusMode = .continuousAutoFocus
                            }
                            if device.isExposureModeSupported(.continuousAutoExposure) {
                                device.exposureMode = .continuousAutoExposure
                            }
                            device.unlockForConfiguration()
                        } catch {
                            debugPrint("❌ Focus restore failed: \(error)")
                        }
                    }
                }
            } catch {
                debugPrint("❌ Focus failed: \(error)")
            }
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() async throws -> UIImage? {
        let captureStartTime = CFAbsoluteTimeGetCurrent()
        debugPrint("📸 Starting photo capture...")
        
        // 세션이 실행 중인지 확인
        guard isSessionRunning else {
            debugPrint("⚠️ Camera session not running")
            return nil
        }
        
        // 중복 촬영 방지
        guard !isCapturingPhoto else {
            debugPrint("⚠️ Already capturing photo")
            return nil
        }
        
        // ⚡️ 첫 프레임이 준비될 때까지 대기 (최대 1초, 하지만 더 효율적으로)
        if !isFrameReady {
            let waitStartTime = CFAbsoluteTimeGetCurrent()
            debugPrint("⚡️ Waiting for first frame...")
            for _ in 0..<AppConstants.Camera.maxFrameWaitAttempts {
                if isFrameReady { break }
                try? await Task.sleep(
                    nanoseconds: UInt64(AppConstants.Camera.frameWaitInterval * 1_000_000_000)
                )
            }
            
            // 여전히 프레임이 안 오면 에러
            guard isFrameReady else {
                debugPrint("❌ Frame not ready after 1 second")
                return nil
            }
            
            let waitElapsed = CFAbsoluteTimeGetCurrent() - waitStartTime
            debugPrint("⚡️ Frame ready after \(String(format: "%.3f", waitElapsed))s")
        }
        
        isCapturingPhoto = true
        defer { isCapturingPhoto = false }

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage?, Error>) in
            self.outputQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let bufferedFrames = self.frameSnapshot()
                guard !bufferedFrames.isEmpty else {
                    debugPrint("⚠️ No buffered frames available for capture")
                    continuation.resume(returning: nil)
                    return
                }

                guard let selectedFrame = self.selectSharpestFrame(from: bufferedFrames) else {
                    continuation.resume(returning: nil)
                    return
                }

                let startTime = CFAbsoluteTimeGetCurrent()
                let processedCIImage = self.applyPostProcessing(to: selectedFrame)
                let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

                guard let cgImage = self.ciContext.createCGImage(
                    processedCIImage,
                    from: processedCIImage.extent,
                    format: .RGBA8,
                    colorSpace: p3ColorSpace
                ) else {
                    continuation.resume(returning: nil)
                    return
                }

                debugPrint("✅ Buffered capture processed in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime))s")

                let orientation: UIImage.Orientation = self.isFrontCamera ? .leftMirrored : .right
                let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                continuation.resume(returning: image)
            }
        }
        
        let captureElapsed = CFAbsoluteTimeGetCurrent() - captureStartTime
        debugPrint("✅ Photo captured in \(String(format: "%.3f", captureElapsed))s")
        
        return result
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // 첫 프레임 도착 표시
        if !isFrameReady {
            isFrameReady = true
            print("✅ First frame ready!")
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        appendRecentFrame(imageBuffer)
    }

    private nonisolated func appendRecentFrame(_ imageBuffer: CVPixelBuffer) {
        captureLock.lock()
        recentFrameBuffer.append(imageBuffer)
        let overflowCount = recentFrameBuffer.count - 5
        if overflowCount > 0 {
            recentFrameBuffer.removeFirst(overflowCount)
        }
        captureLock.unlock()
    }

    private nonisolated func resetRecentFrameBuffer() {
        captureLock.lock()
        recentFrameBuffer.removeAll(keepingCapacity: true)
        _isFrameReady = false
        captureLock.unlock()
    }

    private nonisolated func frameSnapshot() -> [CVPixelBuffer] {
        captureLock.lock()
        let snapshot = recentFrameBuffer
        captureLock.unlock()
        return snapshot
    }

    private nonisolated func selectSharpestFrame(from buffers: [CVPixelBuffer]) -> CIImage? {
        guard !buffers.isEmpty else { return nil }
        let sampleCount = sharpnessSampleCount(for: buffers.count)
        let candidateBuffers = Array(buffers.suffix(sampleCount))

        var bestFrame: CIImage?
        var bestScore: Float = -1

        for buffer in candidateBuffers {
            let image = CIImage(cvPixelBuffer: buffer)
            let score = calculateSharpness(of: image, downsampleScale: sharpnessDownsampleScale())
            if score > bestScore {
                bestScore = score
                bestFrame = image
            }
        }

        return bestFrame
    }

    /// Laplacian 엣지 기반 선명도 점수 (높을수록 선명)
    private nonisolated func calculateSharpness(of image: CIImage, downsampleScale: CGFloat) -> Float {
        let clampedScale = min(max(downsampleScale, 0.1), 1.0)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: clampedScale, y: clampedScale))

        // 그레이스케일 변환
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return 0 }
        grayscaleFilter.setValue(scaled, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let gray = grayscaleFilter.outputImage else { return 0 }

        // 엣지 검출 (Laplacian 근사)
        guard let edgeFilter = CIFilter(name: "CIEdges") else { return 0 }
        edgeFilter.setValue(gray, forKey: kCIInputImageKey)
        edgeFilter.setValue(5.0, forKey: kCIInputIntensityKey)
        guard let edgeImage = edgeFilter.outputImage else { return 0 }

        // 엣지 이미지 평균값 = 선명도 점수
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return 0 }
        avgFilter.setValue(edgeImage, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: edgeImage.extent), forKey: kCIInputExtentKey)
        guard let avgOutput = avgFilter.outputImage else { return 0 }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            avgOutput,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return Float(pixel[0]) / 255.0
    }

    private nonisolated func sharpnessSampleCount(for availableCount: Int) -> Int {
        let defaultSampleCount = 5
        let lowPowerSampleCount = 3
        let preferredCount = ProcessInfo.processInfo.isLowPowerModeEnabled
            ? lowPowerSampleCount
            : defaultSampleCount
        return min(max(preferredCount, 1), availableCount)
    }

    private nonisolated func sharpnessDownsampleScale() -> CGFloat {
        let defaultScale: CGFloat = 0.25
        let lowPowerScale: CGFloat = 0.18
        return ProcessInfo.processInfo.isLowPowerModeEnabled
            ? lowPowerScale
            : defaultScale
    }

    // MARK: - 후처리 (샤프닝)

    private nonisolated func applyPostProcessing(to image: CIImage) -> CIImage {
        // 루미넌스 샤프닝 (색상 변화 없이 디테일만 강화)
        // CINoiseReduction 제거: 선명도 기반 최적 프레임 선택으로 이미 대체됨 (~50ms 절약)
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        sharpenFilter.setValue(image, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)
        return sharpenFilter.outputImage ?? image
    }
}
