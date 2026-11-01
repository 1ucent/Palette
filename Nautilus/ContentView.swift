//
//  ContentView.swift
//  Nautilus
//
//  Premium "Liquid Glass" dashboard for controlling the ELK-BLEDOM LED strip.
//

import SwiftUI

// MARK: - Color Model

private struct RGBColor: Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(color: Color) {
        let ui = UIColor(color)
        var cr: CGFloat = 0
        var cg: CGFloat = 0
        var cb: CGFloat = 0
        var ca: CGFloat = 0
        if ui.getRed(&cr, green: &cg, blue: &cb, alpha: &ca) {
            self.r = Double(cr)
            self.g = Double(cg)
            self.b = Double(cb)
        } else {
            self.r = 1; self.g = 1; self.b = 1
        }
    }

    var swiftUIColor: Color {
        Color(red: r, green: g, blue: b)
    }

    var rByte: UInt8 { UInt8(clamping: Int((r.clamped * 255).rounded())) }
    var gByte: UInt8 { UInt8(clamping: Int((g.clamped * 255).rounded())) }
    var bByte: UInt8 { UInt8(clamping: Int((b.clamped * 255).rounded())) }
}

private extension Double {
    var clamped: Double { Swift.min(1.0, Swift.max(0.0, self)) }
}

// MARK: - ContentView

struct ContentView: View {

    @EnvironmentObject private var bluetooth: BluetoothManager

    @State private var selectedColor: Color = .white
    @State private var brightness: Double = 0.85
    @State private var diskPressed: Bool = false
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        ZStack {
            oceanBackground
            contentLayer
        }
        .preferredColorScheme(.dark)
        .onAppear {
            bluetooth.startScanning()
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }

    // MARK: Background

