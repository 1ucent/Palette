//
//  RoutineEditorView.swift
//  Nautilus
//
//  Editor for a routine: name, time, action, color/pattern, and weekdays.
//

import SwiftUI

struct RoutineEditorView: View {

    @EnvironmentObject private var store: LEDStore
    @Environment(\.dismiss) private var dismiss

    let routine: Routine

    @State private var name: String = ""
    @State private var icon: String = "clock.fill"
    @State private var time: Date = Date()
    @State private var action: RoutineAction = .color
    @State private var red: Double = 1
    @State private var green: Double = 1
    @State private var blue: Double = 1
    @State private var patternID: UUID?
    @State private var weekdays: [Bool] = Array(repeating: true, count: 7)
    @State private var enabled: Bool = true

    private static let daySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Routine name", text: $name)
                }

                Section("Time") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section("Action") {
                    Picker("Action", selection: $action) {
                        ForEach(RoutineAction.allCases, id: \.self) { a in
                            Text(actionLabel(a)).tag(a)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if action == .color {
                    Section("Color") {
                        ColorPicker("Color", selection: Binding(
                            get: { Color(red: red, green: green, blue: blue) },
                            set: { c in
                                if let rgb = RGBExtractor(color: c) {
                                    red = rgb.red; green = rgb.green; blue = rgb.blue
                                }
                            }
                        ))
                    }
                }

                if action == .pattern {
                    Section("Pattern") {
                        Picker("Pattern", selection: $patternID) {
                            ForEach(store.patterns) { p in
                                Text(p.name).tag(p.id as UUID?)
                            }
                        }
                    }
                }

                Section("Days") {
                    HStack {
                        ForEach(0..<7, id: \.self) { i in
                            Button {
                                weekdays[i].toggle()
                            } label: {
                                Text(Self.daySymbols[i])
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(Circle().fill(weekdays[i] ? Color.blue.opacity(0.5) : Color.white.opacity(0.08)))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Toggle("Enabled", isOn: $enabled)
                }
            }
            .navigationTitle("Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") { store.deleteRoutine(routine); dismiss() }
                        .foregroundStyle(.red)
                }
            }
            .onAppear {
                name = routine.name
                icon = routine.icon
                time = routine.time
                action = routine.action
                red = routine.red; green = routine.green; blue = routine.blue
                patternID = routine.patternID
                weekdays = routine.weekdays
                enabled = routine.enabled
            }
        }
    }

    private func save() {
        var updated = routine
        updated.name = name
        updated.icon = icon
        updated.time = time
        updated.action = action
        updated.red = red; updated.green = green; updated.blue = blue
        updated.patternID = patternID
        updated.weekdays = weekdays
        updated.enabled = enabled

        if store.routines.contains(where: { $0.id == routine.id }) {
            store.updateRoutine(updated)
        } else {
            store.addRoutine(updated)
        }
    }

    private func actionLabel(_ a: RoutineAction) -> String {
        switch a {
        case .color: return "Color"
        case .pattern: return "Pattern"
        case .powerOn: return "On"
        case .powerOff: return "Off"
        }
    }
}

private struct RGBExtractor {
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
