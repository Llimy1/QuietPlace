//
//  OnboardingView.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/28/26.
//

import SwiftUI
import Photos
import AVFoundation

struct OnboardingView: View {
    @Binding var isFirstLaunch: Bool
    @State private var currentPage = 0
    @State private var cameraPermissionGranted = false
    @State private var photosPermissionGranted = false
    
    private let totalPages = 7  // 6 → 7로 변경
    
    var body: some View {
        ZStack {
            // 배경
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 건너뛰기 버튼 (마지막 페이지 제외)
                if currentPage < totalPages - 1 {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentPage = totalPages - 1
                            }
                        }) {
                            Text("건너뛰기")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                }
                
                // 페이지 컨텐츠
                TabView(selection: $currentPage) {
                    // 1페이지: 환영
                    WelcomePage()
                        .tag(0)
                    
                    // 2페이지: 잠금화면 위장
                    LockScreenPage()
                        .tag(1)
                    
                    // 3페이지: 무음 촬영
                    SilentCapturePage()
                        .tag(2)
                    
                    // 4페이지: 촬영 주의사항
                    CaptureNotesPage()
                        .tag(3)
                    
                    // 5페이지: 프리뷰 조절
                    PreviewResizePage()
                        .tag(4)
                    
                    // 6페이지: 갤러리
                    GalleryPage()
                        .tag(5)
                    
                    // 7페이지: 권한 요청
                    PermissionPage(
                        cameraPermissionGranted: $cameraPermissionGranted,
                        photosPermissionGranted: $photosPermissionGranted,
                        onComplete: {
                            completeOnboarding()
                        }
                    )
                    .tag(6)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))  // 기본 인디케이터 숨김
                .animation(.easeInOut(duration: 0.25), value: currentPage)
                
                // 하단 인디케이터 + 버튼
                VStack(spacing: 16) {
                    // 커스텀 페이지 인디케이터
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.blue : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // 다음 버튼 (마지막 페이지 제외)
                    if currentPage < totalPages - 1 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("다음")
                                    .font(.system(size: 18, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isFirstLaunch = false
        }
        
        // UserDefaults에 저장
        UserDefaults.standard.set(false, forKey: "isFirstLaunch")
    }
}

// MARK: - Page 1: 환영

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            // 앱 아이콘 (모서리 둥글게)
            BrandMark(size: 140)
                .shadow(color: BrandPalette.primaryBlue.opacity(0.5), radius: 30, x: 0, y: 10)
                .shadow(color: BrandPalette.secondaryPurple.opacity(0.3), radius: 50, x: 0, y: 20)

            // 그라데이션 타이틀 "Quite" + "Place"
            BrandTitle(isDark: true, fontSize: 48)
                .padding(.top, 20)

            // 곡선 스우시
            Swoosh(isDark: true)
                .frame(height: 28)
                .padding(.horizontal, 80)
                .padding(.top, 4)

            // 서브타이틀
            Text("조용한 장소에서도 편리하게")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 6)

            // 설명
            Text("도서관, 강의실, 전시회에서\n볼륨 버튼으로 무음 촬영")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Page 2: 조용한 모드

struct LockScreenPage: View {
    @State private var currentTime = Date()
    
    var body: some View {
        VStack(spacing: 36) {
            Spacer()
            
            // 타이틀
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 28))
                    .foregroundColor(BrandPalette.primaryBlue)
                
                Text("조용한 모드")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // 간단한 잠금화면 일러스트
            ZStack {
                // 폰 배경
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color.black)
                    .frame(width: 220, height: 380)
                    .overlay(
                        RoundedRectangle(cornerRadius: 50)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
                
                // 잠금화면 내용
                VStack(spacing: 16) {
                    // 시간
                    Text(timeString)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                    
                    // 날짜
                    Text(dateString)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                        .frame(height: 60)
                    
                    // 자물쇠 아이콘
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text("잠겨 있음")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 8)
                }
                .padding(.vertical, 50)
            }
            
            // 설명
            VStack(spacing: 12) {
                Text("조용한 환경에서도")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("방해하지 않고 촬영할 수 있어요")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.8))
            }
            .multilineTextAlignment(.center)
            
            // 포인트
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("화면 하단에 작은 프리뷰 제공")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .onAppear {
            currentTime = Date()
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
}

