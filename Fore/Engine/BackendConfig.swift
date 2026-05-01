//
//  BackendConfig.swift
//  Fore
//
//  Endpoint URLs for the Phase B+C backend (the Cloudflare Worker
//  defined in tools/backend). Replace the placeholder host below
//  after running `wrangler deploy` — the URL printed by Wrangler is
//  what goes here. Both endpoints can be off (left as the placeholder
//  host) and the app still works fine; the contribution + refresh
//  paths are best-effort and silently no-op on network errors.
//

import Foundation

enum BackendConfig {
    /// Replace with the URL Wrangler prints after `npm run deploy`.
    /// Example:  https://fore-db.foretap.workers.dev
    static let baseURL = URL(string: "https://fore-db.foretap.workers.dev")!

    static var submissionsEndpoint: URL { baseURL.appending(path: "v1/schemes") }
    static var databaseEndpoint: URL { baseURL.appending(path: "v1/apps.json.gz") }

    /// True when the placeholder host hasn't been replaced. Submission
    /// + refresh helpers gate on this so debug builds don't hammer
    /// example.workers.dev with traffic.
    static var isConfigured: Bool {
        baseURL.host != "fore-db.foretap.workers.dev"
    }
}
