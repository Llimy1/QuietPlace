//
//  ContentView.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import SwiftUI
import AVFoundation
import Photos

struct ContentView: View {
    @State private var currentTab: Tab = .fakeMode  // 기본 화면을 FakeMode로
    @State private var previousTab: Tab = .fakeMode
    @State private var isFirstLaunch: Bool = UserDefaults.standard.object(forKey: "isFirstLaunch") as? Bool ?? true
    @State private var hasRequestedPermissions = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var showSplash = true // 스플래시 화면 표시 여부
    @Environment(\.scenePhase) private var scenePhase
    
    enum Tab {
        case fakeMode
        case gallery
        case settings
    }
    
    var body: some View {
        mainAppContent
            .task {
                // 앱 시작 시 권한 요청 (첫 실행 시에만)
                if isFirstLaunch && !hasRequestedPermissions {
                    hasRequestedPermissions = true
                    await requestAllPermissions()
                }
            }
            .onAppear {
                // 앱이 시작될 때 권한 체크 (온보딩 완료 후)
                if !isFirstLaunch {
                    checkPermissions()
                }
                
                // 스플래시 화면 자동 숨김 (1.5초 후)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // 앱이 포그라운드로 돌아올 때 권한 체크
                if newPhase == .active && !isFirstLaunch {
                    checkPermissions()
                }
            }
            .alert("권한 필요", isPresented: $showPermissionAlert) {
                Button("설정 열기") {
                    openSettings()
                }
                Button("나중에", role: .cancel) { }
            } message: {
                Text(permissionAlertMessage)
            }
    }
    
    // MARK: - Main App Content
    
    private var mainAppContent: some View {
        ZStack {
            // 메인 앱
            NavigationStack {
                content
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .preferredColorScheme(.dark)
            .onChange(of: currentTab) { oldValue, newValue in
                if oldValue != newValue {
                    previousTab = oldValue
                }
            }
            
            // 온보딩 오버레이 (첫 실행 시)
            if isFirstLaunch {
                OnboardingView(isFirstLaunch: $isFirstLaunch)
                    .transition(.opacity)
                    .zIndex(999)
            }
            
            // 스플래시 오버레이 (앱 시작 시)
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1000) // 온보딩보다 위에 표시
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        Group {
            switch currentTab {
            case .fakeMode:
                FakeModeView(currentTab: $currentTab, previousTab: $previousTab)
            case .gallery:
                GalleryView(currentTab: $currentTab, previousTab: $previousTab)
            case .settings:
                SettingsView(currentTab: $currentTab, previousTab: $previousTab)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentTab)
    }
    
    // MARK: - 권한 체크
    
    private func checkPermissions() {
        var missingPermissions: [String] = []
        
        // 카메라 권한 체크
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus != .authorized {
            missingPermissions.append("카메라")
        }
        
        // 사진 권한 체크
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if photoStatus != .authorized && photoStatus != .limited {
            missingPermissions.append("사진 라이브러리")
        }
        
        // 권한이 하나라도 없으면 알림 표시
        if !missingPermissions.isEmpty {
            permissionAlertMessage = """
            \(missingPermissions.joined(separator: ", ")) 권한이 필요합니다.
            
            설정에서 권한을 허용해주세요.
            """
            showPermissionAlert = true
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // MARK: - 권한 요청
    
    private func requestAllPermissions() async {
        debugPrint("🔐 앱 시작 시 권한 요청 시작...")
        
        // 카메라와 사진 라이브러리 권한을 동시에 요청
        async let cameraRequest: Void = requestCameraPermission()
        async let photosRequest: Void = requestPhotosPermission()
        
        // 두 권한 요청이 모두 완료될 때까지 대기
        let _ = await (cameraRequest, photosRequest)
        
        debugPrint("✅ 모든 권한 요청 완료")
    }
    
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            // 권한이 결정되지 않았으면 요청
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            debugPrint("📷 카메라 권한: \(granted ? "허용됨" : "거부됨")")
        case .authorized:
            debugPrint("📷 카메라 권한: 이미 허용됨")
        case .denied, .restricted:
            debugPrint("📷 카메라 권한: 거부됨 또는 제한됨")
        @unknown default:
            break
        }
    }
    
    private func requestPhotosPermission() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .notDetermined:
            // 권한이 결정되지 않았으면 요청
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            let granted = (newStatus == .authorized || newStatus == .limited)
            debugPrint("📸 사진 라이브러리 권한: \(granted ? "허용됨" : "거부됨")")
        case .authorized, .limited:
            debugPrint("📸 사진 라이브러리 권한: 이미 허용됨")
        case .denied, .restricted:
            debugPrint("📸 사진 라이브러리 권한: 거부됨 또는 제한됨")
        @unknown default:
            break
        }
    }
}

#Preview {
    ContentView()
}
