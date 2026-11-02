//
//  ConnectionSettingsView.swift
//  Nautilus
//
//  Connection page: scan for LED strips, connect/disconnect, rename and change
//  icon, and organize devices into groups.
//

import SwiftUI

struct ConnectionSettingsView: View {

    @EnvironmentObject private var bluetooth: BluetoothManager
    @EnvironmentObject private var store: LEDStore

    @State private var isScanning = false
    @State private var editingDevice: LEDDevice?
    @State private var renameGroup: DeviceGroup?

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if !store.devices.isEmpty {
                        groupsSection
                        devicesSection
                    }
                    discoveredSection
                    Spacer(minLength: 20)
                }
                .padding(22)
            }
        }
        .sheet(item: $editingDevice) { device in
            DeviceEditorSheet(device: device)
        }
        .sheet(item: $renameGroup) { group in
            GroupRenameSheet(group: group)
        }
        .onAppear {
            // Auto-scan as soon as the Lights tab opens.
            bluetooth.startScanning()
            isScanning = true
        }
        .onDisappear {
            bluetooth.stopScanning()
            isScanning = false
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
            Text("Connections")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Manage your LED strips")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 8)
    }

    private var groupsSection: some View {
        card(title: "GROUPS") {
            VStack(spacing: 10) {
                ForEach(store.groups) { group in
                    HStack(spacing: 12) {
                        Image(systemName: group.icon)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(group.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(countForGroup(group))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Button { renameGroup = group } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        Button { store.deleteGroup(group) } label: {
                            Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                }

                if store.groups.isEmpty {
                    Text("No groups yet")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                Button {
                    store.addGroup(name: "New Group")
                } label: {
                    Label("New group", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func countForGroup(_ group: DeviceGroup) -> String {
        let count = store.devices.filter { $0.groupID == group.id }.count
        return "\(count) light\(count == 1 ? "" : "s")"
    }

    private var devicesSection: some View {
        card(title: "MY LIGHTS") {
            VStack(spacing: 10) {
                ForEach(store.devices) { device in
                    DeviceRow(device: device, isConnected: bluetooth.connectedPeripheralUUID == device.peripheralUUID)
                        .onTapGesture { editingDevice = device }
                }
            }
        }
    }

    private var discoveredSection: some View {
        card(title: "NEARBY") {
            VStack(spacing: 12) {
                if bluetooth.discoveredDevices.isEmpty {
                    Text("Nothing found nearby")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(bluetooth.discoveredDevices) { device in
                        DiscoveredRow(device: device)
                    }
                }

                Button {
                    toggleScan()
                } label: {
                    Label(isScanning ? "Stop scanning" : "Scan for lights",
                          systemImage: isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.15, green: 0.45, blue: 0.75)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleScan() {
        if isScanning {
            bluetooth.stopScanning()
            isScanning = false
        } else {
            bluetooth.startScanning()
            isScanning = true
        }
    }

    private func card(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.55))
            content()
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 26).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)
    }
}

// MARK: - Rows

private struct DeviceRow: View {
    @EnvironmentObject var store: LEDStore
    let device: LEDDevice
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let group = store.groups.first(where: { $0.id == device.groupID }) {
                    Text(group.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer()
            if isConnected {
                Text("Connected")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.35, green: 0.95, blue: 0.75))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
        .contentShape(Rectangle())
    }
}

private struct DiscoveredRow: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var store: LEDStore
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.white.opacity(0.8))
            Text(device.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button {
                bluetooth.connect(to: device.id)
                store.addOrUpdateDevice(peripheralUUID: device.id, name: device.name)
            } label: {
                Text("Connect")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.15, green: 0.45, blue: 0.75)))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Editor sheets

private struct DeviceEditorSheet: View {
    @EnvironmentObject var store: LEDStore
    @EnvironmentObject var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    let device: LEDDevice

    @State private var name: String = ""
    @State private var icon: String = "lightbulb.fill"
    @State private var groupID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section("Icon") {
                    iconGrid(selected: $icon)
                }
                Section("Group") {
                    Picker("Group", selection: $groupID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(store.groups) { group in
                            Text(group.name).tag(group.id as UUID?)
                        }
                    }
                }
                Section("Time") {
                    Button {
                        bluetooth.syncTime()
                    } label: {
                        Label("Sync device time", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationTitle("Edit Light")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.renameDevice(device, to: name)
                        store.setDeviceIcon(device, to: icon)
                        store.assign(device, to: groupID)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        store.deleteDevice(device)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .onAppear {
                name = device.name
                icon = device.icon
                groupID = device.groupID
            }
        }
    }

    private func iconGrid(selected: Binding<String>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(DeviceIcons.all, id: \.self) { iconName in
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(selected.wrappedValue == iconName ? .white : .white.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(selected.wrappedValue == iconName ? Color.blue.opacity(0.5) : Color.white.opacity(0.06)))
                    .onTapGesture { selected.wrappedValue = iconName }
            }
        }
    }
}

private struct GroupRenameSheet: View {
    @EnvironmentObject var store: LEDStore
    @Environment(\.dismiss) private var dismiss
    let group: DeviceGroup

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Group name", text: $name)
                }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.renameGroup(group, to: name)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { name = group.name }
        }
    }
}
