//
//  ForeShortcutsProvider.swift
//  Fore
//
//  Registers canonical Siri phrases for the Fore app intents.
//
//  Note: AppShortcut phrase placeholders only accept AppEntity / AppEnum
//  parameter types, and at most one per phrase. Our intents take String
//  parameters (section titles, app names) backed by DynamicOptionsProviders,
//  so we keep the phrases parameter-less. Siri prompts the user for the
//  parameter values after recognizing the phrase.
//

import AppIntents

struct ForeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSectionIntent(),
            phrases: [
                "Open a section in \(.applicationName)",
                "Show a section in \(.applicationName)"
            ],
            shortTitle: "Open Section",
            systemImageName: "rectangle.stack"
        )

        AppShortcut(
            intent: LaunchSectionKitIntent(),
            phrases: [
                "Start a kit in \(.applicationName)",
                "Launch a section kit in \(.applicationName)"
            ],
            shortTitle: "Launch Section Kit",
            systemImageName: "play.rectangle.on.rectangle"
        )

        AppShortcut(
            intent: GetTopAppsIntent(),
            phrases: [
                "Get my top apps from \(.applicationName)",
                "What are my top apps in \(.applicationName)"
            ],
            shortTitle: "Top Apps",
            systemImageName: "star"
        )

        AppShortcut(
            intent: AddAppToSectionIntent(),
            phrases: [
                "Add an app to a section in \(.applicationName)"
            ],
            shortTitle: "Add App to Section",
            systemImageName: "plus.app"
        )
    }
}
