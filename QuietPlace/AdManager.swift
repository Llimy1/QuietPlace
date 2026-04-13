//
//  AdManager.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/23/26.
//

import Foundation
import GoogleMobileAds
import Combine

@MainActor
class AdManager: ObservableObject {
    static let shared = AdManager()
    
    // MARK: - Ad Unit IDs
    
    #if DEBUG
    // 테스트 광고 ID (Google 공식 테스트 ID)
    nonisolated static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    nonisolated static let nativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"
    #else
    // 프로덕션 광고 ID
    nonisolated static let bannerAdUnitID = "ca-app-pub-6697014301380374/5978280322"
    nonisolated static let nativeAdUnitID = "ca-app-pub-6697014301380374/9346679690"
    #endif
    
    // MARK: - Initialization
    
    private init() {
        #if DEBUG
        print("✅ AdManager initialized")
        #endif
    }
}
