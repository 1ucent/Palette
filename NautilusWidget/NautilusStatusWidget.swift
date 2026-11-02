//
//  NautilusStatusWidget.swift
//  NautilusWidget
//
//  A home-screen widget that reads the app's shared state (device power/color)
//  from the shared App Group and offers a quick power-toggle button.
//

import WidgetKit
import SwiftUI

// MARK: - Shared App Group key

enum WidgetShared {
    static let appGroupID = "group.com.nautilus.led"
    static let powerOnKey = "widget.powerOn"
    static let colorKey = "widget.colorHex"
    static let deviceNameKey = "widget.deviceName"
}

// MARK: - Timeline entry

struct StatusEntry: TimelineEntry {
    let date: Date
    let isOn: Bool
    let deviceName: String
    let colorHex: String
}

// MARK: - Provider

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), isOn: false, deviceName: "Nautilus", colorHex: "FFFFFF")
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> StatusEntry {
        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)
        let isOn = defaults?.bool(forKey: WidgetShared.powerOnKey) ?? false
        let name = defaults?.string(forKey: WidgetShared.deviceNameKey) ?? "Nautilus"
        let color = defaults?.string(forKey: WidgetShared.colorKey) ?? "FFFFFF"
        return StatusEntry(date: Date(), isOn: isOn, deviceName: name, colorHex: color)
    }
}

// MARK: - View

struct StatusWidgetView: View {
    var entry: StatusEntry

    private var color: Color {
        Color(hex: entry.colorHex) ?? .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(entry.isOn ? color : .white.opacity(0.4))
                Spacer()
                Text(entry.isOn ? "On" : "Off")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text(entry.deviceName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            // Toggle button
            Button(intent: TogglePowerIntent()) {
                Image(systemName: "power")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(entry.isOn ? color.opacity(0.85) : .white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.09),
                                    Color(red: 0.01, green: 0.03, blue: 0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Widget

struct NautilusStatusWidget: Widget {
    let kind: String = "NautilusStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Nautilus")
        .description("Quickly check your LED strip and toggle power.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Color hex helper

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
