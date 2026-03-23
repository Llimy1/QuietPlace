//
//  ATTManager.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/23/26.
//

import AppTrackingTransparency
import Foundation

@MainActor
class ATTManager {
    static let shared = ATTManager()
    
    private init() {}
    
    /// ATT 권한 요청 (앱 활성화 후 호출)
    func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        let status = ATTrackingManager.trackingAuthorizationStatus
        
        if status == .notDetermined {
            let newStatus = await ATTrackingManager.requestTrackingAuthorization()
            #if DEBUG
            print("📊 ATT Authorization: \(newStatus.rawValue)")
            #endif
            return newStatus
        }
        
        #if DEBUG
        print("📊 ATT Status: \(status.rawValue)")
        #endif
        return status
    }
}
