//
//  RoutineScheduler.swift
//  Nautilus
//
//  App-side scheduler that checks enabled routines every second and fires them
//  when their time (and selected weekday) matches. This is app-side: it only
//  runs while the app is in the foreground.
//

import Foundation
import Combine

final class RoutineScheduler: ObservableObject {

    private var timer: Timer?
    private var lastFired: [UUID: Date] = [:]   // routine id -> last fire time

    /// Starts the scheduler loop.
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        NotificationCenter.default.post(name: .routineSchedulerTick, object: nil)
    }
}

extension Notification.Name {
    static let routineSchedulerTick = Notification.Name("routineSchedulerTick")
}
