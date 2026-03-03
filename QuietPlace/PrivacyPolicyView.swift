//
//  PrivacyPolicyView.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/28/26.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 헤더
                VStack(alignment: .leading, spacing: 12) {
                    Text("개인정보 보호정책")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("최종 업데이트: 2026년 2월 28일")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // 소개
                PolicySection(
                    title: "소개",
                    content: """
                    QuietPlace("본 앱")는 사용자의 개인정보 보호를 최우선으로 생각합니다. \
                    본 앱은 도서관, 강의실, 전시회, 세미나 등 조용한 환경에서 \
                    셔터음 없이 메모나 자료를 촬영할 수 있도록 돕습니다. \
                    
                    본 개인정보 보호정책은 본 앱이 어떤 정보를 수집하고, 어떻게 사용하며, \
                    어떻게 보호하는지 설명합니다.
                    
                    ⚠️ 중요: 본 앱은 합법적인 용도로만 사용되어야 합니다. \
                    타인의 사생활을 침해하거나 불법적인 촬영에 사용하는 것은 금지되어 있으며, \
                    관련 법률에 따라 처벌받을 수 있습니다.
                    """
                )
                
                // 1. 수집하는 정보
                PolicySection(
                    title: "1. 수집하는 정보",
                    content: """
                    본 앱은 다음과 같은 방식으로 정보를 처리합니다:
                    
                    • 사진 데이터: 앱 내에서 촬영한 사진은 기기의 앱 전용 저장소에 로컬로 저장됩니다.
                    • 설정 정보: 프리뷰 크기 등 앱 설정은 기기에 로컬로 저장됩니다.
                    
                    중요: 본 앱은 어떠한 개인정보도 외부 서버로 전송하지 않습니다.
                    """
                )
                
                // 2. 정보 사용 방법
                PolicySection(
                    title: "2. 정보 사용 방법",
                    content: """
                    수집된 정보는 다음과 같은 목적으로만 사용됩니다:
                    
                    • 사진 데이터: 앱 내 갤러리에서 사용자가 촬영한 사진을 보여주기 위해서만 사용됩니다.
                    • 설정 정보: 사용자 경험을 개선하고 앱 기능을 제공하기 위해 사용됩니다.
                    
                    모든 데이터는 사용자의 기기에만 저장되며, 절대로 제3자와 공유되지 않습니다.
                    """
                )
                
                // 3. 데이터 저장 및 보안
                PolicySection(
                    title: "3. 데이터 저장 및 보안",
                    content: """
                    • 로컬 저장: 모든 사진과 설정은 사용자의 기기에만 저장됩니다.
                    • 앱 샌드박스: iOS의 앱 샌드박스 보안 메커니즘을 통해 다른 앱이 데이터에 접근할 수 없습니다.
                    • 서버 전송 없음: 본 앱은 인터넷 연결을 필요로 하지 않으며, 어떠한 데이터도 외부로 전송하지 않습니다.
                    • 암호화: iOS 시스템의 기본 암호화 기능을 활용하여 데이터를 보호합니다.
                    """
                )
                
                // 4. 권한 사용
                PolicySection(
                    title: "4. 권한 사용",
                    content: """
                    본 앱은 다음 권한을 요청합니다:
                    
                    • 카메라: 사진 촬영 기능을 제공하기 위해 필요합니다.
                    • 사진 라이브러리: 촬영한 사진을 사용자의 사진첩으로 내보내기 위해 필요합니다.
                    
                    이러한 권한은 앱의 핵심 기능을 제공하기 위해서만 사용되며, \
                    다른 목적으로는 절대 사용되지 않습니다.
                    
                    본 앱은 학술적 목적, 메모, 자료 수집 등 합법적인 용도로만 사용되어야 합니다. \
                    타인의 동의 없이 사진을 촬영하거나 사생활을 침해하는 행위는 \
                    법적으로 금지되어 있으며, 사용자는 관련 법률을 준수할 책임이 있습니다.
                    """
                )
                
                // 5. 데이터 삭제
                PolicySection(
                    title: "5. 데이터 삭제",
                    content: """
                    사용자는 언제든지 다음과 같은 방법으로 데이터를 삭제할 수 있습니다:
                    
                    • 개별 사진 삭제: 갤러리에서 원하는 사진을 선택하여 삭제할 수 있습니다.
                    • 썸네일 캐시 삭제: 설정 > 저장소 > 썸네일 캐시 삭제를 통해 캐시를 정리할 수 있습니다.
                    • 전체 데이터 삭제: 앱을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.
                    """
                )
                
                // 6. 제3자 서비스
                PolicySection(
                    title: "6. 제3자 서비스",
                    content: """
                    본 앱은 제3자 서비스를 사용하지 않습니다:
                    
                    • 광고 없음: 본 앱은 광고를 표시하지 않습니다.
                    • 분석 도구 없음: 본 앱은 어떠한 분석 도구나 추적 서비스도 사용하지 않습니다.
                    • 외부 SDK 없음: 본 앱은 Apple의 기본 프레임워크만 사용합니다.
                    """
                )
                
                // 7. 어린이 개인정보 보호
                PolicySection(
                    title: "7. 어린이 개인정보 보호",
                    content: """
                    본 앱은 만 13세 미만 어린이로부터 의도적으로 개인정보를 수집하지 않습니다. \
                    본 앱은 어떠한 개인정보도 수집하지 않으므로, 모든 연령대의 사용자가 \
                    안전하게 사용할 수 있습니다.
                    """
                )
                
                // 8. 정책 변경
                PolicySection(
                    title: "8. 정책 변경",
                    content: """
                    본 개인정보 보호정책은 필요에 따라 업데이트될 수 있습니다. \
                    정책이 변경되면 앱 업데이트를 통해 새로운 정책이 적용되며, \
                    상단에 최종 업데이트 날짜가 표시됩니다.
                    """
                )
                
                // 9. 문의
                PolicySection(
                    title: "9. 문의",
                    content: """
                    개인정보 보호정책에 대해 궁금한 점이 있으시면 언제든지 문의해주시기 바랍니다.
                    
                    본 앱은 사용자의 개인정보를 존중하며, 투명하고 안전한 서비스를 제공하기 위해 \
                    최선을 다하고 있습니다.
                    """
                )
                
                // 요약
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                            
                            Text("개인정보 보호 요약")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SummaryRow(icon: "lock.fill", text: "모든 데이터는 기기에만 저장됩니다")
                            SummaryRow(icon: "wifi.slash", text: "인터넷 연결이 필요 없습니다")
                            SummaryRow(icon: "hand.raised.fill", text: "어떠한 데이터도 외부로 전송되지 않습니다")
                            SummaryRow(icon: "eye.slash.fill", text: "광고 및 추적 없음")
                            SummaryRow(icon: "trash.fill", text: "언제든지 데이터를 삭제할 수 있습니다")
                        }
                        .padding(.leading, 8)
                    }
                    .padding(20)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .navigationTitle("개인정보 보호정책")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    dismiss()
                }) {
                    Text("완료")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Policy Section

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(content)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
