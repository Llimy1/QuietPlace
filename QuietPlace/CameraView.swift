//
//  CameraView.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/30/26.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @ObservedObject private var cameraManager = CameraManager.shared
    @StateObject private var photoDataManager = PhotoDataManager.shared
    @ObservedObject private var volumeHandler = VolumeButtonHandler.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isTakingPhoto = false
    @State private var showCaptureFlash = false
    @State private var showGallery = false
    @State private var showSettings = false
    @State private var lastThumbnail: UIImage?
    @State private var hasInitialized = false
    
    // 위장 모드 관련
    @State private var currentTime = Date()
    @State private var clockTask: Task<Void, Never>?
    @State private var gradientColors: [Color] = []
    
    // 탭 포커스 관련
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusIndicator = false
    @State private var focusTask: Task<Void, Never>? = nil
    @State private var zoomGestureStartFactor: CGFloat?
    @State private var showZoomIndicator = false
    @State private var zoomIndicatorTask: Task<Void, Never>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 풀스크린 카메라 프리뷰
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()

                // 카메라 전환 중 파란 플래시 방지 오버레이 (새 카메라 첫 프레임 수신 시 페이드아웃)
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(cameraManager.isSwitchingCamera ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.25), value: cameraManager.isSwitchingCamera)

                if !settingsManager.isDisguiseMode && settingsManager.isGridEnabled {
                    CameraGridOverlay()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                
                // 탭 포커스 (위장 모드가 아닐 때만)
                if !settingsManager.isDisguiseMode {
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            focusAt(point: location, viewSize: geometry.size)
                        }
                        .simultaneousGesture(cameraZoomGesture)
                    
                    // 포커스 인디케이터
                    if showFocusIndicator, let point = focusPoint {
                        FocusIndicator()
                            .position(point)
                    }
                }
                
                // 위장 모드 오버레이
                if settingsManager.isDisguiseMode {
                    disguiseOverlay(geometry: geometry)
                }
                
                // 촬영 플래시 효과
                if showCaptureFlash {
                    Color.black
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if !settingsManager.isDisguiseMode &&
                    (showZoomIndicator || cameraManager.currentZoomFactor > AppConstants.Camera.minimumZoomFactor + 0.01) {
                    VStack {
                        Text(zoomFactorText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                            .padding(.top, 64)

                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
                
                // 카메라 UI (위장 모드가 아닐 때만 표시)
                if !settingsManager.isDisguiseMode {
                    cameraUIOverlay(geometry: geometry)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    if settingsManager.isDisguiseMode {
                        startClock()
                    }
                    if !cameraManager.isSessionRunning && cameraManager.isAuthorized {
                        cameraManager.startSession()
                    }
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
            .onChange(of: settingsManager.isDisguiseMode) { _, isDisguise in
                if isDisguise {
                    gradientColors = generateRandomGradient()
                    startClock()
                } else {
                    stopClock()
                }
            }
            .onAppear {
                // 초기 1회만 카메라 설정 (fullScreenCover 복귀 시 중복 방지)
                guard !hasInitialized else {
                    // fullScreenCover에서 돌아올 때는 썸네일만 갱신
                    loadLastThumbnail()
                    return
                }
                hasInitialized = true
                
                if settingsManager.isDisguiseMode {
                    gradientColors = generateRandomGradient()
                    startClock()
                }
                
                Task {
                    if !cameraManager.isAuthorized {
                        await cameraManager.checkAuthorization()
                    }
                    if cameraManager.isAuthorized {
                        if cameraManager.session.inputs.isEmpty {
                            await cameraManager.setupCamera()
                        }
                        if !cameraManager.isSessionRunning {
                            cameraManager.startSession()
                        }
                    }
                    volumeHandler.startMonitoring()
                }
                
                loadLastThumbnail()
            }
            .alert("Error", isPresented: $cameraManager.showError) {
                Button("OK", role: .cancel) {
                    cameraManager.showError = false
                }
            } message: {
                Text(cameraManager.errorMessage ?? "An unknown error occurred")
            }
            .fullScreenCover(isPresented: $showGallery, onDismiss: {
                loadLastThumbnail()
            }) {
                NavigationStack {
                    GalleryView()
                }
            }
            .fullScreenCover(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
    
    // MARK: - Camera UI Overlay
    
    @ViewBuilder
    private func cameraUIOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            // 상단 바
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        settingsManager.isDisguiseMode = true
                    }
                }) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 36, height: 36)
                }
                .padding(.leading, 16)
                .padding(.top, 8)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: {
                        settingsManager.isGridEnabled.toggle()
                    }) {
                        Image(systemName: settingsManager.isGridEnabled ? "square.grid.3x3.fill" : "square.grid.3x3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                settingsManager.isGridEnabled
                                    ? Color.white.opacity(0.22)
                                    : Color.black.opacity(0.4)
                            )
                            .clipShape(Circle())
                    }

                    // 카메라 전환 버튼
                    Button(action: {
                        cameraManager.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing, 20)
                .padding(.top, 10)
            }
            
            Spacer()

            quickZoomControls()
                .padding(.bottom, 18)
            
            // 하단 바: 촬영 버튼 중앙 고정, 양쪽 대칭
