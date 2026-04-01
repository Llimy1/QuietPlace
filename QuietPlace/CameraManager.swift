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
    @Published var isFlashOn = false
    @Published var isUsingFrontCamera = false
    @Published var currentResolutionLabel = "-"
    
    // Camera session
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let outputQueue = DispatchQueue(label: "camera.output", qos: .userInteractive)
    
    // Capture state (thread-safe)
    nonisolated(unsafe) private var photoContinuation: CheckedContinuation<UIImage?, Error>?
    nonisolated(unsafe) private let captureLock = NSLock()
    nonisolated(unsafe) private var _isCapturingPhoto = false
    nonisolated(unsafe) private var _isFrameReady = false
    nonisolated(unsafe) private var _isFrontCamera = false
    
    // ⚡️ 재사용 가능한 CIContext (성능 최적화 - 미리 초기화)
    nonisolated(unsafe) private let ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
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
                
                // Full HD 해상도 설정
                let resolutionLabel: String
                if self.session.canSetSessionPreset(.hd1920x1080) {
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
                        
                        self.videoOutput.videoSettings = [
                            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                        ]
                        
                        self.videoOutput.alwaysDiscardsLateVideoFrames = false
                        self.videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)
                        
                        // 손떨림 방지 (Video Stabilization) - 설정값 반영
                        if let connection = self.videoOutput.connection(with: .video) {
                            if connection.isVideoStabilizationSupported {
                                let enabled = SettingsManager.shared.isStabilizationEnabled
                                connection.preferredVideoStabilizationMode = enabled ? .cinematic : .off
                                debugPrint("✅ Video stabilization: \(enabled ? "cinematic" : "off")")
                            }
                        }
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
                    
                    camera.unlockForConfiguration()
                    
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
    
    // MARK: - Flash Control
    
    func toggleFlash() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.videoDeviceInput?.device,
                  device.hasTorch else { return }
            
            do {
                try device.lockForConfiguration()
                device.torchMode = device.torchMode == .on ? .off : .on
                device.unlockForConfiguration()
                
                Task { @MainActor in
                    self.isFlashOn = (device.torchMode == .on)
                }
            } catch {
                debugPrint("❌ Flash toggle failed: \(error)")
            }
        }
    }
    
    // MARK: - Camera Switch
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let currentPosition = self.videoDeviceInput?.device.position ?? .back
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else { return }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.session.beginConfiguration()
                
                if let currentInput = self.videoDeviceInput {
                    self.session.removeInput(currentInput)
                }
                
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                }
                
                self.session.commitConfiguration()
                
                self._isFrontCamera = (newPosition == .front)
                Task { @MainActor in
                    self.isUsingFrontCamera = (newPosition == .front)
                    self.isFlashOn = false
                }
            } catch {
                debugPrint("❌ Camera switch failed: \(error)")
            }
        }
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.session.isRunning else {
                Task { @MainActor in
                    self.isSessionRunning = true
                }
                return
            }
            
            self.session.startRunning()
            
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
                  let connection = self.videoOutput.connection(with: .video) else { return }
            
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = enabled ? .cinematic : .off
                debugPrint("✅ Video stabilization updated: \(enabled ? "cinematic" : "off")")
            }
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
            
            // 타임아웃 (1초로 증가 - 안정성 향상)
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // ⚡️ lock으로 안전하게 체크
                captureLock.lock()
                if self.photoContinuation != nil {
                    debugPrint("⚠️ Photo capture timeout")
                    self.photoContinuation?.resume(returning: nil)
                    self.photoContinuation = nil
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
        // ⚡️ 첫 프레임 도착 표시
        if !isFrameReady {
            isFrameReady = true
            debugPrint("✅ First frame ready!")
        }
        
        // 촬영 중일 때만 프레임 캡처
        guard isCapturingPhoto else { return }
        
        let frameProcessStartTime = CFAbsoluteTimeGetCurrent()
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // CIImage로 변환
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // ⚡️ 재사용된 CIContext 사용 (성능 향상)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let processingElapsed = CFAbsoluteTimeGetCurrent() - frameProcessStartTime
        debugPrint("🎬 Frame processed in \(String(format: "%.3f", processingElapsed))s")
        
        // UIImage 생성 (전면 카메라는 좌우 반전 보정)
        let orientation: UIImage.Orientation = _isFrontCamera ? .leftMirrored : .right
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        
        // ⚡️ lock으로 안전하게 continuation resume (MainActor 오버헤드 제거)
        captureLock.lock()
        if let continuation = photoContinuation {
            photoContinuation = nil
            captureLock.unlock()
            
            debugPrint("✅ Resuming continuation with image")
            // continuation은 이미 MainActor context에서 생성되었으므로 안전
            continuation.resume(returning: image)
        } else {
            captureLock.unlock()
        }
    }
}

