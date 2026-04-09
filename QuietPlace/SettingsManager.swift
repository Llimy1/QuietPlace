//
//  SettingsManager.swift
//  QuietPlace
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
    
    // 위장 모드 (조용한 모드) 활성화 여부
    @Published var isDisguiseMode: Bool {
        didSet {
            UserDefaults.standard.set(isDisguiseMode, forKey: "isDisguiseMode")
            debugPrint("✅ Disguise mode: \(isDisguiseMode ? "ON" : "OFF")")
        }
    }
    
    // 손떨림 방지 활성화 여부
    @Published var isStabilizationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isStabilizationEnabled, forKey: "isStabilizationEnabled")
            debugPrint("✅ Stabilization: \(isStabilizationEnabled ? "ON" : "OFF")")
        }
    }

    // 구도 그리드 표시 여부
    @Published var isGridEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isGridEnabled, forKey: "isGridEnabled")
            debugPrint("✅ Grid: \(isGridEnabled ? "ON" : "OFF")")
        }
    }
    
    // 위장 모드 오버레이 불투명도 (30% ~ 80%)
    @Published var disguiseOverlayOpacity: Double {
        didSet {
            let clampedValue = min(max(disguiseOverlayOpacity, 0.30), 0.80)
            if clampedValue != disguiseOverlayOpacity {
                disguiseOverlayOpacity = clampedValue
                return
            }
            UserDefaults.standard.set(disguiseOverlayOpacity, forKey: "disguiseOverlayOpacity")
            debugPrint("✅ Disguise overlay opacity saved: \(Int(disguiseOverlayOpacity * 100))%")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // UserDefaults에서 저장된 값 불러오기 (기본값 80%)
        let savedScale = UserDefaults.standard.object(forKey: "previewScale") as? CGFloat ?? 0.80
        self.previewScale = min(max(savedScale, 0.20), 0.80)
        
        // 탭 촬영 기능 (기본값: 활성화)
        self.tapToCapture = UserDefaults.standard.object(forKey: "tapToCapture") as? Bool ?? true
        
        // 위장 모드 (기본값: 비활성화)
        self.isDisguiseMode = UserDefaults.standard.object(forKey: "isDisguiseMode") as? Bool ?? false
        
        // 손떨림 방지 (기본값: 활성화)
        self.isStabilizationEnabled = UserDefaults.standard.object(forKey: "isStabilizationEnabled") as? Bool ?? true

        // 구도 그리드 (기본값: 활성화)
        self.isGridEnabled = UserDefaults.standard.object(forKey: "isGridEnabled") as? Bool ?? true
        
        // 위장 모드 오버레이 불투명도 (기본값: 90%)
        let savedOpacity = UserDefaults.standard.object(forKey: "disguiseOverlayOpacity") as? Double ?? 0.90
        self.disguiseOverlayOpacity = min(max(savedOpacity, 0.30), 0.80)
        
        debugPrint("✅ Settings loaded - Preview scale: \(Int(previewScale * 100))%, Tap to capture: \(tapToCapture ? "ON" : "OFF"), Disguise: \(isDisguiseMode ? "ON" : "OFF"), Overlay: \(Int(disguiseOverlayOpacity * 100))%")
    }
    
    // MARK: - Reset Settings
    
    func resetToDefaults() {
        previewScale = 0.80
        tapToCapture = true
        isDisguiseMode = false
        disguiseOverlayOpacity = 0.80
        isStabilizationEnabled = true
        isGridEnabled = true
        debugPrint("✅ Settings reset to defaults")
    }
}