// MARK: - Page 3: 무음 촬영

struct SilentCapturePage: View {
    @State private var showFlash = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 타이틀
            HStack(spacing: 8) {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 28))
                    .foregroundColor(BrandPalette.accentCyan)
                
                Text("무음 촬영")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // 간단한 폰 + 볼륨 버튼 일러스트
            ZStack {
                // 폰 본체
                RoundedRectangle(cornerRadius: 45)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.15, blue: 0.2), Color(red: 0.1, green: 0.1, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 360)
                    .overlay(
                        RoundedRectangle(cornerRadius: 45)
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
                
                // 카메라 아이콘 (중앙)
                VStack(spacing: 20) {
                    if showFlash {
                        // 촬영 효과
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // 카메라
                        Image(systemName: "camera.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // 볼륨 버튼 안내
                    if !showFlash {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                Text("또는")
                                    .font(.system(size: 15))
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                            }
                            .foregroundColor(BrandPalette.accentCyan)
                            
                            Text("볼륨 버튼 누르기")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                // 왼쪽 볼륨 버튼들
                VStack(spacing: 10) {
                    // 볼륨 업
                    SimpleVolumeButton(isHighlighted: showFlash)
                        .onTapGesture {
                            triggerFlash()
                        }
                    
                    // 볼륨 다운
                    SimpleVolumeButton(isHighlighted: false)
                }
                .offset(x: -115, y: -30)
            }
            
            // 설명
            Text("볼륨 버튼으로 조용히 촬영하세요")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private func triggerFlash() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showFlash = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showFlash = false
            }
        }
    }
}

// 간단한 볼륨 버튼
struct SimpleVolumeButton: View {
    let isHighlighted: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                isHighlighted 
                    ? LinearGradient(colors: [BrandPalette.accentCyan, BrandPalette.accentCyan.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)], startPoint: .top, endPoint: .bottom)
            )
            .frame(width: 8, height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: isHighlighted ? BrandPalette.accentCyan.opacity(0.8) : .clear, radius: isHighlighted ? 15 : 0, x: -5, y: 0)
            .scaleEffect(isHighlighted ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
    }
}

// MARK: - Page 4: 촬영 주의사항

struct CaptureNotesPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 아이콘
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 45))
                    .foregroundColor(.blue)
            }
            
            // 타이틀
            Text("촬영 방법")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // 설명
            Text("두 가지 방법으로 촬영할 수 있어요")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 8)
            
            // 주의사항 카드들 (2열로 정리)
            VStack(spacing: 14) {
                // 첫 번째 행: 촬영 방법
                HStack(spacing: 14) {
                    // 볼륨 버튼
                    CompactNoticeCard(
                        icon: "speaker.wave.2.fill",
                        iconColor: .purple,
                        title: "볼륨 버튼",
                        description: "가장 편리한 방법"
                    )
                    
                    // 화면 탭
                    CompactNoticeCard(
                        icon: "hand.tap.fill",
                        iconColor: .blue,
                        title: "화면 탭",
                        description: "통화 중 유용"
                    )
                }
                
                // 두 번째 행: 팁
                HStack(spacing: 14) {
                    // 진동 피드백
                    CompactNoticeCard(
                        icon: "iphone.radiowaves.left.and.right",
                        iconColor: .green,
                        title: "진동으로 확인",
                        description: "촬영 완료 알림"
                    )
                    
                    // 설정
                    CompactNoticeCard(
                        icon: "gearshape.fill",
                        iconColor: .orange,
                        title: "설정 가능",
                        description: "탭 촬영 켜기/끄기"
                    )
                }
            }
            .padding(.horizontal, 28)
            
            // 추가 팁
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 16))
                    
                    Text("통화/음악 재생 중에는")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Text("볼륨 버튼 2번 누르기 or 화면 탭 사용")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(14)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Page 5: 프리뷰 조절

