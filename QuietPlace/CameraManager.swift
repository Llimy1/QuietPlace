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
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let outputQueue = DispatchQueue(label: "camera.output", qos: .userInteractive)

    // Capture state (thread-safe, captureLock으로 보호)
    nonisolated(unsafe) private var photoContinuation: CheckedContinuation<UIImage?, Error>?
    nonisolated(unsafe) private let captureLock = NSLock()
    nonisolated(unsafe) private var _isCapturingPhoto = false
    nonisolated(unsafe) private var _isFrameReady = false
    nonisolated(unsafe) private var _isFrontCamera = false

    // 멀티 프레임 수집 (선명도 기반 최적 프레임 선택)
    nonisolated(unsafe) private var frameBuffer: [CIImage] = []
    nonisolated(unsafe) private var framesSkipped: Int = 0

    // ⚡️ 재사용 가능한 CIContext (Display P3 광색역, GPU 렌더링)
    nonisolated(unsafe) private let ciContext: CIContext = {
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
                        
                        self.videoOutput.alwaysDiscardsLateVideoFrames = false
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
        debugPrint("🔥 Starting CIContext warmup...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 작은 더미 이미지로 GPU 파이프라인 워밍업 (더 현실적인 크기)
        let dummyImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
        _ = ciContext.createCGImage(dummyImage, from: dummyImage.extent)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        debugPrint("✅ CIContext warmed up in \(String(format: "%.3f", elapsed))s")
    }
    
    // MARK: - Camera Switch
    
    func switchCamera() {
        // MainActor에서 즉시 오버레이 활성화 (sessionQueue 디스패치 전에 UI 업데이트)
        isSwitchingCamera = true

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

                self._isFrontCamera = (newPosition == .front)
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

    private func clampedZoomFactor(_ zoomFactor: CGFloat, for device: AVCaptureDevice) -> CGFloat {
        let minimumZoomFactor = max(
            device.minAvailableVideoZoomFactor,
            AppConstants.Camera.minimumZoomFactor
        )
        let maximumZoomFactor = min(
            device.maxAvailableVideoZoomFactor,
            AppConstants.Camera.maximumZoomFactor
        )

        return min(max(zoomFactor, minimumZoomFactor), max(maximumZoomFactor, minimumZoomFactor))
    }

    private func applyZoomFactor(_ zoomFactor: CGFloat, to device: AVCaptureDevice) -> CGFloat {
        let clampedZoomFactor = clampedZoomFactor(zoomFactor, for: device)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedZoomFactor
            device.unlockForConfiguration()
            return clampedZoomFactor
        } catch {
            debugPrint("❌ Zoom update failed: \(error)")
            return device.videoZoomFactor
        }
    }

    private func configureVideoStabilization(for device: AVCaptureDevice, enabled: Bool) {
        guard let connection = videoOutput.connection(with: .video) else { return }

        guard connection.isVideoStabilizationSupported else {
            debugPrint("⚠️ Video stabilization not supported on this connection")
            return
        }

        let mode = enabled ? preferredStabilizationMode(for: device) : .off
        connection.preferredVideoStabilizationMode = mode

        debugPrint("✅ Video stabilization requested: \(stabilizationModeDescription(mode))")
    }

    private func preferredStabilizationMode(for device: AVCaptureDevice) -> AVCaptureVideoStabilizationMode {
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

    private func stabilizationModeDescription(_ mode: AVCaptureVideoStabilizationMode) -> String {
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
            for _ in 0..<20 {
                if isFrameReady { break }
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05초씩
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
        
        let result = try await withCheckedThrowingContinuation { continuation in
            // ⚡️ continuation을 nonisolated(unsafe) 변수에 직접 할당 (MainActor 오버헤드 제거)
            captureLock.lock()
            self.photoContinuation = continuation
            captureLock.unlock()
            
            // 타임아웃: skip(3) + collect(7) @ 30fps = ~330ms, 여유 있게 2초
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                captureLock.lock()
                if self.photoContinuation != nil {
                    debugPrint("⚠️ Photo capture timeout")
                    self.photoContinuation?.resume(returning: nil)
                    self.photoContinuation = nil
                    self.frameBuffer = []
                    self.framesSkipped = 0
                }
                captureLock.unlock()
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
            debugPrint("✅ First frame ready!")
        }

        guard isCapturingPhoto else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        captureLock.lock()

        // 스태빌라이제이션 버퍼가 안정화될 때까지 초기 프레임 스킵
        if framesSkipped < AppConstants.Camera.captureSkipFrames {
            framesSkipped += 1
            captureLock.unlock()
            return
        }

        // 프레임 수집
        frameBuffer.append(ciImage)

        guard frameBuffer.count >= AppConstants.Camera.captureFrameCount else {
            captureLock.unlock()
            return
        }

        // 수집 완료 - 최적 프레임 선택 준비
        let frames = frameBuffer
        let continuation = photoContinuation
        photoContinuation = nil
        frameBuffer = []
        framesSkipped = 0

        captureLock.unlock()

        guard let continuation = continuation else { return }

        let startTime = CFAbsoluteTimeGetCurrent()

        // 가장 선명한 프레임 선택
        let bestCIImage = selectSharpestFrame(from: frames)

        // 노이즈 리덕션 + 샤프닝 후처리
        let processedCIImage = applyPostProcessing(to: bestCIImage)

        // Display P3 색공간으로 렌더링
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = ciContext.createCGImage(
            processedCIImage,
            from: processedCIImage.extent,
            format: .RGBA8,
            colorSpace: p3ColorSpace
        ) else {
            continuation.resume(returning: nil)
            return
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        debugPrint("✅ Best frame selected & processed in \(String(format: "%.3f", elapsed))s")

        let orientation: UIImage.Orientation = _isFrontCamera ? .leftMirrored : .right
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        continuation.resume(returning: image)
    }

    // MARK: - 선명도 기반 최적 프레임 선택

    private nonisolated func selectSharpestFrame(from frames: [CIImage]) -> CIImage {
        var bestFrame = frames[0]
        var bestScore: Float = -1

        for (index, frame) in frames.enumerated() {
            let score = calculateSharpness(of: frame)
            debugPrint("🔍 Frame \(index) sharpness: \(String(format: "%.4f", score))")
            if score > bestScore {
                bestScore = score
                bestFrame = frame
            }
        }

        debugPrint("🎯 Best sharpness score: \(String(format: "%.4f", bestScore))")
        return bestFrame
    }

    /// Laplacian 엣지 기반 선명도 점수 (높을수록 선명)
    private nonisolated func calculateSharpness(of image: CIImage) -> Float {
        // 연산 속도를 위해 25% 크기로 다운샘플
        let scaled = image.transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))

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

    // MARK: - 후처리 (노이즈 리덕션 + 샤프닝)

    private nonisolated func applyPostProcessing(to image: CIImage) -> CIImage {
        var result = image

        // 노이즈 리덕션 (미세하게 - 과도한 스무딩 방지)
        if let noiseFilter = CIFilter(name: "CINoiseReduction") {
            noiseFilter.setValue(result, forKey: kCIInputImageKey)
            noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
            noiseFilter.setValue(0.4, forKey: "inputSharpness")
            result = noiseFilter.outputImage ?? result
        }

        // 루미넌스 샤프닝 (색상 변화 없이 디테일만 강화)
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(result, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)
            result = sharpenFilter.outputImage ?? result
        }

        return result
    }
}
