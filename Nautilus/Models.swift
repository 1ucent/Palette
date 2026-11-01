//
//  Models.swift
//  Nautilus
//
//  Data models for devices, groups, custom patterns, and routines.
//  All are Codable + Identifiable so they can be persisted as JSON.
//

import Foundation
import CoreBluetooth

// MARK: - LED Device

struct LEDDevice: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    /// BLE peripheral identifier (persisted across launches).
    var peripheralUUID: String
    var name: String
    var icon: String
    var groupID: UUID?

    init(peripheralUUID: String, name: String, icon: String = "lightbulb.fill", groupID: UUID? = nil) {
        self.peripheralUUID = peripheralUUID
        self.name = name
        self.icon = icon
        self.groupID = groupID
    }
}

// MARK: - Device Group

struct DeviceGroup: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String = "square.grid.2x2.fill"
}

// MARK: - Custom Pattern

struct PatternStep: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    /// RGB components 0...1.
    var red: Double
    var green: Double
    var blue: Double
    /// Duration of this step in seconds.
    var duration: Double

    init(red: Double, green: Double, blue: Double, duration: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.duration = duration
    }
}

struct CustomPattern: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var steps: [PatternStep]
    /// True = loop continuously; false = play once then stop.
    var loops: Bool

    init(name: String, icon: String = "circle.hexagongrid.fill", steps: [PatternStep], loops: Bool = true) {
        self.name = name
        self.icon = icon
        self.steps = steps
        self.loops = loops
    }
}

// MARK: - Routine

enum RoutineAction: String, Codable, CaseIterable {
    case color
    case pattern
    case powerOn
    case powerOff
}

struct Routine: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var time: Date
    var action: RoutineAction
    /// Used when action == .color
    var red: Double = 1
    var green: Double = 1
    var blue: Double = 1
    /// Used when action == .pattern
    var patternID: UUID?
    /// Days of week enabled (index 0 = Sunday ... 6 = Saturday).
    var weekdays: [Bool]
    var enabled: Bool

    init(name: String,
         icon: String = "clock.fill",
         time: Date,
         action: RoutineAction,
         red: Double = 1,
         green: Double = 1,
         blue: Double = 1,
         patternID: UUID? = nil,
         weekdays: [Bool] = Array(repeating: true, count: 7),
         enabled: Bool = true) {
        self.name = name
        self.icon = icon
        self.time = time
        self.action = action
        self.red = red
        self.green = green
        self.blue = blue
        self.patternID = patternID
        self.weekdays = weekdays
        self.enabled = enabled
    }
}

// MARK: - Device Icons

enum DeviceIcons {
    static let all: [String] = [
        "lightbulb.fill", "lightbulb", "lamp.desk.fill", "lamp.floor.fill",
        "chandelier.fill", "light.recessed.fill", "flashlight.on.fill",
        "star.fill", "heart.fill", "moon.fill", "sparkles", "bolt.fill",
        "house.fill", "bed.double.fill", "desktopcomputer", "tv.fill"
    ]
}

enum PatternIcons {
    static let all: [String] = [
        "circle.hexagongrid.fill", "wand.and.stars", "rainbow",
        "waveform.path.ecg", "flame.fill", "snowflake", "leaf.fill",
        "music.note", "bolt.fill", "heart.fill", "star.fill", "sun.max.fill"
    ]
}
