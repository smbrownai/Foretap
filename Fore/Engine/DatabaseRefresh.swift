//
//  DatabaseRefresh.swift
//  Fore
//
//  Phase B: pulls a freshly-promoted apps.json.gz from the backend
//  and caches it locally. AppDatabaseLoader prefers the cached copy
//  over the bundled JSON, so users see new community-verified
//  schemes without an App Store update.
//
//  Refresh policy:
//  - On app launch, if cache is missing OR older than 7 days, fetch.
//  - Fetches are best-effort: any network/parse failure leaves the
//    cached file (or bundled fallback) in place.
//  - Cached file lives in Application Support/AppDatabase.json so
//    it survives app launches but not reinstalls.
//

import Foundation

enum DatabaseRefresh {

    /// Where the cached database lives. Public so AppDatabaseLoader
    /// can prefer-load from here.
    static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appending(path: "AppDatabase.json")
    }

    /// Fetch a fresh database if the local cache is missing or stale.
    /// Call from app launch + scenePhase active. Safe to call often;
    /// a single in-flight task is reused.
    static func refreshIfStale(ttl: TimeInterval = 7 * 24 * 60 * 60) {
        guard BackendConfig.isConfigured else { return }
        guard !inFlight else { return }

        let needsRefresh: Bool = {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
                  let modified = attrs[.modificationDate] as? Date else {
                return true
            }
            return Date().timeIntervalSince(modified) > ttl
        }()
        guard needsRefresh else { return }

        inFlight = true
        Task.detached(priority: .background) {
            await fetchAndCache()
            await MainActor.run { inFlight = false }
        }
    }

    @MainActor private static var inFlight = false

    private static func fetchAndCache() async {
        var req = URLRequest(url: BackendConfig.databaseEndpoint)
        req.timeoutInterval = 30
        // We accept gzipped, but URLSession will decompress automatically
        // for `Accept-Encoding: gzip`. Set it explicitly so the body we
        // get is decoded JSON ready to write to disk.
        req.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return }

            // Sanity check: must parse as a non-empty array of entries.
            guard let parsed = try? JSONSerialization.jsonObject(with: data),
                  let array = parsed as? [Any], !array.isEmpty else { return }

            try ensureDirectoryExists(for: cacheURL)
            // Atomic write so a crashed write can't corrupt the cache.
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // Best-effort: keep the existing cache or bundled fallback.
        }
    }

    private static func ensureDirectoryExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
