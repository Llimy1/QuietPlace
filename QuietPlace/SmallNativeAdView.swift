//
//  SmallNativeAdView.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/23/26.
//

import SwiftUI
import GoogleMobileAds
import Combine

// MARK: - Small Native Ad Loader

class SmallNativeAdLoader: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    private var adLoader: AdLoader?
    
    func loadAd() {
        let adLoader = AdLoader(
            adUnitID: AdManager.nativeAdUnitID,
            rootViewController: UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController,
            adTypes: [.native],
            options: nil
        )
        adLoader.delegate = self
        adLoader.load(Request())
        self.adLoader = adLoader
    }
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("❌ Small native ad failed: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - Small Native Ad Bar (한 줄 텍스트 광고)

struct SmallNativeAdBar: View {
    @StateObject private var adLoader = SmallNativeAdLoader()
    
    var body: some View {
        Group {
            if let ad = adLoader.nativeAd {
                SmallNativeAdRepresentable(nativeAd: ad)
                    .frame(height: 30)
            }
        }
        .onAppear {
            adLoader.loadAd()
        }
    }
}

// MARK: - UIViewRepresentable (한 줄 네이티브 광고)

struct SmallNativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd
    
    func makeUIView(context: Context) -> GoogleMobileAds.NativeAdView {
        let adView = GoogleMobileAds.NativeAdView(frame: .zero)
        adView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        
        // AD 라벨
        let adLabel = UILabel()
        adLabel.text = "AD"
        adLabel.font = .systemFont(ofSize: 11, weight: .bold)
        adLabel.textColor = UIColor.systemGray
        
        // Headline 라벨
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 13, weight: .regular)
        headlineLabel.textColor = UIColor.systemGray
        headlineLabel.lineBreakMode = .byTruncatingTail
        
        // 구분선
        let separator = UIView()
        separator.backgroundColor = UIColor.systemGray3
        
        // Auto Layout
        for subview in [separator, adLabel, headlineLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(subview)
        }
        
        NSLayoutConstraint.activate([
            // 상단 구분선
            separator.topAnchor.constraint(equalTo: adView.topAnchor),
            separator.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            
            // AD 라벨
            adLabel.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            adLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            
            // Headline
            headlineLabel.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            headlineLabel.leadingAnchor.constraint(equalTo: adLabel.trailingAnchor, constant: 8),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
        ])
        
        adView.headlineView = headlineLabel
        
        configureAd(adView, with: nativeAd)
        return adView
    }
    
    func updateUIView(_ adView: GoogleMobileAds.NativeAdView, context: Context) {
        configureAd(adView, with: nativeAd)
    }
    
    private func configureAd(_ adView: GoogleMobileAds.NativeAdView, with ad: NativeAd) {
        adView.nativeAd = ad
        (adView.headlineView as? UILabel)?.text = ad.headline
    }
}
