//
//  BluetoothManager.swift
//  Nautilus
//
//  CoreBluetooth manager for the ELK-BLEDOM BLE LED strip controller.
//  Service: FFF0, Write Characteristic: FFF3
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Connection State

enum BLEConnectionState: Equatable {
    case scanning
    case connected
    case disconnected
}

// MARK: - Discovered Device (scan result)

struct DiscoveredDevice: Identifiable, Equatable {
    let id: String          // peripheral UUID string
    let name: String
    let peripheral: CBPeripheral

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Indexed Color

/// Immutable RGB color value used across the manager. Replaces ad-hoc tuples so
/// that `@Published` state satisfies strict concurrency (`Sendable`).
struct IndexedColor: Equatable, Sendable {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

// MARK: - BluetoothManager

final class BluetoothManager: NSObject, ObservableObject {

    // MARK: Published State

    @Published private(set) var connectionState: BLEConnectionState = .disconnected
    @Published private(set) var isPowerOn: Bool = false
    @Published private(set) var lastColor: IndexedColor = IndexedColor(r: 255, g: 255, b: 255)
    /// Peripherals discovered during the latest scan (for the connection page).
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    /// UUID string of the currently connected peripheral (nil when disconnected).
    @Published private(set) var connectedPeripheralUUID: String?

    // MARK: BLE Constants

    private static let serviceUUID = CBUUID(string: "FFF0")
    private static let writeCharacteristicUUID = CBUUID(string: "FFF3")
    /// Devices whose advertised name contains "ELK" are accepted (covers
    /// ELK-BLEDOM, ELK-BLEDOB, and any other ELK-* strip names).
    private static let targetDevicePrefix = "ELK"

    // MARK: CoreBluetooth

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    // MARK: Thread Safety & Throttling

    /// Serial queue guarding mutable BLE-facing state.
    private let bleQueue = DispatchQueue(label: "com.nautilus.bluetooth.queue")

    /// Dispatch source used to coalesce high-frequency color writes.
    private var colorFlushSource: DispatchSourceTimer?
    private let colorFlushInterval: DispatchTimeInterval = .milliseconds(40)

    /// Pending color to be flushed; nil means "no pending write".
    private var pendingColor: IndexedColor?
    private let colorLock = NSLock()

    /// Most recent color actually transmitted; used to skip redundant writes.
    private var lastTransmittedColor: IndexedColor?

    /// Tracks whether we've auto-synced the clock for the current connection
    /// so we only do it once per connection cycle.
    private var didAutoSyncTime = false

    // MARK: Init

    override init() {
        super.init()
        // Defer central initialization until after super.init() per CoreBluetooth guidance.
        centralManager = CBCentralManager(
            delegate: self,
            queue: bleQueue,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
        setupColorFlushTimer()
    }

    deinit {
        colorFlushSource?.cancel()
        colorFlushSource = nil
    }

    // MARK: Public API

    func startScanning() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            guard self.centralManager.state == .poweredOn else { return }

            self.clearDiscoveredDevices()
            self.updateConnectionState(.scanning)

            // Single full scan (nil services) — we accept a device in `consider`
            // by matching its advertised name (ELK-BLEDOM/ELK-BLEDOB) OR the FFF0
            // service UUID. CoreBluetooth only supports one scan at a time, so a
            // filtered scan would miss name-only advertisers.
            self.centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    /// Connect to a discovered peripheral by its UUID string.
    func connect(to uuid: String) {
        bleQueue.async { [weak self] in
            guard let self else { return }
            guard let peripheral = self.discoveredPeripheral(uuid: uuid) else { return }
            self.stopScanningInternal()
            self.targetPeripheral = peripheral
            peripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
    }

    // MARK: Discovery helpers

    private func discoveredPeripheral(uuid: String) -> CBPeripheral? {
        discoveredDevices.first { $0.id == uuid }?.peripheral
    }

    private func stopScanningInternal() {
        if centralManager.isScanning {
            centralManager.stopScan()
        }
    }

    private func clearDiscoveredDevices() {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredDevices = []
        }
    }

    private func addDiscovered(peripheral: CBPeripheral, name: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let id = peripheral.identifier.uuidString
            if !self.discoveredDevices.contains(where: { $0.id == id }) {
                self.discoveredDevices.append(DiscoveredDevice(id: id, name: name, peripheral: peripheral))
            }
        }
    }

    func stopScanning() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            if self.centralManager.isScanning {
                self.centralManager.stopScan()
            }
        }
    }

