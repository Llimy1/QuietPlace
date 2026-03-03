//
//  SplashView.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/3/26.
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // 배경색 - 앱 아이콘과 동일한 그라디언트
            LinearGradient(
                colors: [
                    Color(hex: "1A237E"), // Indigo 900
                    Color(hex: "4A148C")  // Purple 900
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 앱 아이콘
                appIconView
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(opacity)
                
                // 앱 이름
                Text("Quiet Place")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.white) // 어두운 배경이므로 흰색 텍스트
                    .opacity(opacity)
            }
        }
        .onAppear {
            // 애니메이션
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1.0
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - App Icon View
    
    @ViewBuilder
    private var appIconView: some View {
        // 1. 먼저 별도로 추가한 AppIconImage 이미지 확인
        if let _ = UIImage(named: "AppIconImage") {
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(26.4)
        }
        // 2. 시스템에서 앱 아이콘 가져오기 (iOS의 실제 앱 아이콘)
        else if let appIcon = getAppIcon() {
            Image(uiImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(26.4)
        }
        // 3. 둘 다 없으면 대체 아이콘 표시
        else {
            ZStack {
                RoundedRectangle(cornerRadius: 26.4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.3, blue: 0.35),
                                Color(red: 0.2, green: 0.2, blue: 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: "camera.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
    
    // MARK: - Get App Icon
    
    /// 시스템에서 현재 앱 아이콘 가져오기
    private func getAppIcon() -> UIImage? {
        // Info.plist에서 앱 아이콘 이름 가져오기
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
              let lastIcon = iconFiles.last else {
            return nil
        }
        
        return UIImage(named: lastIcon)
    }
}

#Preview {
    SplashView()
}
// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

