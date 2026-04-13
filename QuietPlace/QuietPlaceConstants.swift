//
//  Constants.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/3/26.
//

import Foundation
import CoreGraphics

/// 앱 전체에서 사용하는 상수들
enum AppConstants {
    
    // MARK: - App Info
    
    enum AppInfo {
        static let name = "QuietPlace"
        static let supportEmail = "llimy.mh@gmail.com"
        static let privacyPolicyURL = "https://llimy1.github.io/QuietPlace/privacy.html"
        static let appStoreID = "6761469819"
        static let appStoreCountryCode = "kr"
        static let appStoreURL = "https://apps.apple.com/app/id6761469819"
    }

    // MARK: - Debug

    enum Debug {
        #if DEBUG
        static let forceUpdatePrompt = false
        static let forcedUpdateVersion = "9.9.9"
        #else
        static let forceUpdatePrompt = false
        static let forcedUpdateVersion = ""
        #endif
    }
    
    // MARK: - Timing
    
    enum Timing {
        /// 탭 감지 시간 간격 (초)
        static let tapDetectionInterval: TimeInterval = 0.4
        
        /// 시계 업데이트 간격 (초)
        static let clockUpdateInterval: TimeInterval = 1.0
        
        /// 카메라 프레임 대기 시간 (초)
        static let cameraFrameWaitTimeout: TimeInterval = 1.0
        
        /// 사진 촬영 타임아웃 (초)
        static let photoCaptureTimeout: TimeInterval = 3.0

        /// 앱 업데이트 확인 전 대기 시간 (초)
        static let appUpdatePromptDelay: TimeInterval = 2.5

        /// 앱 업데이트 재확인 최소 간격 (초)
        static let appUpdateCheckInterval: TimeInterval = 60 * 60 * 6

        /// 디버그 강제 업데이트 카드 표시 대기 시간 (초)
        static let debugForcedUpdatePromptDelay: TimeInterval = 0.8
    }
    
    // MARK: - UI
    
    enum UI {
        /// 프리뷰 최소 크기 비율
        static let previewMinScale: CGFloat = 0.20
        
        /// 프리뷰 최대 크기 비율
        static let previewMaxScale: CGFloat = 0.80
        
        /// 프리뷰 기본 크기 비율
        static let previewDefaultScale: CGFloat = 0.30
        
        /// 촬영 버튼 표시 임계값
        static let captureButtonThreshold: CGFloat = 0.60
        
        /// 하단 네비게이션 바 높이
        static let bottomNavHeight: CGFloat = 70
        
        /// 애니메이션 기본 지속 시간
        static let defaultAnimationDuration: TimeInterval = 0.3
    }
    
    // MARK: - Storage
    
    enum Storage {
        /// 사진 저장 폴더명
        static let photosFolderName = "CapturedPhotos"
        
        /// 썸네일 캐시 메모리 한도 (bytes)
        static let thumbnailMemoryLimit = 50 * 1024 * 1024 // 50MB
        
        /// 썸네일 캐시 디스크 한도 (bytes)
        static let thumbnailDiskLimit = 200 * 1024 * 1024 // 200MB
    }
    
    // MARK: - Camera
    
    enum Camera {
        /// 최소 줌 배율
        static let minimumZoomFactor: CGFloat = 1.0

        /// 최대 줌 배율 (품질 저하 방지를 위해 앱에서 제한)
        static let maximumZoomFactor: CGFloat = 5.0

        /// 프레임 대기 최대 반복 횟수
        static let maxFrameWaitAttempts = 20
        
        /// 프레임 대기 간격 (초)
        static let frameWaitInterval: TimeInterval = 0.05
        
        /// JPEG 압축 품질 (0.0 ~ 1.0)
        static let jpegCompressionQuality: CGFloat = 0.9

        /// 줌 인디케이터 표시 유지 시간
        static let zoomIndicatorDismissDelay: TimeInterval = 1.2

        /// 셔터 시점에 평가할 최근 프레임 개수
        static let recentFrameBufferSize: Int = 5

        /// 저전력 모드에서 선명도 평가 프레임 수(지연 절감)
        static let lowPowerSharpnessSampleCount: Int = 3

        /// 선명도 평가 시 기본 다운샘플 비율
        static let defaultSharpnessDownsampleScale: CGFloat = 0.25

        /// 저전력 모드에서 선명도 평가 다운샘플 비율
        static let lowPowerSharpnessDownsampleScale: CGFloat = 0.18

        /// 카메라 전환 시 프리뷰를 가려둘 최소 시간
        static let cameraSwitchOverlayHoldDuration: TimeInterval = 0.45
    }
    
    // MARK: - UserDefaults Keys
    
    enum UserDefaultsKeys {
        static let isFirstLaunch = "isFirstLaunch"
        static let previewScale = "previewScale"
        static let tapToCapture = "tapToCapture"
        static let skippedAppStoreVersion = "skippedAppStoreVersion"
    }
    
    // MARK: - Ads
    
    enum Ads {
        /// 배너 광고 높이
        static let bannerHeight: CGFloat = 32
        /// 네이티브 광고 높이
        static let nativeAdHeight: CGFloat = 280
        /// 네이티브 광고 표시 빈도 (N개 날짜 섹션마다)
        static let nativeAdFrequency: Int = 1
    }
    
}
