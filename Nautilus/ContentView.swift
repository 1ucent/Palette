//
//  ContentView.swift
//  Nautilus
//
//  Liquid Glass dashboard. A centered power button whose border glows with the
//  current color; tap toggles power, long-press opens the color picker. A ring
//  of "knobs" around it is the brightness control — rotating left raises it,
//  right lowers it, with haptic ticks.
//

import SwiftUI
import UIKit

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

    @State private var selectedColor: Color = Color(red: 0.15, green: 0.45, blue: 0.75)
    @State private var brightness: Double = 0.85
    @State private var diskPressed: Bool = false
    @State private var pulsePhase: CGFloat = 0
    @State private var showColorPicker: Bool = false
    @State private var knobRotation: Double = 0

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticTick = UISelectionFeedbackGenerator()

    var body: some View {
        ZStack {
            background
            contentLayer
        }
        .preferredColorScheme(.dark)
        .onAppear {
            hapticLight.prepare()
            hapticTick.prepare()
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }

    // MARK: Background

    private var background: some View {
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
        VStack(spacing: 20) {
            statusIndicator
                .padding(.top, 8)

            Spacer(minLength: 0)

            powerControl
                .padding(.vertical, 6)

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

    // MARK: Power Control (power button + brightness knob ring)

    private var powerControl: some View {
        ZStack {
            // Outer brightness knob ring
            brightnessKnobRing

            // Power button
            powerButton
        }
        .frame(width: 340, height: 340)
    }

    private var currentColor: Color {
        RGBColor(color: selectedColor).swiftUIColor
    }

    // MARK: Power Button

    private var powerButton: some View {
        Button(action: togglePower) {
            ZStack {
                // Liquid glass base
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.9),
                                Color(red: 0.04, green: 0.06, blue: 0.1).opacity(0.95)
                            ],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 8,
                            endRadius: 200
                        )
                    )
                    .frame(width: 220, height: 220)

                // Color glow when powered
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                currentColor.opacity(bluetooth.isPowerOn ? 0.85 : 0.15),
                                currentColor.opacity(bluetooth.isPowerOn ? 0.3 : 0.03)
                            ],
                            center: .init(x: 0.42, y: 0.38),
                            startRadius: 6,
                            endRadius: 160
                        )
                    )
                    .frame(width: 182, height: 182)
                    .blur(radius: 2)
                    .opacity(bluetooth.isPowerOn ? 1.0 : 0.7)

                // Specular sheen
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
                    .offset(y: -60)
                    .opacity(bluetooth.isPowerOn ? 0.55 : 0.3)

                Image(systemName: "power")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(bluetooth.isPowerOn ? .white : .white.opacity(0.55))
                    .shadow(color: bluetooth.isPowerOn ? currentColor.opacity(0.9) : .clear, radius: 18)
            }
            .frame(width: 240, height: 240)
            .overlay(
                // Current-color border
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [currentColor.opacity(0.9), currentColor.opacity(0.2), currentColor.opacity(0.9)],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .blur(radius: 0.8)
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 0.8)
            )
            .scaleEffect(diskPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: diskPressed)
            .animation(.easeInOut(duration: 0.5), value: bluetooth.isPowerOn)
            .animation(.easeInOut(duration: 0.3), value: selectedColor)
            .shadow(color: .black.opacity(0.6), radius: 26, x: 0, y: 16)
            .shadow(color: bluetooth.isPowerOn ? currentColor.opacity(0.5) : .clear, radius: 20)
        }
        .buttonStyle(PressableButtonStyle(pressed: $diskPressed))
        // Long press opens the iOS color picker.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    showColorPicker = true
                }
        )
        .sheet(isPresented: $showColorPicker) {
            NavigationStack {
                ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                    .padding()
                    .navigationTitle("Pick a Color")
                    .navigationBarTitleDisplayMode(.inline)
                    .onChange(of: selectedColor) { _, newValue in
                        applyColor(newValue)
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: Brightness Knob Ring

    private var brightnessKnobRing: some View {
        let markerCount = 48
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 6)
                .frame(width: 300, height: 300)

            Circle()
                .trim(from: 0, to: brightness)
                .stroke(
                    AngularGradient(
                        colors: [currentColor.opacity(0.6), currentColor.opacity(0.9)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.15), value: brightness)

            ForEach(0..<markerCount, id: \.self) { i in
                let angle = Double(i) / Double(markerCount) * 360.0
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < Int(Double(markerCount) * brightness) ? currentColor : .white.opacity(0.2))
                    .frame(width: 2, height: 8)
                    .offset(y: -146)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: 300, height: 300)
        .rotationEffect(.degrees(knobRotation))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleKnobDrag(value)
                }
        )
    }

    private func handleKnobDrag(_ value: DragGesture.Value) {
        let center = CGPoint(x: 150, y: 150)
        let delta = CGVector(dx: value.location.x - center.x,
                             dy: value.location.y - center.y)
        let angle = atan2(delta.dy, delta.dx) * 180 / .pi
        var dRotation = angle - knobRotation
        if dRotation > 180 { dRotation -= 360 }
        if dRotation < -180 { dRotation += 360 }

        let step = 3.0
        let ticks = Int(dRotation / step)
        if ticks != 0 {
            // Right (clockwise, positive) lowers brightness; left raises it.
            let newBrightness = brightness - Double(ticks) * 0.01
            let clamped = Swift.min(1.0, Swift.max(0.0, newBrightness))
            if clamped != brightness {
                brightness = clamped
                hapticTick.selectionChanged()
                if bluetooth.isPowerOn {
                    streamBrightness()
                }
            }
        }
        knobRotation = angle
    }

    // MARK: Connection Footer

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

    // MARK: Logic

    private var isInteractionEnabled: Bool {
        bluetooth.connectionState == .connected
    }

    private func togglePower() {
        guard isInteractionEnabled else { return }
        hapticLight.impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            if bluetooth.isPowerOn {
                bluetooth.turnOff()
            } else {
                bluetooth.turnOn()
                applyColor(selectedColor)
            }
        }
    }

    private func applyColor(_ color: Color) {
        let rgb = RGBColor(color: color)
        bluetooth.sendColor(r: rgb.rByte, g: rgb.gByte, b: rgb.bByte)
    }

    private func streamBrightness() {
        guard isInteractionEnabled, bluetooth.isPowerOn else { return }
        let base = RGBColor(color: selectedColor)
        let scaled = RGBColor(r: base.r * brightness, g: base.g * brightness, b: base.b * brightness)
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
        case .scanning: return 0.45 + Double(pulsePhase) * 0.55
        default: return 1.0
        }
    }

    private var statusText: String {
        switch bluetooth.connectionState {
        case .connected: return "LINKED"
        case .scanning: return "SCANNING"
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
        case .disconnected: return "Connect in the Lights tab"
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
