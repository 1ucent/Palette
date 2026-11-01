//
//  NautilusApp.swift
//  Nautilus
//
//  Application entry point. Owns the single BluetoothManager instance and
//  injects it into the view hierarchy.
//

import SwiftUI

@main
struct NautilusApp: App {

    @StateObject private var bluetooth: BluetoothManager = BluetoothManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Dashboard", systemImage: "slider.horizontal.3")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .environmentObject(bluetooth)
            .preferredColorScheme(.dark)
            .onAppear {
                configureAppearance()
            }
        }
    }

    private func configureAppearance() {
        // Force an obsidian status bar / navigation appearance across the app.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.01, green: 0.03, blue: 0.06, alpha: 1.0)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
