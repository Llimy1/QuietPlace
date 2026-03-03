//
//  BrandComponents.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/28/26.
//

import SwiftUI

// MARK: - 브랜드 컬러

struct BrandPalette {
    static let primaryBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    static let secondaryPurple = Color(red: 0.6, green: 0.3, blue: 0.9)
    static let accentCyan = Color(red: 0.3, green: 0.8, blue: 1.0)
    
    static let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let lightBackground = Color.white
    
    static let gradientLight = LinearGradient(
        colors: [primaryBlue, secondaryPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientDark = LinearGradient(
        colors: [primaryBlue.opacity(0.8), secondaryPurple.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 렌즈 로고

/// 카메라 렌즈를 모티브로 한 앱 아이콘 로고
struct LensLogo: View {
    let size: CGFloat
    let isDark: Bool
    
    var body: some View {
        ZStack {
            // 외곽 링
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            BrandPalette.primaryBlue,
                            BrandPalette.accentCyan
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.08
                )
                .frame(width: size, height: size)
            
            // 중간 링
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            BrandPalette.secondaryPurple.opacity(0.6),
                            BrandPalette.primaryBlue.opacity(0.6)
                        ],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    ),
                    lineWidth: size * 0.06
                )
                .frame(width: size * 0.7, height: size * 0.7)
            
            // 중앙 원
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandPalette.accentCyan.opacity(0.3),
                            BrandPalette.primaryBlue.opacity(0.5),
                            BrandPalette.secondaryPurple.opacity(0.7)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)
            
            // 중앙 하이라이트
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(isDark ? 0.3 : 0.5),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.08, y: -size * 0.08)
            
            // 렌즈 반사 효과
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.6, height: size * 0.3)
                .offset(y: -size * 0.15)
        }
    }
}

// MARK: - 브랜드 타이틀

/// "QuitePlace" 타이틀
struct BrandTitle: View {
    let isDark: Bool
    var fontSize: CGFloat = 48
    
    var body: some View {
        HStack(spacing: 2) {
            Text("Quite")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            BrandPalette.primaryBlue,
                            BrandPalette.accentCyan
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Place")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            BrandPalette.secondaryPurple,
                            BrandPalette.primaryBlue
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: - 곡선 스우시 (Swoosh)

/// 브랜드 타이틀 아래 곡선 장식
struct Swoosh: View {
    let isDark: Bool
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            
            let startPoint = CGPoint(x: 0, y: size.height * 0.5)
            path.move(to: startPoint)
            
            let controlPoint1 = CGPoint(x: size.width * 0.3, y: size.height * 0.2)
            let controlPoint2 = CGPoint(x: size.width * 0.7, y: size.height * 0.8)
            let endPoint = CGPoint(x: size.width, y: size.height * 0.5)
            
            path.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
            
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        BrandPalette.primaryBlue.opacity(0.6),
                        BrandPalette.secondaryPurple.opacity(0.6),
                        BrandPalette.accentCyan.opacity(0.6)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                lineWidth: 3
            )
        }
    }
}

// MARK: - 앱 아이콘용 로고

/// Assets에 저장할 앱 아이콘 (정사각형)
struct AppIconView: View {
    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [
                    BrandPalette.darkBackground,
                    Color(red: 0.08, green: 0.08, blue: 0.1),
                    BrandPalette.darkBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 렌즈 로고
            LensLogo(size: 700, isDark: true)
                .shadow(color: BrandPalette.primaryBlue.opacity(0.5), radius: 30, x: 0, y: 0)
                .shadow(color: BrandPalette.secondaryPurple.opacity(0.3), radius: 50, x: 0, y: 0)
        }
    }
}

// MARK: - 런치 스크린 이미지

/// 런치 스크린용 이미지
struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // 배경
            BrandPalette.darkBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 렌즈 로고
                LensLogo(size: 180, isDark: true)
                    .shadow(color: BrandPalette.primaryBlue.opacity(0.5), radius: 30, x: 0, y: 0)
                
                // 브랜드 타이틀
                BrandTitle(isDark: true, fontSize: 52)
                
                // 스우시
                Swoosh(isDark: true)
                    .frame(height: 30)
                    .padding(.horizontal, 100)
                
                // 서브타이틀
                Text("조용히, 안전하게")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - 튜토리얼용 작은 아이콘

/// 튜토리얼이나 설정에서 사용할 작은 앱 아이콘
struct BrandMark: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // 배경
            RoundedRectangle(cornerRadius: size * 0.225)
                .fill(
                    LinearGradient(
                        colors: [
                            BrandPalette.darkBackground,
                            Color(red: 0.08, green: 0.08, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 렌즈 로고
            LensLogo(size: size * 0.7, isDark: true)
                .shadow(color: BrandPalette.primaryBlue.opacity(0.3), radius: size * 0.1, x: 0, y: 0)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 프리뷰

#Preview("App Icon") {
    AppIconView()
        .frame(width: 1024, height: 1024)
}

#Preview("Launch Screen") {
    LaunchScreenView()
}

#Preview("Brand Mark") {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 30) {
            BrandMark(size: 60)
            BrandMark(size: 100)
            BrandMark(size: 150)
        }
    }
}

#Preview("Lens Logo") {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            LensLogo(size: 100, isDark: true)
            LensLogo(size: 150, isDark: true)
            LensLogo(size: 200, isDark: true)
        }
    }
}

#Preview("Brand Title") {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            BrandTitle(isDark: true, fontSize: 32)
            BrandTitle(isDark: true, fontSize: 48)
            BrandTitle(isDark: true, fontSize: 64)
        }
    }
}