    private var oceanBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.09),
                    Color(red: 0.03, green: 0.08, blue: 0.13),
                    Color(red: 0.01, green: 0.03, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.18, blue: 0.28).opacity(0.55),
                    Color.clear
                ],
                center: .init(x: 0.2, y: 0.15),
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.02, green: 0.1, blue: 0.2).opacity(0.45),
                    Color.clear
                ],
                center: .init(x: 0.85, y: 0.9),
                startRadius: 20,
                endRadius: 480
            )
            .ignoresSafeArea()

            ambientGlow
                .ignoresSafeArea()
        }
    }

    private var ambientGlow: some View {
        let glow = RGBColor(color: selectedColor).swiftUIColor
        return Circle()
            .fill(glow)
            .frame(width: 380, height: 380)
            .blur(radius: 160)
            .opacity(bluetooth.isPowerOn ? 0.35 * brightness : 0.0)
            .scaleEffect(bluetooth.isPowerOn ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.6), value: bluetooth.isPowerOn)
            .animation(.easeInOut(duration: 0.3), value: brightness)
    }

    // MARK: Content Layer

    private var contentLayer: some View {
        VStack(spacing: 22) {
            statusIndicator
                .padding(.top, 8)

            Spacer(minLength: 0)

            powerDisk
                .padding(.vertical, 6)

            Spacer(minLength: 0)

            controlCard

            Spacer(minLength: 0)

            connectionFooter
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }

    // MARK: Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.9), radius: 8)
                .opacity(statusPulseOpacity)

            Text(statusText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(glassCard(cornerRadius: 22))
        .overlay(specularHighlights(cornerRadius: 22))
    }

    // MARK: Power Disk

    private var powerDisk: some View {
        let diskColor = RGBColor(color: selectedColor).swiftUIColor
        return Button(action: togglePower) {
            ZStack {
                // Outer ambient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: 258, height: 258)

                // Glass base
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.85),
                                Color(red: 0.04, green: 0.06, blue: 0.1).opacity(0.9)
                            ],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 8,
                            endRadius: 200
                        )
                    )
                    .frame(width: 240, height: 240)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // Inner liquid color fill when powered
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                diskColor.opacity(bluetooth.isPowerOn ? 0.9 : 0.12),
                                diskColor.opacity(bluetooth.isPowerOn ? 0.35 : 0.02)
                            ],
                            center: .init(x: 0.42, y: 0.38),
                            startRadius: 6,
                            endRadius: 170
                        )
                    )
                    .frame(width: 196, height: 196)
                    .blur(radius: 2)
                    .opacity(bluetooth.isPowerOn ? 1.0 : 0.7)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.10), lineWidth: 0.8)
                            .frame(width: 196, height: 196)
                    )

                // Specular highlight sheen
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 130, height: 60)
                    .blur(radius: 6)
                    .offset(y: -66)
                    .opacity(bluetooth.isPowerOn ? 0.55 : 0.3)

                // Power glyph
                Image(systemName: "power")
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(
                        bluetooth.isPowerOn
                            ? .white
                            : .white.opacity(0.55)
                    )
                    .shadow(color: bluetooth.isPowerOn ? diskColor.opacity(0.9) : .clear, radius: 18)
            }
            .frame(width: 258, height: 258)
            .scaleEffect(diskPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: diskPressed)
            .animation(.easeInOut(duration: 0.5), value: bluetooth.isPowerOn)
            .animation(.easeInOut(duration: 0.3), value: selectedColor)
            .shadow(color: .black.opacity(0.6), radius: 26, x: 0, y: 16)
        }
        .buttonStyle(PressableButtonStyle(pressed: $diskPressed))
        .disabled(!isInteractionEnabled)
        .opacity(isInteractionEnabled ? 1.0 : 0.55)
    }

    // MARK: Control Card

    private var controlCard: some View {
        VStack(spacing: 20) {
            HStack {
                Text("AMBIANCE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.6)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(Int((brightness * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
            }

            brightnessSlider

            Divider()
                .overlay(.white.opacity(0.08))

            HStack {
                Text("COLOR")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.6)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: selectedColor) { _, newValue in
                        let rgb = RGBColor(color: newValue)
                        bluetooth.sendColor(r: rgb.rByte, g: rgb.gByte, b: rgb.bByte)
                    }
            }
        }
        .padding(22)
        .background(glassCard(cornerRadius: 30))
        .overlay(specularHighlights(cornerRadius: 30))
    }

    // MARK: Brightness Slider

    private var brightnessSlider: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let trackHeight: CGFloat = 12
            let knobSize: CGFloat = 30
            let usableWidth = max(width - knobSize, 1)
            let knobX = knobSize / 2 + CGFloat(brightness) * usableWidth
            let accent = RGBColor(color: selectedColor).swiftUIColor

            ZStack(alignment: .leading) {
                // Track base
                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: trackHeight)
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                    )

                // Filled portion
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.35), accent.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(knobX, trackHeight), height: trackHeight)
                    .blur(radius: 1.4)

                // Glossy knurled knob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.55)
                            ],
                            center: .init(x: 0.35, y: 0.32),
                            startRadius: 2,
                            endRadius: knobSize
                        )
                    )
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
                    .shadow(color: accent.opacity(0.7), radius: 12)
                    .offset(x: knobX - knobSize / 2)
            }
            .frame(height: max(trackHeight, knobSize))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x - knobSize / 2
                        let ratio = Double(x / usableWidth)
                        brightness = Swift.min(1.0, Swift.max(0.0, ratio))
                        streamBrightness()
                    }
            )
        }
        .frame(height: 30)
    }

    // MARK: Footer

    private var connectionFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: footerIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(footerText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(.white.opacity(0.4))
    }

    // MARK: Glass Helpers

    private func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.02)
                            ],
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
                    colors: [
                        Color.white.opacity(0.35),
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .blendMode(.screen)
    }

    // MARK: Logic

    private var isInteractionEnabled: Bool {
        bluetooth.connectionState == .connected
    }

    private func togglePower() {
        guard isInteractionEnabled else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            if bluetooth.isPowerOn {
                bluetooth.turnOff()
            } else {
                bluetooth.turnOn()
                let rgb = RGBColor(color: selectedColor)
                bluetooth.sendColor(r: rgb.rByte, g: rgb.gByte, b: rgb.bByte)
            }
        }
    }

    private func streamBrightness() {
        guard isInteractionEnabled, bluetooth.isPowerOn else { return }
        let base = RGBColor(color: selectedColor)
        let scaled = RGBColor(
            r: base.r * brightness,
            g: base.g * brightness,
            b: base.b * brightness
        )
        bluetooth.sendColor(r: scaled.rByte, g: scaled.gByte, b: scaled.bByte)
    }

    private var statusColor: Color {
        switch bluetooth.connectionState {
        case .connected: return Color(red: 0.35, green: 0.95, blue: 0.75)
        case .scanning: return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .disconnected: return Color(red: 1.0, green: 0.45, blue: 0.45)
        }
    }

    private var statusPulseOpacity: Double {
        switch bluetooth.connectionState {
        case .scanning:
            return 0.45 + Double(pulsePhase) * 0.55
        default:
            return 1.0
        }
    }

    private var statusText: String {
        switch bluetooth.connectionState {
        case .connected: return "LINKED"
        case .scanning: return "SYNCING"
        case .disconnected: return "OFFLINE"
        }
    }

    private var footerIcon: String {
        switch bluetooth.connectionState {
        case .connected: return "dot.radiowaves.left.and.right"
        case .scanning: return "antenna.radiowaves.left.and.right"
        case .disconnected: return "wifi.slash"
        }
    }

    private var footerText: String {
        switch bluetooth.connectionState {
        case .connected: return "ELK-BLEDOM connected"
        case .scanning: return "Searching for strip\u{2026}"
        case .disconnected: return "Not connected"
        }
    }
}

// MARK: - Pressable Button Style

private struct PressableButtonStyle: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                pressed = newValue
            }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(BluetoothManager())
}
