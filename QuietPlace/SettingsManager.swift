//
//  SettingsManager.swift
//  QuitePlace
//
//  Created by 이민혁 on 2/23/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // 프리뷰 크기 설정 (20% ~ 80%)
    @Published var previewScale: CGFloat {
        didSet {
            // 범위 제한
            let clampedValue = min(max(previewScale, 0.20), 0.80)
            if clampedValue != previewScale {
                previewScale = clampedValue
                return
            }
            UserDefaults.standard.set(previewScale, forKey: "previewScale")
            debugPrint("✅ Preview scale saved: \(Int(previewScale * 100))%")
        }
    }
    
    // 탭으로 촬영 기능 활성화 여부
    @Published var tapToCapture: Bool {
        didSet {
            UserDefaults.standard.set(tapToCapture, forKey: "tapToCapture")
            debugPrint("✅ Tap to capture: \(tapToCapture ? "ON" : "OFF")")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // UserDefaults에서 저장된 값 불러오기 (기본값 30%)
        let savedScale = UserDefaults.standard.object(forKey: "previewScale") as? CGFloat ?? 0.30
        self.previewScale = min(max(savedScale, 0.20), 0.80)
        
        // 탭 촬영 기능 (기본값: 활성화)
        self.tapToCapture = UserDefaults.standard.object(forKey: "tapToCapture") as? Bool ?? true
        
        debugPrint("✅ Settings loaded - Preview scale: \(Int(previewScale * 100))%, Tap to capture: \(tapToCapture ? "ON" : "OFF")")
    }
    
    // MARK: - Reset Settings
    
    func resetToDefaults() {
        previewScale = 0.30  // 30%로 리셋
        tapToCapture = true  // 탭 촬영 활성화
        debugPrint("✅ Settings reset to defaults")
    }
}



