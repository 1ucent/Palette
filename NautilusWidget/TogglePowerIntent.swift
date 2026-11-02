//
//  TogglePowerIntent.swift
//  NautilusWidget
//
//  AppIntent that requests a power toggle. The widget cannot reach BLE
//  directly, so it records a pending request in the shared App Group; the
//  main app observes it and applies the toggle when it is running.
//

import AppIntents

struct TogglePowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Power"
    static var description = IntentDescription("Turns the LED strip on or off.")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)
        let currentlyOn = defaults?.bool(forKey: WidgetShared.powerOnKey) ?? false
        // Record the requested next state; the app flips it on next observation.
        defaults?.set(!currentlyOn, forKey: "widget.pendingPowerToggle")
        // Also persist the request as a timestamp so the app notices the change.
        defaults?.set(Date().timeIntervalSince1970, forKey: "widget.pendingToggleTimestamp")
        return .result()
    }
}
