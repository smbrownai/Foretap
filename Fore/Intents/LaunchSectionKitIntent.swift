//
//  LaunchSectionKitIntent.swift
//  Fore
//
//  "Start my morning kit in Fore" — sequentially open every app in the
//  named section, with a delay between each. SPEC §10 explicitly calls out
//  that this needs main-app process for `UIApplication.open`, so the intent
//  brings Fore forward.
//

import AppIntents
import Foundation
import UIKit

struct LaunchSectionKitIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch Section Kit in Fore"
    static var description = IntentDescription("Sequentially open every app in a Fore section.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Section", optionsProvider: SectionTitleOptionsProvider())
    var sectionTitle: String

    @Parameter(title: "Delay (seconds)", default: 1)
    var delaySeconds: Int

    init() {}
    init(sectionTitle: String, delaySeconds: Int = 1) {
        self.sectionTitle = sectionTitle
        self.delaySeconds = delaySeconds
    }

    func perform() async throws -> some IntentResult {
        let urls: [URL] = await MainActor.run {
            ForeStore.shared.apps(inSectionNamed: sectionTitle)
                .compactMap { URL(string: $0.urlScheme) }
        }

        let nanos = UInt64(max(delaySeconds, 0)) * 1_000_000_000

        for url in urls {
            await UIApplication.shared.open(url)
            if nanos > 0 {
                try? await Task.sleep(nanoseconds: nanos)
            }
        }

        return .result()
    }
}