//            ZStack {
//                // 촬영 버튼 (정중앙)
//                Button(action: {
//                    takePhoto()
//                }) {
//                    ZStack {
//                        Circle()
//                            .stroke(Color.white, lineWidth: 4)
//                            .frame(width: 72, height: 72)
//                        
//                        Circle()
//                            .fill(Color.white)
//                            .frame(width: 60, height: 60)
//                    }
//                }
//                
//                HStack {
//                    // 왼쪽: 위장 모드 + 갤러리 (세로)
//                    VStack(spacing: 12) {
//                        Button(action: {
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                settingsManager.isDisguiseMode = true
//                            }
//                        }) {
//                            Image(systemName: "eye.slash.fill")
//                                .font(.system(size: 18, weight: .medium))
//                                .foregroundColor(.white)
//                                .frame(width: 50, height: 50)
//                                .background(Color.black.opacity(0.4))
//                                .clipShape(Circle())
//                        }
//                        
//                        Button(action: {
//                            showGallery = true
//                        }) {
//                            if let thumbnail = lastThumbnail {
//                                Image(uiImage: thumbnail)
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 50, height: 50)
//                                    .clipShape(RoundedRectangle(cornerRadius: 10))
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 10)
//                                            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
//                                    )
//                            } else {
//                                RoundedRectangle(cornerRadius: 10)
//                                    .fill(Color.white.opacity(0.2))
//                                    .frame(width: 50, height: 50)
//                                    .overlay(
//                                        Image(systemName: "photo.fill")
//                                            .foregroundColor(.white.opacity(0.6))
//                                    )
//                            }
//                        }
//                    }
//                    
//                    Spacer()
//                    
//                    // 오른쪽: 설정
//                    Button(action: {
//                        showSettings = true
//                    }) {
//                        Image(systemName: "gearshape.fill")
//                            .font(.system(size: 20, weight: .medium))
//                            .foregroundColor(.white)
//                            .frame(width: 50, height: 50)
//                            .background(Color.black.opacity(0.4))
//                            .clipShape(Circle())
//                    }
//                }
//                .padding(.horizontal, 20)
//            }
//            .padding(.bottom, 30)
            // 하단 바: 촬영 버튼 중앙 고정, 양쪽 대칭
            ZStack {
                // 1. 촬영 버튼 (정중앙)
                Button(action: {
                    takePhoto()
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(isTakingPhoto ? 0.4 : 1.0), lineWidth: 4)
                            .frame(width: 72, height: 72)
                        
                        if isTakingPhoto {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                                .frame(width: 60, height: 60)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .disabled(isTakingPhoto)
                
                // 2. 좌우 버튼 (HStack - 기본 center 정렬)
                HStack {
                    Button(action: {
                        showGallery = true
                    }) {
                        if let thumbnail = lastThumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                    }
                    
                    Spacer()
                    
                    // 오른쪽: 설정
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func quickZoomControls() -> some View {
        let quickZoomPresets: [CGFloat] = [1, 2, 5]

        HStack(spacing: 12) {
            ForEach(quickZoomPresets, id: \.self) { preset in
                Button(action: {
                    showZoomIndicator = true
                    zoomIndicatorTask?.cancel()
                    cameraManager.setZoomFactor(preset)
                    scheduleZoomIndicatorDismiss()
                }) {
                    Text("\(Int(preset))x")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isZoomPresetSelected(preset) ? .black : .white)
                        .frame(minWidth: 52)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(isZoomPresetSelected(preset) ? Color.white : Color.black.opacity(0.35))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(isZoomPresetSelected(preset) ? 0 : 0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Disguise Mode Overlay
    
    @ViewBuilder
    private func disguiseOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            // 배경 그라디언트
            LinearGradient(
                colors: gradientColors.isEmpty ? [.blue.opacity(0.3), .purple.opacity(0.5)] : gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // 어두운 오버레이
            Color.black.opacity(settingsManager.disguiseOverlayOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if settingsManager.tapToCapture {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        takePhoto()
                    }
            }
            
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
                .padding(.top, 60)
                
                Spacer()
            }
            .allowsHitTesting(false)
            
            // 하단 잠금화면 아이콘
            VStack {
                Spacer()
                
                HStack {
                    LockScreenButton(systemName: "flashlight.off.fill")
                        .padding(.leading, 40)
                    
                    Spacer()
                    
                    Button(action: {
                        showGallery = true
                    }) {
                        LockScreenButton(systemName: "camera.fill")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 40)
                }
                .padding(.bottom, 40)
            }
            
            // 화면보호 모드 해제 버튼 (상단 좌측, 작고 눈에 안 띄게)
            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            settingsManager.isDisguiseMode = false
                        }
                    }) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 36, height: 36)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Actions
    
    private func takePhoto() {
        guard !isTakingPhoto else { return }
        
        Task {
            guard !isTakingPhoto else { return }
            isTakingPhoto = true
            
            do {
                if let capturedImage = try await cameraManager.capturePhoto() {
                    if let _ = await photoDataManager.savePhotoAsync(capturedImage) {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // 촬영 시각적 표시 (Recording Indicator - Apple Guideline 2.5.14)
                        withAnimation(.easeIn(duration: 0.05)) {
                            showCaptureFlash = true
                        }
                        try? await Task.sleep(for: .seconds(0.15))
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCaptureFlash = false
                        }
                        
                        // 썸네일 업데이트
                        loadLastThumbnail()
                    }
                }
            } catch {
                debugPrint("❌ Photo capture failed: \(error)")
            }
            
            isTakingPhoto = false
        }
    }
    
    private func focusAt(point: CGPoint, viewSize: CGSize) {
        // 촬영 버튼 영역 탭은 포커스 무시
        cameraManager.focusAt(point: point, viewSize: viewSize)
        
        // 포커스 인디케이터 표시
        focusPoint = point
        focusTask?.cancel()
        withAnimation(.easeIn(duration: 0.1)) {
            showFocusIndicator = true
        }
        focusTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.3)) {
                showFocusIndicator = false
            }
        }
    }

    private var cameraZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomGestureStartFactor == nil {
                    zoomGestureStartFactor = cameraManager.currentZoomFactor
                }

                let startFactor = zoomGestureStartFactor ?? cameraManager.currentZoomFactor
                showZoomIndicator = true
                zoomIndicatorTask?.cancel()
                cameraManager.setZoomFactor(startFactor * value)
            }
            .onEnded { _ in
                zoomGestureStartFactor = nil
                scheduleZoomIndicatorDismiss()
            }
    }

    private var zoomFactorText: String {
        String(format: "%.1fx", cameraManager.currentZoomFactor)
    }

    private func isZoomPresetSelected(_ preset: CGFloat) -> Bool {
        abs(cameraManager.currentZoomFactor - preset) < 0.15
    }

    private func scheduleZoomIndicatorDismiss() {
        zoomIndicatorTask?.cancel()
        zoomIndicatorTask = Task {
            try? await Task.sleep(
                for: .seconds(AppConstants.Camera.zoomIndicatorDismissDelay)
            )

            guard !Task.isCancelled else { return }
            showZoomIndicator = false
        }
    }
    
    private func loadLastThumbnail() {
        if let lastPhoto = photoDataManager.photos.first {
            let scale = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen.scale ?? 3
            let px = 50 * scale  // 카메라 UI 썸네일 버튼은 50pt
            lastThumbnail = lastPhoto.getThumbnail(size: CGSize(width: px, height: px))
        }
    }
    
    // MARK: - Clock (Disguise Mode)
    
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

// 탭 포커스 인디케이터
struct FocusIndicator: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 72, height: 72)
            
            // 4방향 모서리 강조선
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) * 90.0
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 12, height: 1.5)
                    .offset(x: 0, y: -36)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

// 잠금화면 스타일 버튼 (손전등, 카메라)
struct LockScreenButton: View {
    let systemName: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 50, height: 50)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
            
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

struct CameraGridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let thirdWidth = width / 3
                let thirdHeight = height / 3

                for index in 1...2 {
                    let x = thirdWidth * CGFloat(index)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                for index in 1...2 {
                    let y = thirdHeight * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        }
    }
}

#Preview {
    CameraView()
}
