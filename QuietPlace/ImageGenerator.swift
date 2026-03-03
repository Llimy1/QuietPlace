//
//  ImageGenerator.swift
//  QuitePlace
//
//  Created by 이민혁 on 2/28/26.
//

import SwiftUI
import UIKit

/// SwiftUI View를 UIImage로 변환하는 유틸리티 (온보딩 및 실제 사용용)
struct ImageGenerator {
    
    // MARK: - View Rendering
    
    /// SwiftUI View를 UIImage로 렌더링
    @MainActor
    static func renderView<V: View>(_ view: V, size: CGSize) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

#Preview("App Icon Preview") {
    VStack(spacing: 30) {
        AppIconView()
            .frame(width: 200, height: 200)
            .cornerRadius(45)
            .shadow(radius: 10)
        
        BrandMark(size: 120)
            .shadow(radius: 10)
        
        Text("QuitePlace")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}

