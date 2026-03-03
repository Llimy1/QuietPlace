//
//  VolumeButtonHandler.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

@MainActor
class VolumeButtonHandler: ObservableObject {
    static let shared = VolumeButtonHandler()  // Singleton
    
    @Published var volumeUpPressed: Bool = false
    @Published var volumeDownPressed: Bool = false
    
    private var audioSession: AVAudioSession?
    private var volumeView: MPVolumeView?
    private var hiddenVolumeView: MPVolumeView?  // 시스템 UI를 숨기기 위한 뷰
    private var observation: NSKeyValueObservation?
    private var previousVolume: Float = 0.5
    private var isMonitoring: Bool = false  // 중복 시작 방지
    
    private init() {}  // Singleton이므로 private init
    
    func startMonitoring() {
        debugPrint("🔊 [Volume] startMonitoring called")
        
        guard !isMonitoring else {
            debugPrint("🔊 [Volume] Already monitoring")
            return
        }
        
        // 기존 리소스 정리
        cleanup()
        
        setupAudioSession()
        setupHiddenVolumeView()
        setupVolumeObservation()
        isMonitoring = true
        debugPrint("🔊 [Volume] Monitoring started successfully")
    }
    
    func stopMonitoring() {
        debugPrint("🔊 [Volume] stopMonitoring called")
        
        guard isMonitoring else {
            return
        }
        
        isMonitoring = false
        cleanup()
        debugPrint("🔊 [Volume] Monitoring stopped")
    }
    
    /// 재시작 - 갤러리에서 돌아올 때 사용
    func restartMonitoring() {
        debugPrint("🔊 [Volume] Restarting monitoring...")
        stopMonitoring()
        
        // 짧은 지연 후 재시작 (리소스 정리 시간 확보)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startMonitoring()
        }
    }
    
    /// 내부 정리 함수
    private func cleanup() {
        observation?.invalidate()
        observation = nil
        
        if let session = audioSession {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        audioSession = nil
        
        hiddenVolumeView?.removeFromSuperview()
        hiddenVolumeView = nil
        volumeView = nil
        
        debugPrint("🔊 [Volume] Resources cleaned up")
    }
    
    private func setupHiddenVolumeView() {
        // 화면 밖에 MPVolumeView를 배치하여 시스템 볼륨 UI를 숨김
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            // 화면 밖에 작은 크기로 배치 (완전히 투명하고 보이지 않음)
            let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            volumeView.alpha = 0.01  // 거의 투명하게
            volumeView.clipsToBounds = true
            volumeView.isUserInteractionEnabled = false
            
            // 윈도우에 추가하여 시스템 볼륨 UI를 대체
            window.addSubview(volumeView)
            self.hiddenVolumeView = volumeView
            
            debugPrint("✅ Hidden volume view added to suppress system UI")
        }
    }
    
    private func setupAudioSession() {
        do {
            audioSession = AVAudioSession.sharedInstance()
            
            // 오디오 세션 카테고리 설정 - ambient로 다른 앱과 공존
            try audioSession?.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(true)
            
            // 현재 볼륨 저장
            previousVolume = audioSession?.outputVolume ?? 0.5
            
            debugPrint("✅ Audio session setup complete. Current volume: \(previousVolume)")
            
            // 볼륨을 중간값으로 설정 (버튼 감지를 위해)
            if previousVolume <= 0.1 || previousVolume >= 0.9 {
                setSystemVolume(0.5)
                previousVolume = 0.5
                debugPrint("⚙️ Volume adjusted to 0.5 for better detection")
            }
        } catch {
            debugPrint("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupVolumeObservation() {
        guard let audioSession = audioSession else {
            debugPrint("❌ Cannot setup volume observation: audioSession is nil")
            return
        }
        
        observation = audioSession.observe(\.outputVolume, options: [.new, .old]) { [weak self] session, change in
            guard let self = self, let newVolume = change.newValue else { return }
            
            debugPrint("🔊 Volume changed: \(self.previousVolume) → \(newVolume)")
            
            Task { @MainActor in
                self.handleVolumeChange(newVolume)
            }
        }
        
        debugPrint("✅ Volume observation setup complete")
    }
    
    private func handleVolumeChange(_ newVolume: Float) {
        let threshold: Float = 0.01
        
        debugPrint("🔊 Volume: \(previousVolume) → \(newVolume)")
        
        if newVolume > previousVolume + threshold {
            // 볼륨 업
            debugPrint("🔊 ⬆️ Volume UP")
            volumeUpPressed = true
            objectWillChange.send()
            
            setSystemVolume(previousVolume)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.volumeUpPressed = false
                self.objectWillChange.send()
            }
            
        } else if newVolume < previousVolume - threshold {
            // 볼륨 다운
            debugPrint("🔊 ⬇️ Volume DOWN")
            volumeDownPressed = true
            objectWillChange.send()
            
            setSystemVolume(previousVolume)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.volumeDownPressed = false
                self.objectWillChange.send()
            }
        }
    }
    
    private func setSystemVolume(_ volume: Float) {
        debugPrint("🔊 Setting volume: \(volume)")
        
        DispatchQueue.main.async {
            if self.volumeView == nil {
                self.volumeView = MPVolumeView(frame: .zero)
            }
            
            guard let volumeView = self.volumeView,
                  let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider else {
                debugPrint("❌ Volume slider not found")
                return
            }
            
            slider.value = volume
            debugPrint("✅ Volume set to: \(volume)")
        }
    }
    
    deinit {
        // Don't create new tasks in deinit - cleanup synchronously
        observation?.invalidate()
        observation = nil
        
        // Remove hidden volume view
        hiddenVolumeView?.removeFromSuperview()
        hiddenVolumeView = nil
        
        // Deactivate audio session synchronously
        if let session = audioSession {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        audioSession = nil
        volumeView = nil
    }
}


