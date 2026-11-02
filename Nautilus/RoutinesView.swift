//
//  RoutinesView.swift
//  Nautilus
//
//  Routines tab: time-based automations (color, pattern, on/off). App-side —
//  they fire while the app is running.
//

import SwiftUI

struct RoutinesView: View {

    @EnvironmentObject private var store: LEDStore
    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var scheduler = RoutineScheduler()

    @State private var editingRoutine: Routine?
    @State private var isNewRoutine = false
    @State private var fired: [UUID: Date] = [:]

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    newButton
                    if store.routines.isEmpty {
                        emptyState
                    } else {
                        routineList
                    }
                    Spacer(minLength: 20)
                }
                .padding(22)
            }
        }
        .sheet(item: $editingRoutine) { routine in
            RoutineEditorView(routine: routine)
        }
        .onAppear { scheduler.start() }
        .onDisappear { scheduler.stop() }
        .onReceive(NotificationCenter.default.publisher(for: .routineSchedulerTick)) { _ in
            evaluateRoutines()
        }
    }

    private var background: some View {
        WallpaperGradient(kind: settings.wallpaper)
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Routines")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Automations at set times")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 8)
    }

    private var newButton: some View {
        Button {
            isNewRoutine = true
            editingRoutine = Routine(name: "New Routine", time: Date(), action: .powerOn)
        } label: {
            Label("New routine", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.15, green: 0.45, blue: 0.75)))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Text("No routines yet.\nTap \"New routine\" to automate your lights.")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    private var routineList: some View {
        VStack(spacing: 12) {
            ForEach(store.routines) { routine in
                routineRow(routine)
            }
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            Image(systemName: routine.icon)
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(timeString(routine.time)) · \(actionLabel(routine.action))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { routine.enabled },
                set: { newValue in
                    var updated = routine
                    updated.enabled = newValue
                    store.updateRoutine(updated)
                }
            ))
            .labelsHidden()
            .tint(.white.opacity(0.85))
            Button { editingRoutine = routine } label: {
                Image(systemName: "pencil").foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func evaluateRoutines() {
        let now = Date()
        let cal = Calendar.current

        for routine in store.routines where routine.enabled {
            let comps = cal.dateComponents([.hour, .minute, .second, .weekday], from: now)
            let rComps = cal.dateComponents([.hour, .minute, .second], from: routine.time)

            guard comps.hour == rComps.hour,
                  comps.minute == rComps.minute,
                  comps.second == rComps.second else { continue }

            let weekdayIdx = cal.component(.weekday, from: now) - 1
            guard routine.weekdays.indices.contains(weekdayIdx),
                  routine.weekdays[weekdayIdx] else { continue }

            if let last = fired[routine.id], now.timeIntervalSince(last) < 60 { continue }

            fired[routine.id] = now
            bluetooth.runRoutine(routine, patterns: store.patterns)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func actionLabel(_ action: RoutineAction) -> String {
        switch action {
        case .color: return "Color"
        case .pattern: return "Pattern"
        case .powerOn: return "Turn on"
        case .powerOff: return "Turn off"
        }
    }
}

