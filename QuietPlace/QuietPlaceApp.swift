//
//  QuietPlaceApp.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/3/26.
//

import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct QuietPlaceApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasRequestedATT = false
    
    init() {
        // Google Mobile Ads SDK 초기화
        MobileAds.shared.start(completionHandler: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active && !hasRequestedATT {
                        hasRequestedATT = true
                        // 앱이 active 상태가 된 후 ATT 요청 (다른 팝업이 끝난 뒤 호출되도록 딜레이)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            ATTrackingManager.requestTrackingAuthorization { _ in }
                        }
                    }
                }
        }
    }
}
