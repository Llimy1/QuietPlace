//
//  CameraManager.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import AVFoundation
import CoreMotion
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
    @Published var currentZoomFactor: CGFloat = AppConstants.Camera.defaultZoomFactor
    @Published var minimumZoomFactor: CGFloat = AppConstants.Camera.defaultZoomFactor
    @Published var isSwitchingCamera = false

    // Camera session
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let outputQueue = DispatchQueue(label: "camera.output", qos: .userInteractive)
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInitiated)
    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "camera.motion"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // Capture state (thread-safe, captureLock으로 보호)
    private let captureLock = NSLock()
    nonisolated(unsafe) private var _isCapturingPhoto = false
    nonisolated(unsafe) private var _isFrameReady = false
    nonisolated(unsafe) private var _isFrontCamera = false
    nonisolated(unsafe) private var _hasCapturedSinceReset = false
    nonisolated(unsafe) private var _latestMotionScore: Double?
    nonisolated(unsafe) private var _latestFrameSequence: UInt64 = 0

    // 표시 줌 1x에 해당하는 실제 videoZoomFactor (가상 듀얼 와이드 카메라는 2.0 부근, sessionQueue에서만 접근)
    nonisolated(unsafe) private var zoomDisplayScale: CGFloat = 1.0

    // 최근 프레임 버퍼 (셔터 직전 프레임들에서 즉시 선택)
    nonisolated(unsafe) private var recentFrameBuffer: [BufferedVideoFrame] = []

    private struct BufferedVideoFrame {
        nonisolated(unsafe) let pixelBuffer: CVPixelBuffer
        let sequence: UInt64
        let receivedAt: CFTimeInterval
        let motionScore: Double?
        let readiness: CameraReadinessState
    }

    private struct FrameSelection {
        let image: CIImage
        let score: Float
        let motionScore: Double?
    }

    private struct CameraReadinessState: Sendable {
        let isAdjustingFocus: Bool
        let isAdjustingExposure: Bool
        let isAdjustingWhiteBalance: Bool

        nonisolated var isReady: Bool {
            !isAdjustingFocus && !isAdjustingExposure && !isAdjustingWhiteBalance
        }
    }

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

    private nonisolated var hasCapturedSinceReset: Bool {
        get {
            captureLock.lock()
            defer { captureLock.unlock() }
            return _hasCapturedSinceReset
        }
        set {
            captureLock.lock()
            _hasCapturedSinceReset = newValue
            captureLock.unlock()
        }
    }

    private nonisolated var latestMotionScore: Double? {
        get {
            captureLock.lock()
            defer { captureLock.unlock() }
            return _latestMotionScore
        }
        set {
            captureLock.lock()
            _latestMotionScore = newValue
            captureLock.unlock()
        }
    }

    private override init() {
        super.init()
    }

    private func startMotionMonitoring() {
        guard !motionManager.isDeviceMotionActive else { return }

        guard motionManager.isDeviceMotionAvailable else {
            debugPrint("⚠️ Device motion is not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            if let error {
                debugPrint("⚠️ Motion update failed: \(error.localizedDescription)")
                return
            }

            guard let motion else { return }
            self?.updateMotionSample(motion)
        }
    }

    private func stopMotionMonitoring() {
        guard motionManager.isDeviceMotionActive else { return }
        motionManager.stopDeviceMotionUpdates()
        latestMotionScore = nil
    }

    private nonisolated func updateMotionSample(_ motion: CMDeviceMotion) {
        let rotation = motion.rotationRate
        let acceleration = motion.userAcceleration
        let rotationMagnitude = sqrt(
            (rotation.x * rotation.x) +
            (rotation.y * rotation.y) +
            (rotation.z * rotation.z)
        )
        let accelerationMagnitude = sqrt(
            (acceleration.x * acceleration.x) +
            (acceleration.y * acceleration.y) +
            (acceleration.z * acceleration.z)
        )

        // Rotation is measured in rad/s and acceleration in g. Acceleration is weighted
        // because quick lift/stop gestures often show up there before autofocus settles.
        latestMotionScore = rotationMagnitude + (accelerationMagnitude * 4.0)
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
        let aspectRatio = SettingsManager.shared.photoAspectRatio

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

                // 화면비 설정에 따른 세션 프리셋 (4:3 = 기본 카메라와 동일 화각)
                let resolutionLabel = self.applySessionPreset(for: aspectRatio)
                Task { @MainActor in
                    self.currentResolutionLabel = resolutionLabel
                }
                
                do {
                    // 후면 카메라 (울트라와이드 포함 듀얼 와이드 우선, 0.5x 줌아웃 지원)
                    guard let camera = self.bestCaptureDevice(for: .back) else {
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

                    let zoomScale = self.displayZoomScale(for: camera)
                    self.zoomDisplayScale = zoomScale

                    let appliedZoomFactor = self.clampedZoomFactor(
                        AppConstants.Camera.defaultZoomFactor * zoomScale,
                        for: camera,
                        displayScale: zoomScale
                    )
                    camera.videoZoomFactor = appliedZoomFactor

                    camera.unlockForConfiguration()

                    let minimumDisplayZoom = camera.minAvailableVideoZoomFactor / zoomScale
                    Task { @MainActor in
                        self.currentZoomFactor = appliedZoomFactor / zoomScale
                        self.minimumZoomFactor = minimumDisplayZoom
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

            guard let newDevice = self.bestCaptureDevice(for: newPosition) else {
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
                let newZoomScale = self.displayZoomScale(for: newDevice)
                self.zoomDisplayScale = newZoomScale
                let appliedZoomFactor = self.applyZoomFactor(
                    currentZoomFactor * newZoomScale,
                    to: newDevice,
                    displayScale: newZoomScale
                )
                let minimumDisplayZoom = newDevice.minAvailableVideoZoomFactor / newZoomScale

                self.isFrontCamera = (newPosition == .front)
                Task { @MainActor in
                    self.isUsingFrontCamera = (newPosition == .front)
                    self.currentZoomFactor = appliedZoomFactor / newZoomScale
                    self.minimumZoomFactor = minimumDisplayZoom
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
        startMotionMonitoring()

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
        stopMotionMonitoring()

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
    
    // MARK: - Aspect Ratio Control

    /// 무음 비디오 캡처가 끊기지 않도록 안정적인 비디오 프리셋을 적용하고 해상도 라벨을 반환합니다.
    private nonisolated func applySessionPreset(for aspectRatio: PhotoAspectRatio) -> String {
        if session.canSetSessionPreset(.hd4K3840x2160) {
            session.sessionPreset = .hd4K3840x2160
            print("📸 Using 4K resolution (3840x2160)")
            return aspectRatio == .fourByThree ? "4:3 (4K 기반)" : "16:9 4K (3840×2160)"
        } else if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
            print("📸 Using Full HD resolution (1920x1080)")
            return aspectRatio == .fourByThree ? "4:3 (FHD 기반)" : "16:9 Full HD (1920×1080)"
        } else {
            session.sessionPreset = .high
            print("📸 Using high video preset")
            return aspectRatio.rawValue
        }
    }

    /// 설정 화면에서 화면비 변경 시 호출. 프리뷰 끊김을 막기 위해 실행 중인 세션 프리셋은 바꾸지 않습니다.
    func updateAspectRatio(_ aspectRatio: PhotoAspectRatio) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  !self.session.inputs.isEmpty else { return }

            // 이전 화면비로 찍힌 버퍼 프레임 폐기
            self.resetRecentFrameBuffer()

            Task { @MainActor in
                self.currentResolutionLabel = self.resolutionLabel(for: aspectRatio)
            }
        }
    }

    private func resolutionLabel(for aspectRatio: PhotoAspectRatio) -> String {
        if session.sessionPreset == .hd4K3840x2160 {
            return aspectRatio == .fourByThree ? "4:3 (4K 기반)" : "16:9 4K (3840×2160)"
        }

        if session.sessionPreset == .hd1920x1080 {
            return aspectRatio == .fourByThree ? "4:3 (FHD 기반)" : "16:9 Full HD (1920×1080)"
        }

        return aspectRatio.rawValue
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

    /// 표시 줌 배율(0.5x~5x)을 받아 실제 videoZoomFactor로 변환해 적용
    func setZoomFactor(_ zoomFactor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.videoDeviceInput?.device else { return }

            let zoomScale = self.zoomDisplayScale
            let appliedZoomFactor = self.applyZoomFactor(
                zoomFactor * zoomScale,
                to: device,
                displayScale: zoomScale
            )

            Task { @MainActor in
                self.currentZoomFactor = appliedZoomFactor / zoomScale
            }
        }
    }

    /// 위치별 최적 캡처 디바이스 (후면: 듀얼 와이드 가상 카메라 우선 → 0.5x 지원)
    private nonisolated func bestCaptureDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .back,
           let dualWide = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            return dualWide
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    /// 표시 줌 1x에 해당하는 실제 videoZoomFactor (가상 카메라는 줌 1.0이 울트라와이드)
    private nonisolated func displayZoomScale(for device: AVCaptureDevice) -> CGFloat {
        guard let switchOverFactor = device.virtualDeviceSwitchOverVideoZoomFactors.first else {
            return 1.0
        }
        return CGFloat(truncating: switchOverFactor)
    }

    private nonisolated func clampedZoomFactor(
        _ zoomFactor: CGFloat,
        for device: AVCaptureDevice,
        displayScale: CGFloat
    ) -> CGFloat {
        let minimumZoomFactor = device.minAvailableVideoZoomFactor
        let maximumZoomFactor = min(
            device.maxAvailableVideoZoomFactor,
            AppConstants.Camera.maximumZoomFactor * displayScale
        )

        return min(max(zoomFactor, minimumZoomFactor), max(maximumZoomFactor, minimumZoomFactor))
    }

    private nonisolated func applyZoomFactor(
        _ zoomFactor: CGFloat,
        to device: AVCaptureDevice,
        displayScale: CGFloat
    ) -> CGFloat {
        let clampedZoomFactor = clampedZoomFactor(zoomFactor, for: device, displayScale: displayScale)

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

        if #available(iOS 26.0, *),
           format.isVideoStabilizationModeSupported(.lowLatency) {
            return .lowLatency
        }

        if format.isVideoStabilizationModeSupported(.standard) {
            return .standard
        }

        if format.isVideoStabilizationModeSupported(.previewOptimized) {
            return .previewOptimized
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

        guard isSessionRunning else {
            debugPrint("⚠️ Camera session not running")
            return nil
        }

        guard beginPhotoCapture() else {
            debugPrint("⚠️ Already capturing photo")
            return nil
        }
        defer { finishPhotoCapture() }
        let captureAspectRatio = SettingsManager.shared.photoAspectRatio

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

        if !hasCapturedSinceReset {
            let settleDelayNs = UInt64(AppConstants.Camera.initialCaptureSettleDelay * 1_000_000_000)
            if settleDelayNs > 0 {
                try? await Task.sleep(nanoseconds: settleDelayNs)
            }
        }

        let targetFrames = min(
            AppConstants.Camera.freshCaptureMinFrameCount,
            AppConstants.Camera.recentFrameBufferSize
        )

        // ⚡️ 빠른 경로: 셔터 직전까지 버퍼에 쌓인 프레임을 대기 없이 즉시 평가
        // (흔들림/초점/선명도 게이트는 selectSharpestFrame에서 동일하게 적용됨)
        var result: UIImage?
        let bufferedFrames = frameSnapshot(
            afterSequence: 0,
            maxAge: AppConstants.Camera.captureMaxCandidateAge
        )
        if bufferedFrames.count >= targetFrames {
            result = await renderBestBufferedFrame(
                from: bufferedFrames,
                aspectRatio: captureAspectRatio
            )
            if result != nil {
                debugPrint("⚡️ Fast path: captured from pre-shutter buffer")
            }
        }

        // 빠른 경로가 품질 기준을 통과하지 못한 경우에만 안정화 대기 후 새 프레임으로 재시도
        if result == nil {
            let motionReady = await waitForMotionToSettle(
                timeout: AppConstants.Camera.captureMotionSettleTimeout
            )
            if !motionReady {
                debugPrint("⚠️ Motion still high; relying on frame quality gate")
            }

            let cameraReady = await waitForCameraReadiness(
                timeout: AppConstants.Camera.captureReadinessTimeout
            )
            if !cameraReady {
                debugPrint("⚠️ Capturing before camera adjustment fully settled")
            }

            let startSequence = beginFreshFrameWindow()
            result = await waitForBestFreshFrame(
                afterSequence: startSequence,
                minFrameCount: targetFrames,
                timeout: AppConstants.Camera.freshCaptureFrameWaitTimeout,
                aspectRatio: captureAspectRatio
            )

            if result == nil {
                result = await waitForBestFreshFrame(
                    afterSequence: startSequence,
                    minFrameCount: min(targetFrames + 2, AppConstants.Camera.recentFrameBufferSize),
                    timeout: AppConstants.Camera.freshCaptureRetryWaitTimeout,
                    aspectRatio: captureAspectRatio
                )
            }
        }

        let captureElapsed = CFAbsoluteTimeGetCurrent() - captureStartTime
        if result != nil {
            hasCapturedSinceReset = true
            debugPrint("✅ Photo captured in \(String(format: "%.3f", captureElapsed))s")
        } else {
            debugPrint("⚠️ Photo capture skipped: no stable sharp frame found in \(String(format: "%.3f", captureElapsed))s")
        }
        return result
    }

    private nonisolated func beginPhotoCapture() -> Bool {
        captureLock.lock()
        defer { captureLock.unlock() }

        guard !_isCapturingPhoto else { return false }
        _isCapturingPhoto = true
        return true
    }

    private nonisolated func finishPhotoCapture() {
        captureLock.lock()
        _isCapturingPhoto = false
        captureLock.unlock()
    }

    private nonisolated func beginFreshFrameWindow() -> UInt64 {
        captureLock.lock()
        recentFrameBuffer.removeAll(keepingCapacity: true)
        let startSequence = _latestFrameSequence
        captureLock.unlock()
        return startSequence
    }

    private func waitForBestFreshFrame(
        afterSequence startSequence: UInt64,
        minFrameCount: Int,
        timeout: TimeInterval,
        aspectRatio: PhotoAspectRatio
    ) async -> UIImage? {
        let deadline = Date().addingTimeInterval(timeout)
        var lastFrames: [BufferedVideoFrame] = []
        var lastEvaluatedCount = 0

        while Date() < deadline {
            let frames = frameSnapshot(
                afterSequence: startSequence,
                maxAge: AppConstants.Camera.captureMaxCandidateAge
            )
            lastFrames = frames

            if frames.count >= minFrameCount, frames.count != lastEvaluatedCount {
                lastEvaluatedCount = frames.count
                if let image = await renderBestBufferedFrame(
                    from: frames,
                    aspectRatio: aspectRatio
                ) {
                    return image
                }
            }

            try? await Task.sleep(
                nanoseconds: UInt64(AppConstants.Camera.frameWaitInterval * 1_000_000_000)
            )
        }

        let finalFrames = frameSnapshot(
            afterSequence: startSequence,
            maxAge: AppConstants.Camera.captureMaxCandidateAge
        )
        let frames = finalFrames.isEmpty ? lastFrames : finalFrames
        guard !frames.isEmpty else {
            debugPrint("⚠️ No fresh buffered frames available for capture")
            return nil
        }

        return await renderBestBufferedFrame(
            from: frames,
            aspectRatio: aspectRatio
        )
    }

    private func renderBestBufferedFrame(
        from bufferedFrames: [BufferedVideoFrame],
        aspectRatio: PhotoAspectRatio
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                guard !bufferedFrames.isEmpty else {
                    debugPrint("⚠️ No fresh buffered frames available for capture")
                    continuation.resume(returning: nil)
                    return
                }

                guard let selectedFrame = self.selectSharpestFrame(from: bufferedFrames) else {
                    debugPrint("⚠️ No buffered frame passed sharpness/motion gate")
                    continuation.resume(returning: nil)
                    return
                }

                let startTime = CFAbsoluteTimeGetCurrent()
                let croppedCIImage = self.aspectCroppedImage(
                    selectedFrame.image,
                    to: aspectRatio.rawCaptureAspectRatio
                )
                let processedCIImage = self.applyPostProcessing(to: croppedCIImage)
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

                let motionText = selectedFrame.motionScore
                    .map { String(format: "%.2f", $0) }
                    ?? "n/a"
                debugPrint(
                    "✅ Buffered capture processed in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime))s, sharpness: \(String(format: "%.4f", selectedFrame.score)), motion: \(motionText)"
                )

                let orientation: UIImage.Orientation = self.isFrontCamera ? .leftMirrored : .right
                let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                continuation.resume(returning: image)
            }
        }
    }

    private func waitForCameraReadiness(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let state = await cameraReadinessState()
            if state.isReady {
                return true
            }

            try? await Task.sleep(
                nanoseconds: UInt64(AppConstants.Camera.frameWaitInterval * 1_000_000_000)
            )
        }

        let finalState = await cameraReadinessState()
        return finalState.isReady
    }

    private func cameraReadinessState() async -> CameraReadinessState {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self,
                      let device = self.videoDeviceInput?.device else {
                    continuation.resume(
                        returning: CameraReadinessState(
                            isAdjustingFocus: false,
                            isAdjustingExposure: false,
                            isAdjustingWhiteBalance: false
                        )
                    )
                    return
                }

                continuation.resume(
                    returning: CameraReadinessState(
                        isAdjustingFocus: device.isAdjustingFocus,
                        isAdjustingExposure: device.isAdjustingExposure,
                        isAdjustingWhiteBalance: device.isAdjustingWhiteBalance
                    )
                )
            }
        }
    }

    private func waitForMotionToSettle(timeout: TimeInterval) async -> Bool {
        guard latestMotionScore != nil else { return true }

        let deadline = Date().addingTimeInterval(timeout)
        var stableSampleCount = 0

        while Date() < deadline {
            let score = latestMotionScore ?? 0
            if score <= AppConstants.Camera.capturePreferredMotionScore {
                stableSampleCount += 1
                if stableSampleCount >= AppConstants.Camera.captureMotionStableSampleCount {
                    return true
                }
            } else {
                stableSampleCount = 0
            }

            try? await Task.sleep(
                nanoseconds: UInt64(AppConstants.Camera.frameWaitInterval * 1_000_000_000)
            )
        }

        return (latestMotionScore ?? 0) <= AppConstants.Camera.captureMaxMotionScore
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
        appendRecentFrame(
            imageBuffer,
            receivedAt: CACurrentMediaTime(),
            motionScore: latestMotionScore,
            readiness: currentCameraReadinessSnapshot()
        )
    }

    private nonisolated func appendRecentFrame(
        _ imageBuffer: CVPixelBuffer,
        receivedAt: CFTimeInterval,
        motionScore: Double?,
        readiness: CameraReadinessState
    ) {
        captureLock.lock()
        _latestFrameSequence += 1
        let sequence = _latestFrameSequence
        let frame = BufferedVideoFrame(
            pixelBuffer: imageBuffer,
            sequence: sequence,
            receivedAt: receivedAt,
            motionScore: motionScore,
            readiness: readiness
        )

        recentFrameBuffer.append(frame)
        let overflowCount = recentFrameBuffer.count - AppConstants.Camera.recentFrameBufferSize
        if overflowCount > 0 {
            recentFrameBuffer.removeFirst(overflowCount)
        }
        captureLock.unlock()
    }

    private nonisolated func resetRecentFrameBuffer() {
        captureLock.lock()
        recentFrameBuffer.removeAll(keepingCapacity: true)
        _isFrameReady = false
        _hasCapturedSinceReset = false
        captureLock.unlock()
    }

    private nonisolated func frameSnapshot(
        afterSequence startSequence: UInt64,
        maxAge: TimeInterval
    ) -> [BufferedVideoFrame] {
        let now = CACurrentMediaTime()
        captureLock.lock()
        let snapshot = recentFrameBuffer.filter { frame in
            frame.sequence > startSequence && (now - frame.receivedAt) <= maxAge
        }
        captureLock.unlock()
        return snapshot
    }

    private nonisolated func currentCameraReadinessSnapshot() -> CameraReadinessState {
        guard let device = videoDeviceInput?.device else {
            return CameraReadinessState(
                isAdjustingFocus: false,
                isAdjustingExposure: false,
                isAdjustingWhiteBalance: false
            )
        }

        return CameraReadinessState(
            isAdjustingFocus: device.isAdjustingFocus,
            isAdjustingExposure: device.isAdjustingExposure,
            isAdjustingWhiteBalance: device.isAdjustingWhiteBalance
        )
    }

    private nonisolated func selectSharpestFrame(from frames: [BufferedVideoFrame]) -> FrameSelection? {
        guard !frames.isEmpty else { return nil }
        let sampleCount = sharpnessSampleCount(for: frames.count)
        let candidateFrames = Array(frames.suffix(sampleCount))
        let minimumFramesForLumaGuard = 4
        let lumaDeltaThreshold: Float = 0.12
        let centerWeight: Float = 1.35
        let recencyWeight: Float = 0.08
        let centerCropRatio: CGFloat = 0.62

        let candidates = candidateFrames.map { frame in
            (
                frame: frame,
                image: CIImage(cvPixelBuffer: frame.pixelBuffer)
            )
        }
        guard !candidates.isEmpty else { return nil }

        let latestLuma = calculateAverageLuma(of: candidates.last!.image)
        var filteredCandidates = candidates

        if candidates.count >= minimumFramesForLumaGuard {
            filteredCandidates = candidates.filter { candidate in
                let luma = calculateAverageLuma(of: candidate.image)
                return abs(luma - latestLuma) <= lumaDeltaThreshold
            }
            if filteredCandidates.isEmpty {
                filteredCandidates = candidates
            }
        }

        let readinessFilteredCandidates = filteredCandidates.filter { candidate in
            candidate.frame.readiness.isReady
        }
        if !readinessFilteredCandidates.isEmpty {
            filteredCandidates = readinessFilteredCandidates
        }

        let motionFilteredCandidates = filteredCandidates.filter { candidate in
            guard let motionScore = candidate.frame.motionScore else { return true }
            return motionScore <= AppConstants.Camera.captureMaxMotionScore
        }

        if !motionFilteredCandidates.isEmpty {
            filteredCandidates = motionFilteredCandidates
        } else if filteredCandidates.allSatisfy({ $0.frame.motionScore != nil }) {
            return nil
        }

        var bestFrame: FrameSelection?
        var bestScore: Float = -1
        let downsampleScale = sharpnessDownsampleScale()
        let denominator = Float(max(filteredCandidates.count - 1, 1))

        for (index, candidate) in filteredCandidates.enumerated() {
            let components = calculateSharpnessComponents(
                of: candidate.image,
                downsampleScale: downsampleScale,
                centerCropRatio: centerCropRatio
            )
            let recencyBoost = (Float(index) / denominator) * recencyWeight
            let motionPenalty = candidate.frame.motionScore
                .map { Float(max($0 - AppConstants.Camera.capturePreferredMotionScore, 0)) * 0.08 }
                ?? 0
            let score = components.global + (components.center * centerWeight) + recencyBoost - motionPenalty

            if score > bestScore {
                bestScore = score
                bestFrame = FrameSelection(
                    image: candidate.image,
                    score: score,
                    motionScore: candidate.frame.motionScore
                )
            }
        }

        guard bestScore >= AppConstants.Camera.captureMinimumSharpnessScore else {
            #if DEBUG
            print("⚠️ Sharpness below threshold: \(String(format: "%.4f", bestScore))")
            #endif
            return nil
        }

        return bestFrame
    }

    /// 전체/중앙 엣지 기반 선명도 점수
    private nonisolated func calculateSharpnessComponents(
        of image: CIImage,
        downsampleScale: CGFloat,
        centerCropRatio: CGFloat
    ) -> (global: Float, center: Float) {
        let clampedScale = min(max(downsampleScale, 0.1), 1.0)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: clampedScale, y: clampedScale))
        let globalScore = edgeAverageScore(of: scaled)
        let centerImage = centerCroppedImage(from: scaled, ratio: centerCropRatio)
        let centerScore = edgeAverageScore(of: centerImage ?? scaled)
        return (global: globalScore, center: centerScore)
    }

    private nonisolated func edgeAverageScore(of image: CIImage) -> Float {
        // 그레이스케일 변환
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return 0 }
        grayscaleFilter.setValue(image, forKey: kCIInputImageKey)
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

    private nonisolated func centerCroppedImage(from image: CIImage, ratio: CGFloat) -> CIImage? {
        let clampedRatio = min(max(ratio, 0.2), 1.0)
        let extent = image.extent
        guard extent.width > 1, extent.height > 1 else { return nil }
        let width = extent.width * clampedRatio
        let height = extent.height * clampedRatio
        let cropRect = CGRect(
            x: extent.midX - (width / 2),
            y: extent.midY - (height / 2),
            width: width,
            height: height
        )
        return image.cropped(to: cropRect)
    }

    private nonisolated func aspectCroppedImage(_ image: CIImage, to targetAspectRatio: CGFloat) -> CIImage {
        let extent = image.extent
        guard extent.width > 1,
              extent.height > 1,
              targetAspectRatio > 0 else {
            return image
        }

        let sourceAspectRatio = extent.width / extent.height
        guard abs(sourceAspectRatio - targetAspectRatio) > 0.001 else {
            return image
        }

        let cropRect: CGRect
        if sourceAspectRatio > targetAspectRatio {
            let width = extent.height * targetAspectRatio
            cropRect = CGRect(
                x: extent.midX - (width / 2),
                y: extent.minY,
                width: width,
                height: extent.height
            )
        } else {
            let height = extent.width / targetAspectRatio
            cropRect = CGRect(
                x: extent.minX,
                y: extent.midY - (height / 2),
                width: extent.width,
                height: height
            )
        }

        return image.cropped(to: cropRect)
    }

    private nonisolated func calculateAverageLuma(of image: CIImage) -> Float {
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        avgFilter.setValue(image, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
        guard let avgOutput = avgFilter.outputImage else { return 0.5 }

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
        let defaultSampleCount = min(
            AppConstants.Camera.freshCaptureMinFrameCount + 1,
            AppConstants.Camera.recentFrameBufferSize
        )
        let lowPowerSampleCount = AppConstants.Camera.lowPowerSharpnessSampleCount
        let preferredCount = ProcessInfo.processInfo.isLowPowerModeEnabled
            ? lowPowerSampleCount
            : defaultSampleCount
        return min(max(preferredCount, 1), availableCount)
    }

    private nonisolated func sharpnessDownsampleScale() -> CGFloat {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
            ? AppConstants.Camera.lowPowerSharpnessDownsampleScale
            : AppConstants.Camera.defaultSharpnessDownsampleScale
    }

    // MARK: - 후처리 (샤프닝)

    private nonisolated func applyPostProcessing(to image: CIImage) -> CIImage {
        // 루미넌스 샤프닝 (색상 변화 없이 디테일만 강화)
        // CINoiseReduction 제거: 선명도 기반 최적 프레임 선택으로 이미 대체됨 (~50ms 절약)
        let sceneLuma = calculateAverageLuma(of: image)
        let sharpenAmount: CGFloat
        if sceneLuma < 0.22 {
            sharpenAmount = 0.20
        } else if sceneLuma < 0.45 {
            sharpenAmount = 0.28
        } else {
            sharpenAmount = 0.36
        }

        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        sharpenFilter.setValue(image, forKey: kCIInputImageKey)
        sharpenFilter.setValue(sharpenAmount, forKey: kCIInputSharpnessKey)
        return sharpenFilter.outputImage ?? image
    }
}
