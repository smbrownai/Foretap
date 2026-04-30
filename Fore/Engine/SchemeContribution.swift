//
//  SchemeContribution.swift
//  Fore
//
//  Phase C: when an app the user added launches successfully (the
//  scheme actually opens something), submit (bundleId, scheme, name)
//  to the community backend so other users with the same app benefit.
//
//  Privacy:
//  - We submit only schemes the user typed in themselves AND that we
//    just verified launches. No browsing history; no app inventory.
//  - The "anonymous device ID" sent is a SHA-256 hash of a UUID
//    generated locally on first launch and stored in UserDefaults.
//    We only use it server-side to count "how many distinct devices
//    confirmed this pair," never to identify the user.
//  - Gated by AppPreferenceKey.contributeSchemes (default ON).
//    Settings → Help build the catalog can flip it off at any time.
//

import CryptoKit
import Foundation

enum SchemeContribution {

    /// Submit a verified (bundleId, scheme) pair. No-op when:
    ///   - the contribution toggle is off
    ///   - the backend host hasn't been configured
    ///   - bundleId is nil (custom app the user typed without picker
    ///     context — we don't know which App Store row it maps to)
    ///   - we've already submitted this exact pair from this install
    static func submitIfEligible(bundleId: String?, scheme: String, name: String) {
        guard let bundleId, !bundleId.isEmpty,
              !scheme.isEmpty,
              BackendConfig.isConfigured,
              isContributeEnabled() else { return }

        let key = "\(bundleId)|\(scheme)"
        var submitted = submittedPairs()
        guard !submitted.contains(key) else { return }

        Task.detached(priority: .background) {
            let ok = await postSubmission(bundleId: bundleId, scheme: scheme, name: name)
            if ok {
                await MainActor.run {
                    submitted.insert(key)
                    UserDefaults.standard.set(Array(submitted), forKey: "fore.contrib.submittedPairs")
                }
            }
        }
    }

    // ---- HTTP -----------------------------------------------------------

    private static func postSubmission(bundleId: String, scheme: String, name: String) async -> Bool {
        var req = URLRequest(url: BackendConfig.submissionsEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10

        let body: [String: Any] = [
            "bundleId": bundleId,
            "scheme": scheme,
            "name": name,
            "anonymousDeviceID": deviceIDHash(),
            "clientVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return false }
        req.httpBody = payload

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }

    // ---- Device ID + opt-in --------------------------------------------

    /// SHA-256 of a per-install UUID. Stable across launches, opaque
    /// server-side. Survives reinstalls only by accident — that's fine.
    private static func deviceIDHash() -> String {
        let key = "fore.contrib.deviceUUID"
        let defaults = UserDefaults.standard
        let uuid: String
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            uuid = existing
        } else {
            uuid = UUID().uuidString
            defaults.set(uuid, forKey: key)
        }
        let digest = SHA256.hash(data: Data(uuid.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func isContributeEnabled() -> Bool {
        // Default ON: registered in ForeApp's UserDefaults registration.
        UserDefaults.standard.bool(forKey: AppPreferenceKey.contributeSchemes)
    }

    private static func submittedPairs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "fore.contrib.submittedPairs") ?? [])
    }
}
