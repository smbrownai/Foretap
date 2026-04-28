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

    /// Returns the entries with their `isInstalled` value resolved by
    /// `UIApplication.canOpenURL`. Must be called from the main actor.
    @MainActor
    static func resolveInstalled(_ entries: [AppDatabaseEntry]) -> [(entry: AppDatabaseEntry, isInstalled: Bool)] {
        entries.map { entry in
            let installed: Bool = {
                guard let url = URL(string: entry.urlScheme) else { return false }
                return UIApplication.shared.canOpenURL(url)
            }()
            return (entry, installed)
        }
    }
}
