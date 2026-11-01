//
//  CustomPatternsView.swift
//  Nautilus
//
//  Patterns tab: play and edit saved custom color-sequence patterns.
//

import SwiftUI

struct CustomPatternsView: View {

    @EnvironmentObject private var store: LEDStore
    @EnvironmentObject private var bluetooth: BluetoothManager

    @State private var editingPattern: CustomPattern?
    @State private var isNewPattern = false
    @State private var playingPatternID: UUID?

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    newButton

                    if store.patterns.isEmpty {
                        emptyState
                    } else {
                        patternList
                    }

                    Spacer(minLength: 20)
                }
                .padding(22)
            }
        }
        .sheet(item: $editingPattern) { pattern in
            PatternEditorView(pattern: pattern)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.02, green: 0.05, blue: 0.09),
                     Color(red: 0.01, green: 0.03, blue: 0.06)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Patterns")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Play and edit custom sequences")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 8)
    }

    private var newButton: some View {
        Button {
            isNewPattern = true
            editingPattern = CustomPattern(name: "New Pattern",
                                           steps: [PatternStep(red: 1, green: 0, blue: 0, duration: 1),
                                                   PatternStep(red: 0, green: 0, blue: 1, duration: 1)])
        } label: {
            Label("New pattern", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.15, green: 0.45, blue: 0.75)))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Text("No custom patterns yet.\nTap \"New pattern\" to build one.")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    private var patternList: some View {
        VStack(spacing: 12) {
            ForEach(store.patterns) { pattern in
                patternRow(pattern)
            }
        }
    }

    private func patternRow(_ pattern: CustomPattern) -> some View {
        HStack(spacing: 12) {
            previewSwatch(pattern)
            VStack(alignment: .leading, spacing: 3) {
                Text(pattern.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(pattern.steps.count) step\(pattern.steps.count == 1 ? "" : "s") · \(pattern.loops ? "loops" : "once")")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()

            Button {
                if playingPatternID == pattern.id {
                    bluetooth.stopPatternPlayback()
                    playingPatternID = nil
                } else {
                    bluetooth.playPattern(pattern)
                    playingPatternID = pattern.id
                }
            } label: {
                Image(systemName: playingPatternID == pattern.id ? "stop.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(playingPatternID == pattern.id ? Color.red.opacity(0.7) : Color(red: 0.15, green: 0.45, blue: 0.75)))
            }
            .buttonStyle(.plain)

            Button { editingPattern = pattern } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func previewSwatch(_ pattern: CustomPattern) -> some View {
        let colors = pattern.steps.map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
        return LinearGradient(colors: colors.isEmpty ? [.white] : colors,
                              startPoint: .leading, endPoint: .trailing)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