struct PreviewResizePage: View {
    @State private var scale: CGFloat = 0.3
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 프리뷰 크기 조절 애니메이션
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 300 * scale, height: 225 * scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    )
                    .animation(.spring(response: 0.5), value: scale)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 30 * scale))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // 핀치 제스처 아이콘
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text("두 손가락으로 확대/축소")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // 타이틀
            Text("📐 크기 조절")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // 설명
            VStack(spacing: 12) {
                Text("두 손가락으로 프리뷰를")
                Text("확대/축소할 수 있어요")
                Text("원하는 크기로 조절하세요")
            }
            .font(.system(size: 17))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            
            // 팁
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("20% ~ 80% 범위로 조절 가능")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .onAppear {
            // 자동 애니메이션 시작
            startAnimation()
        }
        .onDisappear {
            // 타이머 정리
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.spring(response: 0.5)) {
                scale = scale == 0.3 ? 0.6 : 0.3
            }
        }
    }
}

// MARK: - Page 6: 갤러리

struct GalleryPage: View {
    @State private var selectedPhoto = 0
    let photoColors: [Color] = [
        BrandPalette.primaryBlue,
        BrandPalette.secondaryPurple,
        BrandPalette.accentCyan,
        Color.pink,
        Color.orange,
        Color.green
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // 타이틀
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 26))
                    .foregroundColor(BrandPalette.secondaryPurple)
                
                Text("안전한 갤러리")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // 갤러리 그리드 목업
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        PhotoGridItem(
                            color: photoColors[index],
                            isSelected: selectedPhoto == index
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPhoto = index
                            }
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    ForEach(3..<6, id: \.self) { index in
                        PhotoGridItem(
                            color: photoColors[index],
                            isSelected: selectedPhoto == index
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPhoto = index
                            }
                        }
                    }
                }
            }
            
            // 설명
            VStack(spacing: 3) {
                Text("앱 내부에만 저장되어")
                Text("안전하게 보호됩니다")
            }
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.7))
            
            // 기능 목록
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "calendar",
                    text: "날짜별 자동 정리",
                    color: BrandPalette.primaryBlue
                )
                FeatureRow(
                    icon: "checkmark.square",
                    text: "사진 선택 & 삭제",
                    color: BrandPalette.accentCyan
                )
                FeatureRow(
                    icon: "square.and.arrow.down",
                    text: "사진첩으로 내보내기",
                    color: BrandPalette.secondaryPurple
                )
            }
            .padding(.horizontal, 50)
            
            Spacer()
        }
    }
}

// 갤러리 그리드 아이템
struct PhotoGridItem: View {
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.3),
                        color.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 85, height: 85)
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: isSelected ? 15 : 0, x: 0, y: 0)
    }
}

// MARK: - Page 7: 권한 요청

struct PermissionPage: View {
    @Binding var cameraPermissionGranted: Bool
    @Binding var photosPermissionGranted: Bool
    let onComplete: () -> Void
    
    @State private var isRequestingCamera = false
    @State private var isRequestingPhotos = false
    @State private var showSettingsAlert = false
    @State private var settingsAlertMessage = ""
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 체크마크 아이콘 (모든 권한 허용 시 초록색)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: allPermissionsGranted 
                                ? [Color.green.opacity(0.3), Color.green.opacity(0.2)]
                                : [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: allPermissionsGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(allPermissionsGranted ? .green : .orange)
                    .symbolEffect(.bounce, value: allPermissionsGranted)
            }
            
            // 타이틀
            Text(allPermissionsGranted ? "✅ 모든 준비 완료!" : "🔐 필수 권한 설정")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // 설명
            Text(allPermissionsGranted 
                ? "이제 QuitePlace를 사용할 수 있습니다" 
                : "앱 사용을 위해\n두 권한이 모두 필요합니다")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            // 권한 버튼들
            VStack(spacing: 16) {
                PermissionButton(
                    icon: "camera.fill",
                    title: "카메라",
                    description: "사진 촬영에 필요 (필수)",
                    isGranted: cameraPermissionGranted,
                    isRequesting: isRequestingCamera,
                    action: {
                        requestCameraPermission()
                    }
                )
                
                PermissionButton(
                    icon: "photo.fill",
                    title: "사진 라이브러리",
                    description: "사진 저장에 필요 (필수)",
                    isGranted: photosPermissionGranted,
                    isRequesting: isRequestingPhotos,
                    action: {
                        requestPhotosPermission()
                    }
                )
            }
            .padding(.horizontal, 40)
            
