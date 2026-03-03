//
//  SplashOverlay.swift
//  QuitePlace
//
//  Created by Assistant on 2/28/26.
//

import SwiftUI

struct SplashOverlay: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            BrandPalette.darkBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                BrandMark(size: 120)
                    .scaleEffect(appear ? 1.0 : 0.9)
                    .opacity(appear ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.9), value: appear)

                Text("QuitePlace")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(appear ? 1.0 : 0.0)
                    .offset(y: appear ? 0 : 8)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appear)
            }
        }
        .onAppear { appear = true }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    SplashOverlay()
}
#endif
