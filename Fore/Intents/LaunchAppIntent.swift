//
//  LaunchAppIntent.swift
//  Fore
//
//  AppIntent invoked when the user taps an app icon inside a Fore widget.
//  Apple's OpenURLIntent only honors universal links, so for custom URL
//  schemes (msteams://, spotify://, etc.) we set openAppWhenRun = true,
//  let perform() run inside the Fore parent app, record the usage event,
//  then call openURL ourselves.
//
//  Member of: Fore + ForeWidgetsExtension targets.
//

import AppIntents
import Foundation
import SwiftUI

struct LaunchAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch App via Fore"
    static var description = IntentDescription("Opens the chosen app and records the launch.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "URL Scheme")
    var urlScheme: String

    @Parameter(title: "App Name")
    var appName: String

    init() {}

    init(urlScheme: String, appName: String) {
        self.urlScheme = urlScheme
        self.appName = appName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SharedUsageQueue.append(scheme: urlScheme)
        if let url = URL(string: urlScheme) {
            EnvironmentValues().openURL(url)
        }
        return .result()
    }
}
