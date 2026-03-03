//
//  Debug.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/3/26.
//

import Foundation

/// 디버그 모드에서만 출력하는 print 함수
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    #endif
}

/// 에러 로깅 (프로덕션에서도 최소한의 로그)
func logError(_ message: String, error: Error? = nil) {
    #if DEBUG
    if let error = error {
        Swift.print("❌ \(message): \(error.localizedDescription)")
    } else {
        Swift.print("❌ \(message)")
    }
    #else
    // 프로덕션에서는 로깅 서비스나 Analytics로 전송 가능
    // 지금은 조용히 무시
    #endif
}

/// 성능 측정 (디버그 전용)
func measureTime(_ label: String, block: () -> Void) {
    #if DEBUG
    let start = CFAbsoluteTimeGetCurrent()
    block()
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    Swift.print("⏱️ \(label): \(String(format: "%.3f", elapsed))s")
    #else
    block()
    #endif
}
