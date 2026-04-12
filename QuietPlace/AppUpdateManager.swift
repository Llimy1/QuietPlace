//
//  AppUpdateManager.swift
//  QuietPlace
//
//  Created by Codex on 4/9/26.
//

import Foundation
import UIKit
import Combine

@MainActor
final class AppUpdateManager: ObservableObject {
    @Published private(set) var availableUpdate: AvailableAppUpdate?

    private var isCheckingForUpdate = false
    private var lastCheckDate: Date?

    func checkForUpdateIfNeeded() async {
        if AppConstants.Debug.forceUpdatePrompt {
            showDebugUpdatePrompt()
            return
        }

        guard !isCheckingForUpdate else { return }

        if let lastCheckDate,
           Date().timeIntervalSince(lastCheckDate) < AppConstants.Timing.appUpdateCheckInterval {
            return
        }

        isCheckingForUpdate = true
        lastCheckDate = Date()
        defer { isCheckingForUpdate = false }

        guard let currentVersion = currentAppVersion else { return }

        do {
            guard let lookupResult = try await fetchLatestStoreResult() else { return }
            guard isVersion(lookupResult.version, newerThan: currentVersion) else { return }
            guard skippedVersion != lookupResult.version else { return }

            let appStoreURL = URL(string: lookupResult.trackViewURL) ?? fallbackAppStoreURL
            guard let appStoreURL else { return }

            availableUpdate = AvailableAppUpdate(
                version: lookupResult.version,
                appStoreURL: appStoreURL
            )
        } catch {
            debugPrint("⚠️ Failed to check App Store version: \(error.localizedDescription)")
        }
    }

    func dismissUpdatePrompt() {
        if AppConstants.Debug.forceUpdatePrompt {
            availableUpdate = nil
            return
        }

        guard let version = availableUpdate?.version else {
            availableUpdate = nil
            return
        }

        UserDefaults.standard.set(version, forKey: AppConstants.UserDefaultsKeys.skippedAppStoreVersion)
        availableUpdate = nil
    }

    func openAppStoreForUpdate() {
        guard let update = availableUpdate else { return }

        if !AppConstants.Debug.forceUpdatePrompt {
            UserDefaults.standard.set(update.version, forKey: AppConstants.UserDefaultsKeys.skippedAppStoreVersion)
        }
        availableUpdate = nil
        UIApplication.shared.open(update.appStoreURL)
    }

    private func showDebugUpdatePrompt() {
        guard let appStoreURL = fallbackAppStoreURL else { return }

        availableUpdate = AvailableAppUpdate(
            version: AppConstants.Debug.forcedUpdateVersion,
            appStoreURL: appStoreURL
        )
    }

    private var currentAppVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private var fallbackAppStoreURL: URL? {
        URL(string: AppConstants.AppInfo.appStoreURL)
    }

    private var skippedVersion: String? {
        UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.skippedAppStoreVersion)
    }

    private func fetchLatestStoreResult() async throws -> LookupResult? {
        for requestURL in lookupRequestURLs {
            let (data, response) = try await URLSession.shared.data(from: requestURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                continue
            }

            let lookupResponse = try JSONDecoder().decode(LookupResponse.self, from: data)
            if let result = lookupResponse.results.first {
                return result
            }
        }

        return nil
    }

    private var lookupRequestURLs: [URL] {
        var urls: [URL] = []

        if let appIDLookupURL = makeLookupURL(
            queryItems: [
                URLQueryItem(name: "id", value: AppConstants.AppInfo.appStoreID),
                URLQueryItem(name: "country", value: AppConstants.AppInfo.appStoreCountryCode)
            ]
        ) {
            urls.append(appIDLookupURL)
        }

        if let bundleID = Bundle.main.bundleIdentifier,
           let bundleLookupURL = makeLookupURL(
                queryItems: [
                    URLQueryItem(name: "bundleId", value: bundleID),
                    URLQueryItem(name: "country", value: AppConstants.AppInfo.appStoreCountryCode)
                ]
           ) {
            urls.append(bundleLookupURL)
        }

        if let fallbackLookupURL = makeLookupURL(
            queryItems: [
                URLQueryItem(name: "id", value: AppConstants.AppInfo.appStoreID)
            ]
        ) {
            urls.append(fallbackLookupURL)
        }

        return urls
    }

    private func makeLookupURL(queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = queryItems
        return components?.url
    }

    private func isVersion(_ latestVersion: String, newerThan currentVersion: String) -> Bool {
        latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}

extension AppUpdateManager {
    struct AvailableAppUpdate: Identifiable, Equatable {
        let version: String
        let appStoreURL: URL

        var id: String { version }
    }
}

private extension AppUpdateManager {
    struct LookupResponse: Decodable {
        let results: [LookupResult]
    }

    struct LookupResult: Decodable {
        let version: String
        let trackViewURL: String

        private enum CodingKeys: String, CodingKey {
            case version
            case trackViewURL = "trackViewUrl"
        }
    }
}
