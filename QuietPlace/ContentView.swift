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
    @State private var isFirstLaunch: Bool = UserDefaults.standard.object(forKey: "isFirstLaunch") as? Bool ?? true
    @State private var hasRequestedPermissions = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var showSplash = true
    @StateObject private var appUpdateManager = AppUpdateManager()
    @State private var updateCheckTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // 메인 카메라 뷰
            CameraView()
                .preferredColorScheme(.dark)
            
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
                    .zIndex(1000)
            }

            if let availableUpdate = appUpdateManager.availableUpdate,
               !isFirstLaunch,
               !showSplash {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1001)

                AppUpdatePromptCard(
                    version: availableUpdate.version,
                    onLater: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appUpdateManager.dismissUpdatePrompt()
                        }
                    },
                    onUpdate: {
                        appUpdateManager.openAppStoreForUpdate()
                    }
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1002)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appUpdateManager.availableUpdate != nil)
        .task {
            if isFirstLaunch && !hasRequestedPermissions {
                hasRequestedPermissions = true
                await requestAllPermissions()
            }
        }
        .onAppear {
            if !isFirstLaunch {
                checkPermissions()
                scheduleUpdateCheck()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && !isFirstLaunch {
                checkPermissions()
                scheduleUpdateCheck()
            } else if newPhase != .active {
                cancelUpdateCheck()
            }
        }
        .onDisappear {
            cancelUpdateCheck()
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

    private func scheduleUpdateCheck() {
        guard !isFirstLaunch else { return }

        updateCheckTask?.cancel()
        updateCheckTask = Task {
            let promptDelay = AppConstants.Debug.forceUpdatePrompt
                ? AppConstants.Timing.debugForcedUpdatePromptDelay
                : AppConstants.Timing.appUpdatePromptDelay
            let delay = UInt64(promptDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await appUpdateManager.checkForUpdateIfNeeded()
        }
    }

    private func cancelUpdateCheck() {
        updateCheckTask?.cancel()
        updateCheckTask = nil
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

private struct AppUpdatePromptCard: View {
    let version: String
    let onLater: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("새 버전이 있어요")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("QuietPlace \(version) 업데이트가 준비됐어요.\n더 안정적인 촬영 경험을 위해 업데이트해보세요.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.82))
                    .lineSpacing(3)
            }

            HStack(spacing: 12) {
                Button(action: onLater) {
                    Text("나중에")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(action: onUpdate) {
                    Text("업데이트하기")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
    }
}

#Preview {
    ContentView()
}