    func disconnect() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            if let peripheral = self.targetPeripheral {
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    // MARK: Raw Byte Emitters

    func turnOn() {
        let frame: [UInt8] = [0x7E, 0x04, 0x04, 0x01, 0x00, 0x01, 0xFF, 0x00, 0xEF]
        writeFrame(frame)
        bleQueue.async { [weak self] in
            self?.publishPowerState(true)
        }
    }

    func turnOff() {
        let frame: [UInt8] = [0x7E, 0x04, 0x04, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xEF]
        writeFrame(frame)
        bleQueue.async { [weak self] in
            self?.publishPowerState(false)
        }
    }

    func sendColor(r: UInt8, g: UInt8, b: UInt8) {
        // Coalesce: store latest requested color; the timer flushes it.
        colorLock.lock()
        pendingColor = IndexedColor(r: r, g: g, b: b)
        colorLock.unlock()

        bleQueue.async { [weak self] in
            guard let self else { return }
            self.publishColor(r: r, g: g, b: b)
        }
    }

    // MARK: Command Emitters (mirrors CommandUtils.kt)

    /// Sets brightness as a percentage (0...100). Values are coerced into range.
    /// Frame: [7E,04,01,v,FF,FF,FF,00,EF]
    func setBrightness(_ value: Int) {
        let v = UInt8(clamping: Swift.min(100, Swift.max(0, value)))
        let frame: [UInt8] = [0x7E, 0x04, 0x01, v, 0xFF, 0xFF, 0xFF, 0x00, 0xEF]
        writeFrame(frame)
    }

    /// Sets pattern playback speed as a percentage (0...100). Values are coerced into range.
    /// Frame: [7E,04,02,v,FF,FF,FF,00,EF]
    func setSpeed(_ value: Int) {
        let v = UInt8(clamping: Swift.min(100, Swift.max(0, value)))
        let frame: [UInt8] = [0x7E, 0x04, 0x02, v, 0xFF, 0xFF, 0xFF, 0x00, 0xEF]
        writeFrame(frame)
    }

    /// Selects one of 29 preprogrammed patterns (0...28).
    /// Frame: [7E,05,03,(p+128),03,FF,FF,00,EF]
    func setPattern(_ pattern: Int) {
        let p = UInt8(clamping: Swift.min(28, Swift.max(0, pattern)) + 128)
        let frame: [UInt8] = [0x7E, 0x05, 0x03, p, 0x03, 0xFF, 0xFF, 0x00, 0xEF]
        writeFrame(frame)
    }

    /// Synces the strip's internal clock. Weekday is converted from Calendar's
    /// 1...7 (Sunday...Saturday) to the strip's 0...6.
    /// Frame: [7E,07,83,HH,MM,SS,(weekday-1),FF,EF]
    func syncTime(date: Date = Date()) {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second, .weekday], from: date)
        let hour = UInt8(clamping: Swift.max(0, comps.hour ?? 0))
        let minute = UInt8(clamping: Swift.max(0, comps.minute ?? 0))
        let second = UInt8(clamping: Swift.max(0, comps.second ?? 0))
        // Calendar.weekday is 1...7 (1 = Sunday); strip expects 0...6 (0 = Sunday).
        let weekday = UInt8(clamping: Swift.max(0, (comps.weekday ?? 1) - 1))
        let frame: [UInt8] = [0x7E, 0x07, 0x83, hour, minute, second, weekday, 0xFF, 0xEF]
        writeFrame(frame)
    }

    /// Configures the strip's on/off scheduling for a single time across selected
    /// weekdays. `weekdays` is a 7-element array indexed 0 = Sunday ... 6 = Saturday.
    /// Frame: [7E,08,82,HH,MM,SS,(isOn?0:1),(isSet?128:0)|packed,EF]
    func setTiming(hour: Int, minute: Int, second: Int,
                   weekdays: [Bool], isOn: Bool, isSet: Bool) {
        let h = UInt8(clamping: Swift.max(0, hour))
        let m = UInt8(clamping: Swift.max(0, minute))
        let s = UInt8(clamping: Swift.max(0, second))
        let onOff: UInt8 = isOn ? 0x00 : 0x01
        let setMask: UInt8 = isSet ? 0x80 : 0x00
        let packed = Self.packWeekdays(weekdays)
        let frame: [UInt8] = [0x7E, 0x08, 0x82, h, m, s, onOff, setMask | packed, 0xEF]
        writeFrame(frame)
    }

    /// Reorders the RGB traces/wires. 1 = Red, 2 = Green, 3 = Blue.
    /// Frame: [7E,06,81,a,b,c,FF,00,EF]
    func setWireOrder(firstWire: Int, secondWire: Int, thirdWire: Int) {
        let a = UInt8(clamping: Swift.max(0, firstWire))
        let b = UInt8(clamping: Swift.max(0, secondWire))
        let c = UInt8(clamping: Swift.max(0, thirdWire))
        let frame: [UInt8] = [0x7E, 0x06, 0x81, a, b, c, 0xFF, 0x00, 0xEF]
        writeFrame(frame)
    }

    // MARK: Custom Pattern Playback

    /// Plays a custom color sequence, writing each step's color to the strip
    /// with the step's own duration. Loops if `pattern.loops` is true.
    private var patternPlayTask: Task<Void, Never>?

    func playPattern(_ pattern: CustomPattern) {
        patternPlayTask?.cancel()

        guard !pattern.steps.isEmpty, targetPeripheral != nil else { return }

        patternPlayTask = Task { [weak self] in
            guard let self else { return }
            var index = 0
            while !Task.isCancelled {
                let step = pattern.steps[index]
                self.sendColor(r: UInt8(clamping: Int(step.red * 255)),
                               g: UInt8(clamping: Int(step.green * 255)),
                               b: UInt8(clamping: Int(step.blue * 255)))
                try? await Task.sleep(nanoseconds: UInt64(step.duration * 1_000_000_000))
                if Task.isCancelled { break }
                index += 1
                if index >= pattern.steps.count {
                    if pattern.loops {
                        index = 0
                    } else {
                        break
                    }
                }
            }
        }
    }

    func stopPatternPlayback() {
        patternPlayTask?.cancel()
        patternPlayTask = nil
    }

    /// Executes a routine action against the connected strip.
    func runRoutine(_ routine: Routine, patterns: [CustomPattern]) {
        switch routine.action {
        case .powerOn:
            turnOn()
        case .powerOff:
            turnOff()
        case .color:
            sendColor(r: UInt8(clamping: Int(routine.red * 255)),
                      g: UInt8(clamping: Int(routine.green * 255)),
                      b: UInt8(clamping: Int(routine.blue * 255)))
        case .pattern:
            if let pid = routine.patternID, let pattern = patterns.first(where: { $0.id == pid }) {
                playPattern(pattern)
            }
        }
    }

    // MARK: Color Flush Timer

    private func setupColorFlushTimer() {
        let source = DispatchSource.makeTimerSource(queue: bleQueue)
        source.schedule(
            deadline: .now() + colorFlushInterval,
            repeating: colorFlushInterval,
            leeway: .milliseconds(5)
        )
        source.setEventHandler { [weak self] in
            self?.flushPendingColor()
        }
        source.resume()
        colorFlushSource = source
    }

    private func flushPendingColor() {
        colorLock.lock()
        let color = pendingColor
        pendingColor = nil
        colorLock.unlock()

        guard let color else { return }

        // Skip redundant frames if the value is unchanged.
        if let last = lastTransmittedColor,
           last.r == color.r, last.g == color.g, last.b == color.b {
            return
        }

        lastTransmittedColor = color

        let frame: [UInt8] = [0x7E, 0x07, 0x05, 0x03, color.r, color.g, color.b, 0x10, 0xEF]
        writeFrameOnQueue(frame)
    }

    // MARK: Write Helpers

    /// Thread-safe entry point that hops onto the BLE queue.
    private func writeFrame(_ data: [UInt8]) {
        bleQueue.async { [weak self] in
            self?.writeFrameOnQueue(data)
        }
    }

    /// Must be called on `bleQueue`.
    private func writeFrameOnQueue(_ data: [UInt8]) {
        guard let peripheral = targetPeripheral,
              let characteristic = writeCharacteristic,
              peripheral.state == .connected else {
            return
        }

        let packet = Data(data)

        // Prefer write-without-response to avoid buffer saturation during
        // streaming, falling back to acknowledged writes if unsupported.
        if characteristic.properties.contains(.writeWithoutResponse) {
            let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
            writeChunked(packet, peripheral: peripheral, characteristic: characteristic,
                         type: .withoutResponse, mtu: max(mtu, 20))
        } else if characteristic.properties.contains(.write) {
            let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
            writeChunked(packet, peripheral: peripheral, characteristic: characteristic,
                         type: .withResponse, mtu: max(mtu, 20))
        }
    }

    private func writeChunked(_ packet: Data,
                              peripheral: CBPeripheral,
                              characteristic: CBCharacteristic,
                              type: CBCharacteristicWriteType,
                              mtu: Int) {
        // The LED frames are small (9 bytes); still chunk defensively in case
        // negotiated MTU is smaller than the payload.
        guard packet.count > 0 else { return }

        if packet.count <= mtu {
            peripheral.writeValue(packet, for: characteristic, type: type)
            return
        }

        var offset = 0
        while offset < packet.count {
            let end = min(offset + mtu, packet.count)
            let chunk = packet.subdata(in: offset..<end)
            peripheral.writeValue(chunk, for: characteristic, type: type)
            offset = end
        }
    }

    // MARK: State Helpers (called on bleQueue)

    private func updateConnectionState(_ state: BLEConnectionState) {
        if Thread.isMainThread {
            if self.connectionState != state { self.connectionState = state }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.connectionState != state { self.connectionState = state }
            }
        }
    }

    private func publishPowerState(_ on: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPowerOn = on
            self?.syncSharedState()
        }
    }

    private func publishColor(r: UInt8, g: UInt8, b: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.lastColor = IndexedColor(r: r, g: g, b: b)
            self?.syncSharedState()
        }
    }

    // MARK: Widget shared state

    /// Writes current power/color/name to the shared App Group so the
    /// home-screen widget can read it.
    private func syncSharedState() {
        let defaults = UserDefaults(suiteName: "group.com.nautilus.led")
        defaults?.set(isPowerOn, forKey: "widget.powerOn")
        let hex = String(format: "%02X%02X%02X", lastColor.r, lastColor.g, lastColor.b)
        defaults?.set(hex, forKey: "widget.colorHex")
        defaults?.set("Nautilus", forKey: "widget.deviceName")

        // Handle any pending toggle requested by the widget.
        if defaults?.object(forKey: "widget.pendingToggleTimestamp") != nil {
            defaults?.removeObject(forKey: "widget.pendingToggleTimestamp")
            let target = defaults?.bool(forKey: "widget.pendingPowerToggle")
            defaults?.removeObject(forKey: "widget.pendingPowerToggle")
            if let target {
                if target { turnOn() } else { turnOff() }
            }
        }
    }

    // MARK: Static Helpers

    /// Bit-packs a 7-element weekday array (index 0 = Sunday ... 6 = Saturday)
    /// into the single-byte mask used by `setTiming`.
    private static func packWeekdays(_ weekdays: [Bool]) -> UInt8 {
        var packed: UInt8 = 0
        for i in 0..<7 where weekdays.indices.contains(i) && weekdays[i] {
            packed |= UInt8(1 << i)
        }
        return packed
    }

    // MARK: Discovery Helpers

    private func consider(peripheral: CBPeripheral, advertisedName: String?, advertisedServices: [CBUUID]?) {
        // Match ONLY on names containing "ELK" (case/whitespace-insensitive).
        // Ignore service UUIDs entirely.
        let candidateNames = [advertisedName, peripheral.name].compactMap { $0 }
        let normalized = candidateNames.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        let nameMatches = normalized.contains { name in
            name.contains(Self.targetDevicePrefix)
        }

        guard nameMatches else { return }

        let name = advertisedName ?? peripheral.name ?? "LED Strip"
        addDiscovered(peripheral: peripheral, name: name)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff, .unauthorized, .unsupported, .resetting, .unknown:
            targetPeripheral = nil
            writeCharacteristic = nil
            updateConnectionState(.disconnected)
        @unknown default:
            updateConnectionState(.disconnected)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        consider(peripheral: peripheral,
                 advertisedName: advertisedName,
                 advertisedServices: advertisedServices)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheralUUID = peripheral.identifier.uuidString
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        targetPeripheral = nil
        writeCharacteristic = nil
        connectedPeripheralUUID = nil
        didAutoSyncTime = false
        updateConnectionState(.disconnected)
        startScanning()
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        targetPeripheral = nil
        writeCharacteristic = nil
        lastTransmittedColor = nil
        connectedPeripheralUUID = nil
        didAutoSyncTime = false
        updateConnectionState(.disconnected)
        // Auto-reconnect by restarting the scan.
        startScanning()
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }

        for service in services where service.uuid == Self.serviceUUID {
            peripheral.discoverCharacteristics([Self.writeCharacteristicUUID], for: service)
        }

        if services.isEmpty {
            // Some strips report a different service; discover all as fallback.
            peripheral.discoverServices(nil)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        guard error == nil else { return }
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics where characteristic.uuid == Self.writeCharacteristicUUID {
            writeCharacteristic = characteristic
            updateConnectionState(.connected)
            // Auto-sync the strip's clock on connect so schedules are accurate.
            if !didAutoSyncTime {
                didAutoSyncTime = true
                syncTime()
            }
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didWriteValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        // No-op: acknowledged writes complete here. Streaming uses
        // write-without-response, so we generally will not hit this path.
    }
}
