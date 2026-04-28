//
//  AppDatabaseLoader.swift
//  Fore
//
//  Loads bundled AppDatabase.json. Decodes raw entries into a lightweight
//  struct, then runs canOpenURL via SchemeValidator (Phase 1 surfaces a
//  default check; full validator arrives in Phase 3).
//

import Foundation
import UIKit

struct AppDatabaseEntry: Codable, Hashable, Identifiable {
    var name: String
    var urlScheme: String
    var category: AppCategory
    var keywords: [String]

    var id: String { urlScheme }
}

enum AppDatabaseLoaderError: Error {
    case fileNotFound
    case decodingFailed(Error)
}

struct AppDatabaseLoader {
    static let bundledFileName = "AppDatabase"
    static let bundledFileExtension = "json"

    static func loadBundledEntries(bundle: Bundle = .main) throws -> [AppDatabaseEntry] {
        guard let url = bundle.url(forResource: bundledFileName, withExtension: bundledFileExtension) else {
            throw AppDatabaseLoaderError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([AppDatabaseEntry].self, from: data)
        } catch {
            throw AppDatabaseLoaderError.decodingFailed(error)
        }
    }

    /// Tri-state install status for an entry. iOS only lets `canOpenURL`
    /// verify schemes listed in `LSApplicationQueriesSchemes` (capped at 50)
    /// plus Apple system schemes. For schemes outside that set we genuinely
    /// don't know — callers decide what to do with `unverified`.
    enum InstallStatus {
        case installed       // canOpenURL returned true
        case notInstalled    // declared scheme, canOpenURL returned false
        case unverified      // scheme not declared; iOS won't tell us
    }

    /// Resolves install status for each entry. Must be called from the main actor.
    @MainActor
    static func resolveInstalled(_ entries: [AppDatabaseEntry]) -> [(entry: AppDatabaseEntry, status: InstallStatus)] {
        let declared = declaredQueriesSchemes()
        return entries.map { entry in
            (entry, status(for: entry.urlScheme, declared: declared))
        }
    }

    /// Convenience for code paths that only need the optimistic boolean
    /// (treat `unverified` as installed). Used at AppEntry write time so
    /// home-screen icons don't get dimmed for things we can't verify.
    @MainActor
    static func optimisticIsInstalled(scheme: String) -> Bool {
        switch status(for: scheme, declared: declaredQueriesSchemes()) {
        case .installed, .unverified: return true
        case .notInstalled:           return false
        }
    }

    @MainActor
    private static func status(for urlScheme: String, declared: Set<String>) -> InstallStatus {
        guard let url = URL(string: urlScheme),
              let scheme = url.scheme?.lowercased() else {
            return .notInstalled
        }
        if UIApplication.shared.canOpenURL(url) { return .installed }
        return declared.contains(scheme) ? .notInstalled : .unverified
    }

    private static func declaredQueriesSchemes() -> Set<String> {
        let raw = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        return Set(raw.map { $0.lowercased() })
    }
}
