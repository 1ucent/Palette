//
//  SettingsView.swift
//  Nautilus
//
//  Settings tab for the ELK-BLEDOM LED strip controller: brightness, pattern
//  speed, preset pattern selection, clock sync, and weekly scheduling.
//

import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject private var bluetooth: BluetoothManager

    @State private var brightness: Double = 0.85
    @State private var speed: Double = 0.5
    @State private var selectedPattern: Int = 0
    @State private var timingHour: Int = 18
    @State private var timingMinute: Int = 0
    @State private var timingIsOn: Bool = true
    @State private var timingIsSet: Bool = true
    @State private var weekdays: [Bool] = Array(repeating: false, count: 7)

    private static let daySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    brightnessSection
                    speedSection
                    patternSection
                    clockSection
                    scheduleSection
                    Spacer(minLength: 20)
                }
                .padding(22)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.05, blue: 0.09),
                Color(red: 0.01, green: 0.03, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Configure your LED strip")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 8)
    }

    private var isConnected: Bool {
        bluetooth.connectionState == .connected
    }

    private var brightnessSection: some View {
        sectionCard(title: "BRIGHTNESS") {
            VStack(spacing: 14) {
                Text("\(Int((brightness * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Slider(value: $brightness, in: 0...1)
                    .tint(.white.opacity(0.85))
                    .onChange(of: brightness) { _, newValue in
                        guard isConnected else { return }
                        bluetooth.setBrightness(Int((newValue * 100).rounded()))
                    }
            }
        }
        .opacity(isConnected ? 1.0 : 0.45)
    }

    private var speedSection: some View {
        sectionCard(title: "PATTERN SPEED") {
            VStack(spacing: 14) {
                Text("\(Int((speed * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Slider(value: $speed, in: 0...1)
                    .tint(.white.opacity(0.85))
                    .onChange(of: speed) { _, newValue in
                        guard isConnected else { return }
                        bluetooth.setSpeed(Int((newValue * 100).rounded()))
                    }
            }
        }
        .opacity(isConnected ? 1.0 : 0.45)
    }

    private var patternSection: some View {
        sectionCard(title: "PATTERN") {
            Picker("Pattern", selection: $selectedPattern) {
                ForEach(0..<29, id: \.self) { index in
                    Text("\(index + 1)").tag(index)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .onChange(of: selectedPattern) { _, newValue in
                guard isConnected else { return }
                bluetooth.setPattern(newValue)
            }
        }
        .opacity(isConnected ? 1.0 : 0.45)
    }

    private var clockSection: some View {
        sectionCard(title: "CLOCK") {
            Button {
                guard isConnected else { return }
                bluetooth.syncTime()
            } label: {
                HStack {
                    Label("Sync device time", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
    }

    private var scheduleSection: some View {
        sectionCard(title: "WEEKLY SCHEDULE") {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        Button {
                            weekdays[index].toggle()
                        } label: {
                            Text(Self.daySymbols[index])
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(weekdays[index] ? Color.white.opacity(0.22) : Color.white.opacity(0.06))
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }

                DatePicker(
                    "Time",
                    selection: Binding(
                        get: {
                            var comps = DateComponents()
                            comps.hour = timingHour
                            comps.minute = timingMinute
                            return Calendar.current.date(from: comps) ?? Date()
                        },
                        set: { date in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                            timingHour = comps.hour ?? 0
                            timingMinute = comps.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .tint(.white)

                Toggle("Turn lights on", isOn: $timingIsOn)
                    .tint(.white.opacity(0.85))
                Toggle("Enable this schedule", isOn: $timingIsSet)
                    .tint(.white.opacity(0.85))

                Button {
                    applySchedule()
                } label: {
                    Text("Apply Schedule")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.15, green: 0.45, blue: 0.75))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Helpers

    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.55))
            content()
        }
        .padding(22)
        .background(glassCard(cornerRadius: 26))
        .overlay(specularHighlights(cornerRadius: 26))
    }

    private func applySchedule() {
        guard isConnected else { return }
        bluetooth.setTiming(
            hour: timingHour,
            minute: timingMinute,
            second: 0,
            weekdays: weekdays,
            isOn: timingIsOn,
            isSet: timingIsSet
        )
    }

    private func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 12)
    }

    private func specularHighlights(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.05), Color.white.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .blendMode(.screen)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(BluetoothManager())
}
