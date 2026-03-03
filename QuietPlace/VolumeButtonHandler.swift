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
        print("🔊 [Volume] startMonitoring called")
        
        guard !isMonitoring else {
            print("🔊 [Volume] Already monitoring")
            return
        }
        
        setupAudioSession()
        setupHiddenVolumeView()
        setupVolumeObservation()
        isMonitoring = true
        print("🔊 [Volume] Monitoring started")
    }
    
    func stopMonitoring() {
        print("🔊 [Volume] stopMonitoring called")
        
        guard isMonitoring else {
            return
        }
        
        isMonitoring = false
        observation?.invalidate()
        observation = nil
        
        if let session = audioSession {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        audioSession = nil
        
        hiddenVolumeView?.removeFromSuperview()
        hiddenVolumeView = nil
        volumeView = nil
        
        print("🔊 [Volume] Monitoring stopped")
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
            
            print("✅ Hidden volume view added to suppress system UI")
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
            
            print("✅ Audio session setup complete. Current volume: \(previousVolume)")
            
            // 볼륨을 중간값으로 설정 (버튼 감지를 위해)
            if previousVolume <= 0.1 || previousVolume >= 0.9 {
                setSystemVolume(0.5)
                previousVolume = 0.5
                print("⚙️ Volume adjusted to 0.5 for better detection")
            }
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupVolumeObservation() {
        guard let audioSession = audioSession else {
            print("❌ Cannot setup volume observation: audioSession is nil")
            return
        }
        
        observation = audioSession.observe(\.outputVolume, options: [.new, .old]) { [weak self] session, change in
            guard let self = self, let newVolume = change.newValue else { return }
            
            print("🔊 Volume changed: \(self.previousVolume) → \(newVolume)")
            
            Task { @MainActor in
                self.handleVolumeChange(newVolume)
            }
        }
        
        print("✅ Volume observation setup complete")
    }
    
    private func handleVolumeChange(_ newVolume: Float) {
        let threshold: Float = 0.01
        
        print("🔊 handleVolumeChange called: prev=\(previousVolume), new=\(newVolume), diff=\(newVolume - previousVolume)")
        
        if newVolume > previousVolume + threshold {
            // 볼륨 업 버튼 눌림
            print("🔊 ⬆️ Volume UP detected - BEFORE: volumeUpPressed = \(volumeUpPressed)")
            
            // ⚡️ MainActor에서 즉시 업데이트 (동기적으로)
            volumeUpPressed = true
            print("🔊 ⬆️ Volume UP detected - AFTER: volumeUpPressed = \(volumeUpPressed)")
            
            // SwiftUI가 변경을 감지하도록 명시적으로 objectWillChange 트리거
            objectWillChange.send()
            print("🔊 ⬆️ objectWillChange.send() called")
            
            // 즉시 원래 볼륨으로 복원 (UI 이벤트 중복 방지)
            setSystemVolume(previousVolume)
            
            // 짧은 지연 후 상태 리셋
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔊 ⬆️ Volume UP reset - BEFORE: volumeUpPressed = \(self.volumeUpPressed)")
                self.volumeUpPressed = false
                print("🔊 ⬆️ Volume UP reset - AFTER: volumeUpPressed = \(self.volumeUpPressed)")
                self.objectWillChange.send()
            }
            
        } else if newVolume < previousVolume - threshold {
            // 볼륨 다운 버튼 눌림
            print("🔊 ⬇️ Volume DOWN detected - BEFORE: volumeDownPressed = \(volumeDownPressed)")
            
            // ⚡️ MainActor에서 즉시 업데이트 (동기적으로)
            volumeDownPressed = true
            print("🔊 ⬇️ Volume DOWN detected - AFTER: volumeDownPressed = \(volumeDownPressed)")
            
            // SwiftUI가 변경을 감지하도록 명시적으로 objectWillChange 트리거
            objectWillChange.send()
            print("🔊 ⬇️ objectWillChange.send() called")
            
            // 즉시 원래 볼륨으로 복원 (UI 이벤트 중복 방지)
            setSystemVolume(previousVolume)
            
            // 짧은 지연 후 상태 리셋
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔊 ⬇️ Volume DOWN reset - BEFORE: volumeDownPressed = \(self.volumeDownPressed)")
                self.volumeDownPressed = false
                print("🔊 ⬇️ Volume DOWN reset - AFTER: volumeDownPressed = \(self.volumeDownPressed)")
                self.objectWillChange.send()
            }
        } else {
            print("🔊 Volume change within threshold - ignoring")
        }
        
        // previousVolume은 업데이트하지 않음 (항상 같은 볼륨 유지)
    }
    
    private func setSystemVolume(_ volume: Float) {
        print("🔊 setSystemVolume called: \(volume)")
        
        // MPVolumeView를 사용하여 시스템 볼륨 조절
        DispatchQueue.main.async {
            if self.volumeView == nil {
                self.volumeView = MPVolumeView(frame: .zero)
                print("🔊 Created new MPVolumeView for volume control")
            }
            
            guard let volumeView = self.volumeView else {
                print("❌ volumeView is nil")
                return
            }
            
            // Slider를 찾아서 볼륨 설정
            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                slider.value = volume
                print("✅ Volume set to: \(volume)")
            } else {
                print("❌ Could not find volume slider in MPVolumeView")
            }
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


