//
//  LaunchAppIntent.swift
//  Fore
//
//  AppIntent invoked when the user taps an app icon inside a Fore widget.
//  Records a usage event into the shared queue, then returns an OpenURLIntent
//  so iOS launches the target app.
//
//  Member of: Fore + ForeWidgetsExtension targets.
//

import AppIntents
import Foundation

struct LaunchAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch App via Fore"
    static var description = IntentDescription("Opens the chosen app and records the launch.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "URL Scheme")
    var urlScheme: String

    @Parameter(title: "App Name")
    var appName: String

    init() {}

    init(urlScheme: String, appName: String) {
        self.urlScheme = urlScheme
        self.appName = appName
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        SharedUsageQueue.append(scheme: urlScheme)

        guard let url = URL(string: urlScheme) else {
            return .result(opensIntent: OpenURLIntent(URL(string: "about:blank")!))
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
