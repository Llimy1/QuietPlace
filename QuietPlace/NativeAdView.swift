//
//  NativeAdView.swift
//  QuietPlace
//
//  Created by 이민혁 on 3/23/26.
//

import SwiftUI
import GoogleMobileAds
import Combine

// MARK: - Native Ad Loader

class NativeAdLoader: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    @Published var isLoading = false
    private var adLoader: AdLoader?
    
    func loadAd() {
        guard !isLoading else { return }
        isLoading = true
        
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
        self.isLoading = false
        #if DEBUG
        print("✅ Native ad loaded")
        #endif
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        self.isLoading = false
        #if DEBUG
        print("❌ Native ad failed: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - Native Ad Card (SwiftUI)

struct NativeAdCardView: View {
    @StateObject private var adLoader = NativeAdLoader()
    
    var body: some View {
        Group {
            if let nativeAd = adLoader.nativeAd {
                NativeAdRepresentable(nativeAd: nativeAd)
                    .frame(height: AppConstants.Ads.nativeAdHeight)
            } else {
                Color.clear
                    .frame(height: adLoader.isLoading ? AppConstants.Ads.nativeAdHeight : 0)
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            adLoader.loadAd()
        }
    }
}

// MARK: - UIViewRepresentable for NativeAdView

struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd
    
    func makeUIView(context: Context) -> GoogleMobileAds.NativeAdView {
        let adView = buildNativeAdView()
        configureAdView(adView, with: nativeAd)
        return adView
    }
    
    func updateUIView(_ nativeAdView: GoogleMobileAds.NativeAdView, context: Context) {
        configureAdView(nativeAdView, with: nativeAd)
    }
    
    private func buildNativeAdView() -> GoogleMobileAds.NativeAdView {
        let adView = GoogleMobileAds.NativeAdView(frame: .zero)
        adView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
        adView.layer.cornerRadius = 12
        adView.clipsToBounds = true
        
        // Media view
        let mediaView = MediaView()
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        headlineLabel.textColor = .white
        headlineLabel.numberOfLines = 2
        
        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = UIColor.lightGray
        bodyLabel.numberOfLines = 2
        
        // Icon
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 6
        iconView.clipsToBounds = true
        
        // CTA button
        let ctaButton = UIButton(type: .system)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = UIColor.systemBlue
        ctaButton.layer.cornerRadius = 8
        ctaButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        ctaButton.isUserInteractionEnabled = false
        
        // "Ad" label
        let adLabel = UILabel()
        adLabel.text = "Ad"
        adLabel.font = .systemFont(ofSize: 10, weight: .bold)
        adLabel.textColor = .white
        adLabel.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.8)
        adLabel.textAlignment = .center
        adLabel.layer.cornerRadius = 4
        adLabel.clipsToBounds = true
        
        // Auto Layout
        for subview in [mediaView, iconView, headlineLabel, bodyLabel, ctaButton, adLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(subview)
        }
        
        NSLayoutConstraint.activate([
            // Media: top, full width, 150pt
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            mediaView.heightAnchor.constraint(equalToConstant: 150),
            
            // Ad badge
            adLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
            adLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
            adLabel.widthAnchor.constraint(equalToConstant: 24),
            adLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // Icon
            iconView.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),
            iconView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            // Headline
            headlineLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            
            // Body
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            
            // CTA button
            ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            ctaButton.heightAnchor.constraint(equalToConstant: 32),
        ])
        
        // Register asset views
        adView.headlineView = headlineLabel
        adView.bodyView = bodyLabel
        adView.mediaView = mediaView
        adView.iconView = iconView
        adView.callToActionView = ctaButton
        
        return adView
    }
    
    private func configureAdView(_ adView: GoogleMobileAds.NativeAdView, with ad: NativeAd) {
        adView.nativeAd = ad
        
        (adView.headlineView as? UILabel)?.text = ad.headline
        (adView.bodyView as? UILabel)?.text = ad.body
        (adView.iconView as? UIImageView)?.image = ad.icon?.image
        adView.mediaView?.mediaContent = ad.mediaContent
        
        if let cta = ad.callToAction {
            (adView.callToActionView as? UIButton)?.setTitle(cta, for: .normal)
            adView.callToActionView?.isHidden = false
        } else {
            adView.callToActionView?.isHidden = true
        }
    }
}