            // 중요 안내 메시지 (권한이 모두 허용되지 않은 경우)
            if !allPermissionsGranted {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("두 권한 모두 허용해야 앱을 사용할 수 있습니다")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 40)
            }
            
            // 시작하기 버튼 (모든 권한 허용 시에만 활성화)
            Button(action: {
                if allPermissionsGranted {
                    onComplete()
                }
            }) {
                HStack {
                    Text("시작하기")
                        .font(.system(size: 18, weight: .semibold))
                    if allPermissionsGranted {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: allPermissionsGranted 
                            ? [Color.green, Color.green.opacity(0.8)]
                            : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: allPermissionsGranted ? Color.green.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
            }
            .disabled(!allPermissionsGranted)
            .padding(.horizontal, 40)
            .animation(.easeInOut, value: allPermissionsGranted)
            
            if !allPermissionsGranted {
                VStack(spacing: 8) {
                    Text("권한이 거부되었나요?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Button(action: {
                        openSettings()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                            Text("설정에서 권한 허용하기")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            // 현재 권한 상태 확인
            checkCurrentPermissions()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // 앱이 포그라운드로 돌아올 때 권한 상태 다시 확인 (설정에서 변경했을 수 있음)
            if newPhase == .active {
                checkCurrentPermissions()
            }
        }
        .alert("설정으로 이동", isPresented: $showSettingsAlert) {
            Button("취소", role: .cancel) { }
            Button("설정 열기") {
                openSettings()
            }
        } message: {
            Text(settingsAlertMessage)
        }
    }
    
    private var allPermissionsGranted: Bool {
        cameraPermissionGranted && photosPermissionGranted
    }
    
    private func checkCurrentPermissions() {
        // 카메라 권한 확인
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            await MainActor.run {
                cameraPermissionGranted = (status == .authorized)
            }
        }
        
        // 사진 권한 확인
        Task {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            await MainActor.run {
                photosPermissionGranted = (status == .authorized || status == .limited)
            }
        }
    }
    
    private func requestCameraPermission() {
        guard !cameraPermissionGranted else { return }
        
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        // 이미 거부된 상태면 설정으로 안내
        if currentStatus == .denied || currentStatus == .restricted {
            settingsAlertMessage = "카메라 권한이 거부되었습니다.\n설정 > QuitePlace에서 카메라 권한을 허용해주세요."
            showSettingsAlert = true
            return
        }
        
        isRequestingCamera = true
        
        Task {
            await CameraManager.shared.checkAuthorization()
            
            // 짧은 대기 후 상태 확인
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                cameraPermissionGranted = CameraManager.shared.isAuthorized
                isRequestingCamera = false
                
                // 권한이 거부되었다면 설정으로 이동 안내
                if !cameraPermissionGranted {
                    settingsAlertMessage = "카메라 권한이 필요합니다.\n설정에서 권한을 허용해주세요."
                    showSettingsAlert = true
                }
            }
        }
    }
    
    private func requestPhotosPermission() {
        guard !photosPermissionGranted else { return }
        
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        // 이미 거부된 상태면 설정으로 안내
        if currentStatus == .denied || currentStatus == .restricted {
            settingsAlertMessage = "사진 라이브러리 권한이 거부되었습니다.\n설정 > QuitePlace에서 사진 권한을 허용해주세요."
            showSettingsAlert = true
            return
        }
        
        isRequestingPhotos = true
        
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            
            await MainActor.run {
                photosPermissionGranted = (status == .authorized || status == .limited)
                isRequestingPhotos = false
                
                if !photosPermissionGranted {
                    settingsAlertMessage = "사진 라이브러리 권한이 필요합니다.\n설정에서 권한을 허용해주세요."
                    showSettingsAlert = true
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let text: String
    var color: Color = .green
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}

struct NoticeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            // 텍스트
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(iconColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// 컴팩트한 카드 (2열 레이아웃용)
struct CompactNoticeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 54, height: 54)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }
            
            // 텍스트
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [iconColor.opacity(0.3), iconColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: iconColor.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct PermissionButton: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isRequesting: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(isGranted ? .green : .white.opacity(0.7))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                } else if !isRequesting {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isGranted ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .disabled(isGranted || isRequesting)
    }
}

#Preview {
    OnboardingView(isFirstLaunch: .constant(true))
}

