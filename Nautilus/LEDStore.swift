//
//  LEDStore.swift
//  Nautilus
//
//  App-side persistence for devices, groups, custom patterns, and routines.
//  Data is stored as JSON in Application Support. No secrets are involved,
//  so plain JSON files are appropriate here (vs Keychain).
//

import Foundation
import Combine

final class LEDStore: ObservableObject {

    @Published var devices: [LEDDevice] = [] {
        didSet { persistDevices() }
    }
    @Published var groups: [DeviceGroup] = [] {
        didSet { persistGroups() }
    }
    @Published var patterns: [CustomPattern] = [] {
        didSet { persistPatterns() }
    }
    @Published var routines: [Routine] = [] {
        didSet { persistRoutines() }
    }

    // MARK: Persistence

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nautilus", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var devicesURL: URL { baseDirectory.appendingPathComponent("devices.json") }
    private var groupsURL: URL { baseDirectory.appendingPathComponent("groups.json") }
    private var patternsURL: URL { baseDirectory.appendingPathComponent("patterns.json") }
    private var routinesURL: URL { baseDirectory.appendingPathComponent("routines.json") }

    init() {
        load()
    }

    // MARK: Load

    private func load() {
        devices = loadJSON([LEDDevice].self, from: devicesURL) ?? []
        groups = loadJSON([DeviceGroup].self, from: groupsURL) ?? []
        patterns = loadJSON([CustomPattern].self, from: patternsURL) ?? []
        routines = loadJSON([Routine].self, from: routinesURL) ?? []
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: Persist

    private func persistDevices() { persist(devices, to: devicesURL) }
    private func persistGroups() { persist(groups, to: groupsURL) }
    private func persistPatterns() { persist(patterns, to: patternsURL) }
    private func persistRoutines() { persist(routines, to: routinesURL) }

    private func persist<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Device helpers

    func device(withPeripheralUUID uuid: String) -> LEDDevice? {
        devices.first { $0.peripheralUUID == uuid }
    }

    @discardableResult
    func addOrUpdateDevice(peripheralUUID: String, name: String) -> LEDDevice {
        if let existing = device(withPeripheralUUID: peripheralUUID) {
            // Preserve user's custom name/icon; only refresh if empty.
            return existing
        }
        let device = LEDDevice(peripheralUUID: peripheralUUID, name: name)
        devices.append(device)
        return device
    }

    func renameDevice(_ device: LEDDevice, to newName: String) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx].name = newName
    }

    func setDeviceIcon(_ device: LEDDevice, to icon: String) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx].icon = icon
    }

    func deleteDevice(_ device: LEDDevice) {
        devices.removeAll { $0.id == device.id }
    }

    // MARK: Group helpers

    @discardableResult
    func addGroup(name: String) -> DeviceGroup {
        let group = DeviceGroup(name: name)
        groups.append(group)
        return group
    }

    func assign(_ device: LEDDevice, to groupID: UUID?) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx].groupID = groupID
    }

    func renameGroup(_ group: DeviceGroup, to newName: String) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].name = newName
    }

    func deleteGroup(_ group: DeviceGroup) {
        groups.removeAll { $0.id == group.id }
        for i in devices.indices where devices[i].groupID == group.id {
            devices[i].groupID = nil
        }
    }

    // MARK: Pattern helpers

    func addPattern(_ pattern: CustomPattern) {
        patterns.append(pattern)
    }

    func updatePattern(_ pattern: CustomPattern) {
        guard let idx = patterns.firstIndex(where: { $0.id == pattern.id }) else { return }
        patterns[idx] = pattern
    }

    func deletePattern(_ pattern: CustomPattern) {
        patterns.removeAll { $0.id == pattern.id }
    }

    // MARK: Routine helpers

    func addRoutine(_ routine: Routine) {
        routines.append(routine)
    }

    func updateRoutine(_ routine: Routine) {
        guard let idx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[idx] = routine
    }

    func deleteRoutine(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }
    }
}
