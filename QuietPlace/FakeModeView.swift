//
//  FakeModeView.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import SwiftUI
import Combine
import AVFoundation

struct FakeModeView: View {
    @Binding var currentTab: ContentView.Tab
    @Binding var previousTab: ContentView.Tab
    @ObservedObject private var cameraManager = CameraManager.shared
    @StateObject private var photoDataManager = PhotoDataManager.shared
    @ObservedObject private var volumeHandler = VolumeButtonHandler.shared
    @ObservedObject private var settingsManager = SettingsManager.shared  // Settings 연동
    @Environment(\.scenePhase) var scenePhase
    @State private var currentTime = Date()
    @State private var showBottomNav = false
    @State private var previewPosition: CGPoint?  // Optional로 변경
    @State private var isPreviewVisible = true
    @State private var isTakingPhoto = false
    @State private var gradientColors: [Color] = []
    
    // Task 관리
    @State private var tapCount = 0
    @State private var tapTask: Task<Void, Never>?
    @State private var clockTask: Task<Void, Never>?
    @State private var lastTapTime = Date()
    
    private func startClock() {
        clockTask?.cancel()
        clockTask = Task {
            while !Task.isCancelled {
                currentTime = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func stopClock() {
        clockTask?.cancel()
        clockTask = nil
    }
    
    private func handleTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        // 0.4초 이내의 탭이면 연속 탭으로 간주
        if timeSinceLastTap < 0.4 {
            tapCount += 1
        } else {
            // 시간이 많이 지났으면 새로운 시퀀스 시작
            tapCount = 1
        }
        
        lastTapTime = now
        tapTask?.cancel()
        
        // 3번 빠른 탭: 프리뷰 숨기기/보이기
        if tapCount >= 3 {
            withAnimation {
                isPreviewVisible.toggle()
            }
            tapCount = 0
            tapTask?.cancel()
            tapTask = nil
            return
        }
        
        // 1번 탭: 촬영 (탭 촬영이 활성화되어 있고, 프리뷰가 보이는 경우)
        if tapCount == 1 && settingsManager.tapToCapture && isPreviewVisible {
            // 0.4초 대기 후 여전히 1번 탭이면 촬영
            tapTask = Task {
                try? await Task.sleep(for: .seconds(0.4))
                if !Task.isCancelled && tapCount == 1 {
                    takePhoto()
                    tapCount = 0
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let initialPreviewPosition = CGPoint(
                x: geometry.size.width - 80,
                y: geometry.size.height - 120
            )
            
            ZStack {
                // 배경 (랜덤 그라디언트)
                LinearGradient(
                    colors: gradientColors.isEmpty ? [.blue.opacity(0.3), .purple.opacity(0.5)] : gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // 어두운 오버레이 (가독성)
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                // 시간 표시
                VStack {
                    VStack(spacing: 8) {
                        Text(dateString)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        
                        Text(timeString)
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.top, 60)  // 최상단에서 60pt 아래
                    
                    Spacer()
                }
                
                // 하단 잠금화면 아이콘들 + 스와이프 영역
                VStack {
                    Spacer()
                    
                    HStack {
                        // 손전등 아이콘 (좌측 하단)
                        LockScreenButton(systemName: "flashlight.off.fill")
                            .padding(.leading, 40)
                        
                        Spacer()
                        
                        // 카메라 아이콘 (우측 하단)
                        LockScreenButton(systemName: "camera.fill")
                            .padding(.trailing, 40)
                    }
                    .padding(.bottom, 40)
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // 하단에서 위로 스와이프 감지
                            if value.translation.height < -50 && value.startLocation.y > geometry.size.height - 150 {
                                withAnimation(.spring()) {
                                    showBottomNav = true
                                }
                            }
                        }
                )
                
                // 🎥 Pinch로 크기 조절 가능한 카메라 프리뷰
                if isPreviewVisible {
                    PinchResizableCameraPreview(
                        position: $previewPosition,
                        defaultPosition: initialPreviewPosition,
                        scale: $settingsManager.previewScale,  // Settings와 연동
                        showBottomNav: $showBottomNav,
                        cameraSession: cameraManager.session,
                        isSessionRunning: cameraManager.isSessionRunning,
                        onCapture: { takePhoto() }
                    )
                }
                
                // 바텀 네비게이션 (스와이프 또는 프리뷰 탭으로 표시)
                if showBottomNav {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showBottomNav = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        FakeModeBottomNavigationBar(
                            currentTab: $currentTab,
                            previousTab: $previousTab,
                            showBottomNav: $showBottomNav
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            .contentShape(Rectangle())  // 전체 영역을 탭 가능하게
            .onTapGesture {
                handleTap()  // 전체 화면 어디든 탭 가능
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    startClock()
                    // ⚡️ 카메라는 필요할 때만 시작
                    if !cameraManager.isSessionRunning && cameraManager.isAuthorized {
                        cameraManager.startSession()
                    }
                    
                    // ⚡️ 볼륨 핸들러 재시작 (다른 화면에서 돌아올 때)
                    volumeHandler.restartMonitoring()
                    
                case .background, .inactive:
                    stopClock()
                @unknown default:
                    break
                }
            }
            .onChange(of: volumeHandler.volumeUpPressed) { oldValue, newValue in
                if !oldValue && newValue {
                    takePhoto()
                }
            }
            .onChange(of: volumeHandler.volumeDownPressed) { oldValue, newValue in
                if !oldValue && newValue {
                    takePhoto()
                }
            }
            .onAppear {
                debugPrint("📱 [FakeMode] View appeared")
                
                gradientColors = generateRandomGradient()
                startClock()
                
                // ⚡️ 최적화: 카메라는 한 번만 초기화
                Task {
                    if !cameraManager.isAuthorized {
                        await cameraManager.checkAuthorization()
                    }
                    
                    if cameraManager.isAuthorized {
                        // 세션이 비어있을 때만 설정
                        if cameraManager.session.inputs.isEmpty {
                            await cameraManager.setupCamera()
                        }
                        
                        // 실행 중이 아닐 때만 시작
                        if !cameraManager.isSessionRunning {
                            cameraManager.startSession()
                        }
                    }
                    
                    // 볼륨 버튼 모니터링 시작
                    volumeHandler.startMonitoring()
                }
            }
            .onDisappear {
                stopClock()
                tapTask?.cancel()
                tapTask = nil
                volumeHandler.stopMonitoring()
            }
            .alert("Error", isPresented: $cameraManager.showError) {
                Button("OK", role: .cancel) {
                    cameraManager.showError = false
                }
            } message: {
                Text(cameraManager.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: currentTime)
    }
    
    private func takePhoto() {
        // 이미 촬영 중이면 무시
        guard !isTakingPhoto else {
            debugPrint("⚠️ Photo capture already in progress, ignoring")
            return
        }
        
        Task {
            // 다시 한 번 체크 (race condition 방지)
            guard !isTakingPhoto else { return }
            
            isTakingPhoto = true
            
            do {
                if let capturedImage = try await cameraManager.capturePhoto() {
                    if let _ = await photoDataManager.savePhotoAsync(capturedImage) {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                }
            } catch {
                debugPrint("❌ Photo capture failed: \(error)")
            }
            
            isTakingPhoto = false
        }
    }
    
    
    private func generateRandomGradient() -> [Color] {
        let gradients: [[Color]] = [
            [.blue.opacity(0.3), .purple.opacity(0.5)],
            [.pink.opacity(0.3), .orange.opacity(0.5)],
            [.green.opacity(0.3), .blue.opacity(0.5)],
            [.purple.opacity(0.3), .pink.opacity(0.5)],
            [.orange.opacity(0.3), .red.opacity(0.5)],
            [.teal.opacity(0.3), .blue.opacity(0.5)],
            [.indigo.opacity(0.3), .purple.opacity(0.5)],
            [.cyan.opacity(0.3), .teal.opacity(0.5)]
        ]
        
        return gradients.randomElement() ?? [.blue.opacity(0.3), .purple.opacity(0.5)]
    }
}

// 🎥 Pinch 제스처로 자유롭게 크기 조절 가능한 카메라 프리뷰
struct PinchResizableCameraPreview: View {
    @Binding var position: CGPoint?
    let defaultPosition: CGPoint
    @Binding var scale: CGFloat  // 0.20 ~ 0.80 (20% ~ 80%)
    @Binding var showBottomNav: Bool
    let cameraSession: AVCaptureSession
    let isSessionRunning: Bool
    let onCapture: () -> Void
    
    // 크기 제약
    private let minScale: CGFloat = 0.20  // 20%
    private let maxScale: CGFloat = 0.80  // 80%
    private let largeThreshold: CGFloat = 0.60  // 60% 이상이면 큰 크기로 간주
    
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var lastPinchScale: CGFloat = 1.0
    @State private var bounceScale: CGFloat = 1.0
    @State private var showCaptureButton = false
    
    private var currentPosition: CGPoint {
        position ?? defaultPosition
    }
    
    // 화면 크기 기준으로 실제 크기 계산 (4:3 비율 유지)
    private var size: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let width = screenWidth * scale
        let height = width * 0.75  // 4:3 비율
        return CGSize(width: width, height: height)
    }
    
    // 큰 크기인지 확인
    private var isLargeSize: Bool {
        scale >= largeThreshold
    }
    
    var body: some View {
        ZStack {
            // 카메라 프리뷰
            CameraPreview(session: cameraSession)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            
            // 로딩 중일 때만 표시
            if !isSessionRunning {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(progressViewScale)
                    Text("Loading...")
                        .font(.system(size: loadingTextSize))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // 큰 크기일 때 촬영 버튼 표시
            if isLargeSize && showCaptureButton {
                VStack {
                    Spacer()
                    
                    Button(action: {
                        onCapture()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: captureButtonSize, height: captureButtonSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: captureButtonSize + 10, height: captureButtonSize + 10)
                            )
                    }
                    .padding(.bottom, captureButtonPadding)
                }
                .frame(width: size.width, height: size.height)
                .transition(.opacity)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.3), radius: shadowRadius, x: 0, y: 4)
        .scaleEffect(bounceScale * pinchScale)
        .position(currentPosition)
        .gesture(
            // 드래그 제스처 (이동)
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onChanged { value in
                    position = CGPoint(
                        x: value.location.x,
                        y: value.location.y
                    )
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        bounceScale = 0.95
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                        bounceScale = 1.0
                    }
                }
        )
        .simultaneousGesture(
            // Pinch 제스처 (크기 조절)
            MagnificationGesture()
                .updating($pinchScale) { value, state, _ in
                    state = value
                }
                .onChanged { value in
                    // 실시간으로 크기 조절
                    let newScale = (scale / lastPinchScale) * value
                    scale = min(max(newScale, minScale), maxScale)
                }
                .onEnded { value in
                    // 최종 크기 저장
                    let newScale = (scale / lastPinchScale) * value
                    scale = min(max(newScale, minScale), maxScale)
                    lastPinchScale = 1.0
                    
                    // 바운스 효과
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        bounceScale = 0.98
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                        bounceScale = 1.0
                    }
                }
        )
        .onChange(of: scale) { oldValue, newValue in
            // 큰 크기로 변경될 때 촬영 버튼 표시
            if newValue >= largeThreshold && oldValue < largeThreshold {
                withAnimation(.easeIn(duration: 0.2)) {
                    showCaptureButton = true
                }
            } else if newValue < largeThreshold && oldValue >= largeThreshold {
                showCaptureButton = false
            }
        }
        .onAppear {
            // 초기 크기가 큰 경우 촬영 버튼 표시
            if isLargeSize {
                showCaptureButton = true
            }
        }
    }
    
    // MARK: - Computed Properties (크기에 따라 UI 조정)
    
    private var cornerRadius: CGFloat {
        12 + (scale - minScale) / (maxScale - minScale) * 8  // 12 ~ 20
    }
    
    private var shadowRadius: CGFloat {
        8 + (scale - minScale) / (maxScale - minScale) * 8  // 8 ~ 16
    }
    
    private var progressViewScale: CGFloat {
        1.0 + (scale - minScale) / (maxScale - minScale) * 0.5  // 1.0 ~ 1.5
    }
    
    private var loadingTextSize: CGFloat {
        10 + (scale - minScale) / (maxScale - minScale) * 4  // 10 ~ 14
    }
    
    private var captureButtonSize: CGFloat {
        50 + (scale - largeThreshold) / (maxScale - largeThreshold) * 20  // 50 ~ 70
    }
    
    private var captureButtonPadding: CGFloat {
        10 + (scale - largeThreshold) / (maxScale - largeThreshold) * 10  // 10 ~ 20
    }
}

// 잠금화면 스타일 버튼 (손전등, 카메라)
struct LockScreenButton: View {
    let systemName: String
    
    var body: some View {
        ZStack {
            // 배경 원
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 50, height: 50)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
            
            // 아이콘
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// Fake Mode 바텀 네비게이션 바
struct FakeModeBottomNavigationBar: View {
    @Binding var currentTab: ContentView.Tab
    @Binding var previousTab: ContentView.Tab
    @Binding var showBottomNav: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            BottomNavButton(
                icon: "moon.fill",
                title: "조용한 모드",
                isActive: true
            ) {
                showBottomNav = false
            }
            
            BottomNavButton(
                icon: "photo.fill",
                title: "갤러리"
            ) {
                showBottomNav = false
                previousTab = currentTab
                currentTab = .gallery
            }
            
            BottomNavButton(
                icon: "gearshape.fill",
                title: "설정"
            ) {
                showBottomNav = false
                previousTab = currentTab
                currentTab = .settings
            }
        }
        .frame(height: 70)
        .background(
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    FakeModeView(currentTab: .constant(.fakeMode), previousTab: .constant(.fakeMode))
}
