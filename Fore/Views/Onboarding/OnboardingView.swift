//
//  OnboardingView.swift
//  Fore
//
//  Three-screen first-launch flow. Persists completion in @AppStorage so it
//  doesn't show again. Per SPEC §12 Phase 8.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppPreferenceKey.didCompleteOnboarding)
    private var didComplete: Bool = false

    @State private var page: Int = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                page1.tag(0)
                page2.tag(1)
                page3.tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    didComplete = true
                }
            } label: {
                Text(page < 2 ? "Continue" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled()
    }

    private var page1: some View {
        OnboardingPage(
            symbol: "square.grid.3x3.fill",
            title: "Sections, not chaos",
            message: "Fore replaces the App Library with named sections — Pinned, Work, Travel, anything you want. Stack them, reorder them, ignore the ones you don't need."
        )
    }

    private var page2: some View {
        OnboardingPage(
            symbol: "sparkles",
            title: "Right apps, right time",
            message: "Recently Used and Frequently Used auto-populate based on your launches. Time-based and Focus-based sections rise to the top when their context kicks in."
        )
    }

    private var page3: some View {
        OnboardingPage(
            symbol: "square.stack.3d.up.fill",
            title: "Home-screen widgets",
            message: "Add a Fore widget to launch apps without opening Fore first. Long-press the widget to pick which section it shows."
        )
    }
}

private struct OnboardingPage: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 60)
    }
}
