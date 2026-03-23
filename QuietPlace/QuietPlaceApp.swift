//
//  QuietPlaceApp.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/3/26.
//

import SwiftUI
import GoogleMobileAds

@main
struct QuietPlaceApp: App {
    
    init() {
        // Google Mobile Ads SDK 초기화
        MobileAds.shared.start(completionHandler: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 앱 UI가 보인 후 ATT 권한 요청
                    try? await Task.sleep(for: .seconds(1.5))
                    _ = await ATTManager.shared.requestTrackingAuthorization()
                }
        }
    }
}
