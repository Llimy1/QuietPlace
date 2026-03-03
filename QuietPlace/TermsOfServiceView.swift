//
//  TermsOfServiceView.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/3/26.
//

import SwiftUI
import WebKit

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        ZStack {
            // WebView
            WebView(
                url: URL(string: "https://llimy1.github.io/QuietPlace/terms.html")!,
                isLoading: $isLoading,
                loadError: $loadError
            )
            .ignoresSafeArea(edges: .bottom)
            
            // 로딩 인디케이터
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("이용약관 로딩 중...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            }
            
            // 에러 화면
            if loadError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("이용약관을 불러올 수 없습니다")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("인터넷 연결을 확인해주세요")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        loadError = false
                        isLoading = true
                    }) {
                        Text("다시 시도")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            }
        }
        .navigationTitle("이용약관")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("완료") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}

// WebView Wrapper
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.loadError = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = true
            debugPrint("❌ WebView failed to load: \(error)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = true
            debugPrint("❌ WebView failed provisional navigation: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
