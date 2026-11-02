//
//  SettingsView.swift
//  Nautilus
//
//  Client-side settings: accent color, wallpaper, and light/dark appearance.
//  These alter the app's own look, not the LED strip.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            wallpaperBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    accentSection
                    wallpaperSection
                    appearanceSection
                    Spacer(minLength: 20)
                }
                .padding(22)
            }
        }
    }

    // MARK: Background (uses selected wallpaper)

    private var wallpaperBackground: some View {
        WallpaperGradient(kind: settings.wallpaper)
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Customize your app")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 8)
    }

    // MARK: Accent color

    private var accentSection: some View {
        card(title: "ACCENT COLOR") {
            ColorPicker("Accent", selection: Binding(
                get: { settings.accentColor },
                set: { color in
                    let ui = UIColor(color)
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                    let hex = String(format: "%02X%02X%02X",
                                     Int(r * 255), Int(g * 255), Int(b * 255))
                    settings.accentHex = hex
                }
            ), supportsOpacity: false)
        }
    }

    // MARK: Wallpaper

    private var wallpaperSection: some View {
        card(title: "WALLPAPER") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(WallpaperKind.allCases, id: \.self) { kind in
                    WallpaperGradient(kind: kind.rawValue)
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(settings.wallpaper == kind.rawValue ? settings.accentColor : .white.opacity(0.2), lineWidth: 3)
                        )
                        .onTapGesture { settings.wallpaper = kind.rawValue }
                }
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        card(title: "APPEARANCE") {
            Picker("Appearance", selection: $settings.appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Card

    private func card(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.55))
            content()
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 26).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)
    }
}

// MARK: - Wallpaper kinds

enum WallpaperKind: String, CaseIterable {
    case ocean = "ocean"
    case midnight = "midnight"
    case ember = "ember"
    case aurora = "aurora"
}

struct WallpaperGradient: View {
    let kind: String

    private var colors: [Color] {
        switch kind {
        case "ocean":
            return [Color(red: 0.02, green: 0.05, blue: 0.09),
                    Color(red: 0.03, green: 0.08, blue: 0.13),
                    Color(red: 0.01, green: 0.03, blue: 0.06)]
        case "midnight":
            return [Color(red: 0.03, green: 0.02, blue: 0.08),
                    Color(red: 0.06, green: 0.04, blue: 0.15),
                    Color(red: 0.01, green: 0.01, blue: 0.04)]
        case "ember":
            return [Color(red: 0.12, green: 0.05, blue: 0.02),
                    Color(red: 0.22, green: 0.09, blue: 0.03),
                    Color(red: 0.06, green: 0.02, blue: 0.01)]
        case "aurora":
            return [Color(red: 0.02, green: 0.08, blue: 0.06),
                    Color(red: 0.05, green: 0.04, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.05)]
        default:
            return [Color(red: 0.02, green: 0.05, blue: 0.09),
                    Color(red: 0.03, green: 0.08, blue: 0.13),
                    Color(red: 0.01, green: 0.03, blue: 0.06)]
        }
    }

    var body: some View {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
