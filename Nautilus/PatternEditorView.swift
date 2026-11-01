//
//  PatternEditorView.swift
//  Nautilus
//
//  Editor for building a custom color sequence. Each step has its own color
//  and duration.
//

import SwiftUI

struct PatternEditorView: View {

    @EnvironmentObject private var store: LEDStore
    @Environment(\.dismiss) private var dismiss

    let pattern: CustomPattern

    @State private var name: String = ""
    @State private var icon: String = "circle.hexagongrid.fill"
    @State private var loops: Bool = true
    @State private var steps: [PatternStep] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Pattern name", text: $name)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(PatternIcons.all, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.system(size: 22))
                                .foregroundStyle(icon == iconName ? .white : .white.opacity(0.5))
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(icon == iconName ? Color.blue.opacity(0.5) : Color.white.opacity(0.06)))
                                .onTapGesture { icon = iconName }
                        }
                    }
                }

                Section("Steps") {
                    ForEach($steps) { $step in
                        StepRow(step: $step, onDelete: { removeStep(step) })
                    }
                    Button {
                        steps.append(PatternStep(red: 1, green: 1, blue: 1, duration: 1))
                    } label: {
                        Label("Add step", systemImage: "plus")
                    }
                }

                Section {
                    Toggle("Loop", isOn: $loops)
                }
            }
            .navigationTitle("Edit Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        store.deletePattern(pattern)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .onAppear {
                name = pattern.name
                icon = pattern.icon
                loops = pattern.loops
                steps = pattern.steps
            }
        }
    }

    private func removeStep(_ step: PatternStep) {
        steps.removeAll { $0.id == step.id }
    }

    private func save() {
        var updated = pattern
        updated.name = name
        updated.icon = icon
        updated.loops = loops
        updated.steps = steps

        if store.patterns.contains(where: { $0.id == pattern.id }) {
            store.updatePattern(updated)
        } else {
            store.addPattern(updated)
        }
    }
}

// MARK: - Step Row

private struct StepRow: View {
    @Binding var step: PatternStep
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ColorPicker("Color", selection: Binding(
                get: { Color(red: step.red, green: step.green, blue: step.blue) },
                set: { newColor in
                    if let rgb = RGBColorOption(color: newColor) {
                        step.red = rgb.red
                        step.green = rgb.green
                        step.blue = rgb.blue
                    }
                }
            ))

            HStack {
                Text("Duration")
                Spacer()
                Text(String(format: "%.1f s", step.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $step.duration, in: 0.1...10, step: 0.1)

            Button(action: onDelete) {
                Label("Remove", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - RGB extraction helper

private struct RGBColorOption {
    let red: Double
    let green: Double
    let blue: Double

    init?(color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
    }
}
