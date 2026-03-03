//
//  SettingsView.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @Binding var currentTab: ContentView.Tab
    @Binding var previousTab: ContentView.Tab
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showResetAlert = false
    @State private var cacheInfo: (memoryCount: Int, memoryLimit: String, diskCount: Int, diskSize: String)?
    @State private var showClearCacheAlert = false
    @State private var showOnboardingAgain = false  // 온보딩 다시 보기
    @State private var showPrivacyPolicy = false  // 개인정보 보호정책
    @State private var showEmailCopiedAlert = false  // 이메일 복사 알림
    
    // 지원 이메일
    private let supportEmail = "llimy.mh@gmail.com"
    
    // 앱 버전 자동 가져오기
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 메인 컨텐츠
            ScrollView {
                VStack(spacing: 24) {
                    // 프리뷰 크기 섹션
                    SettingsSection(title: "프리뷰 크기") {
                        VStack(spacing: 16) {
                            // 크기 슬라이더
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("프리뷰 크기")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(settingsManager.previewScale * 100))%")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .frame(minWidth: 50, alignment: .trailing)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                
                                // 슬라이더
                                HStack(spacing: 12) {
                                    Text("20%")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    
                                    Slider(
                                        value: $settingsManager.previewScale,
                                        in: 0.20...0.80,
                                        step: 0.01
                                    )
                                    .tint(.blue)
                                    
                                    Text("80%")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // 설명
                            VStack(alignment: .leading, spacing: 8) {
                                Text("손가락으로 프리뷰를 확대/축소할 수도 있습니다")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Text("60% 이상: 촬영 버튼 표시")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                    
                    // 조용한 모드 섹션
                    SettingsSection(title: "조용한 모드") {
                        VStack(spacing: 0) {
                            // 탭으로 촬영 토글
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("화면 탭으로 촬영")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.primary)
                                    
                                    Text("통화 중 볼륨 버튼이 작동하지 않을 때 유용합니다")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $settingsManager.tapToCapture)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // 배경 설명
                            VStack(alignment: .leading, spacing: 12) {
                                Text("배경")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                Text("잠금화면 배경은 자동으로 랜덤 그라디언트가 적용됩니다.")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    // Storage 섹션
                    SettingsSection(title: "저장소") {
                        VStack(spacing: 0) {
                            CacheInfoRow()
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "썸네일 캐시 삭제",
                                showArrow: false
                            ) {
                                clearThumbnailCache()
                            }
                        }
                    }
                    
                    // 도움말 섹션
                    SettingsSection(title: "도움말") {
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "사용 가이드 다시 보기",
                                showArrow: true
                            ) {
                                showOnboarding()
                            }
                        }
                    }
                    
                    // 문의 섹션
                    SettingsSection(title: "문의") {
                        VStack(spacing: 0) {
                            // 이메일 주소 표시 및 복사
                            Button(action: {
                                copyEmailToClipboard()
                            }) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("이메일 문의")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.primary)
                                        
                                        Text(supportEmail)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.blue)
                                        
                                        Text("복사")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // General 섹션
                    SettingsSection(title: "일반") {
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "앱 정보",
                                value: "v\(appVersion)",
                                showArrow: false
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "개인정보 보호정책",
                                showArrow: true
                            ) {
                                showPrivacyPolicy = true
                            }
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "설정 초기화",
                                showArrow: false
                            ) {
                                showResetAlert = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .padding(.bottom, 80) // 바텀 바 공간 확보
            }
            
            // 고정 바텀 네비게이션 바
            SettingsBottomNavigationBar(currentTab: $currentTab, previousTab: $previousTab)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    currentTab = previousTab
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("뒤로")
                    }
                }
            }
        }
        .alert("설정 초기화", isPresented: $showResetAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                settingsManager.resetToDefaults()
            }
        } message: {
            Text("모든 설정을 기본값으로 초기화하시겠습니까?")
        }
        .alert("캐시 삭제", isPresented: $showClearCacheAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                ThumbnailCache.shared.clearCache()
                updateCacheInfo()
            }
        } message: {
            Text("모든 썸네일 캐시가 삭제됩니다. 사진은 삭제되지 않습니다.")
        }
        .alert("이메일 주소 복사됨", isPresented: $showEmailCopiedAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("\(supportEmail)\n\n클립보드에 복사되었습니다.")
        }
        .onAppear {
            // 캐시 정보 로드
            updateCacheInfo()
        }
        .fullScreenCover(isPresented: $showOnboardingAgain) {
            OnboardingView(isFirstLaunch: $showOnboardingAgain)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showOnboarding() {
        showOnboardingAgain = true
    }
    
    private func updateCacheInfo() {
        cacheInfo = ThumbnailCache.shared.cacheInfo()
    }
    
    private func clearThumbnailCache() {
        showClearCacheAlert = true
    }
    
    private func copyEmailToClipboard() {
        // 클립보드에 이메일 복사
        UIPasteboard.general.string = supportEmail
        
        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // 알림 표시
        showEmailCopiedAlert = true
    }
}

// MARK: - 기존 컴포넌트들 제거하고 필요한 것만 유지

// 설정 섹션
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            
            content
                .background(Color(red: 0.15, green: 0.15, blue: 0.16))
                .cornerRadius(12)
        }
    }
}

// 설정 행
struct SettingsRow: View {
    let title: String
    var value: String? = nil
    var showArrow: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .disabled(action == nil && value != nil)
    }
}

// 캐시 정보 행
struct CacheInfoRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("썸네일 캐시")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            let info = ThumbnailCache.shared.cacheInfo()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("메모리:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("\(info.memoryLimit)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("디스크:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("\(info.diskCount)개 파일 (\(info.diskSize))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// Settings 바텀 네비게이션 바
struct SettingsBottomNavigationBar: View {
    @Binding var currentTab: ContentView.Tab
    @Binding var previousTab: ContentView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            BottomNavButton(
                icon: "moon.fill",
                title: "조용한 모드"
            ) {
                previousTab = currentTab
                currentTab = .fakeMode
            }
            
            BottomNavButton(
                icon: "photo.fill",
                title: "갤러리"
            ) {
                previousTab = currentTab
                currentTab = .gallery
            }
            
            BottomNavButton(
                icon: "gearshape.fill",
                title: "설정",
                isActive: true
            ) {
                // 이미 설정에 있음
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
    SettingsView(currentTab: .constant(.settings), previousTab: .constant(.fakeMode))
}
