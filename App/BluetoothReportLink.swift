import Foundation
import CoreBluetooth
import SwiftUI

/// Foreground discovery and report transfer independent of Watch Connectivity.
/// Only the custom service UUID and a disposable receiver label are advertised.
final class BluetoothReportLink: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    struct Receiver: Identifiable { let id: UUID; let name: String }
    static let serviceID = CBUUID(string: "608FF842-F13E-4AD6-B752-97285388D65A")
    static let reportID = CBUUID(string: "608FF842-F13E-4AD6-B752-97285388D65B")
    @Published var status = "Bluetooth report transfer is stopped."
    @Published var receivers: [Receiver] = []
    @Published var scanning = false
    @Published var sending = false
    @Published var receiving = false
    @Published var receiverName = ""
    var onReport: ((Data) throws -> Void)?
    var reportProvider: (() throws -> Data)?
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var selected: CBPeripheral?
    private var frames: [Data] = []
    private var frameIndex = 0
    private var transferCharacteristic: CBCharacteristic?
    private var scanRequested = false
    private var scanTimer: Timer?
    private var sendTimer: Timer?
    private let preferredKey = "WatchLink.bluetooth.preferredReceiver"
    private var preferredAttempted = false
    #if os(iOS) || os(macOS)
    private var peripheralManager: CBPeripheralManager?
    private var armed = false
    private var publishedService = false
    private var expiry: Timer?
    private var peer: UUID?
    private var assembly = ReportBluetoothProtocol.Receiver()
    #endif

    private func describe(_ error: Error) -> String { let e = error as NSError; return "\(e.domain)/\(e.code)" }
    private func stateMessage(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOff: return "Turn on Bluetooth on both devices."
        case .unauthorized: return "Allow WatchLink Bluetooth access in Settings."
        case .unsupported: return "Bluetooth LE is unavailable on this device."
        case .resetting: return "Bluetooth is restarting; retry shortly."
        default: return "Waiting for Bluetooth permission and power."
        }
    }
    func startScanning() {
        guard !sending else { return }
        scanRequested = true; preferredAttempted = false; receivers = []; peripherals = [:]
        status = "Looking for nearby iPhones running WatchLink…"
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else { scanIfReady() }
    }
    func stopScanning() {
        scanRequested = false; scanning = false; scanTimer?.invalidate(); scanTimer = nil
        central?.stopScan()
    }
    private func scanIfReady() {
        guard scanRequested, let central else { return }
        guard central.state == .poweredOn else { scanning = false; status = stateMessage(central.state); return }
        central.scanForPeripherals(withServices: [Self.serviceID], options: nil)
        scanning = true
        status = "On iPhone, tap Get Watch report. Choose its receiver name here."
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            guard let self else { return }; self.stopScanning()
            self.status = self.receivers.isEmpty ? "No iPhone found. Open WatchLink on iPhone, tap Get Watch report, and allow Bluetooth on both devices." : "Choose an iPhone, or tap Find iPhone to search again."
        }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { scanIfReady() }
        else { stopSending(); scanning = false; status = stateMessage(central.state) }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard scanRequested, !sending else { return }
        peripherals[peripheral.identifier] = peripheral
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        // Do not expose the phone owner's device name or an arbitrary BLE name.
        let name = advertised.hasPrefix("WatchLink-") ? String(advertised.prefix(24)) : "WatchLink receiver"
        if !receivers.contains(where: { $0.id == peripheral.identifier }) { receivers.append(.init(id: peripheral.identifier, name: name)) }
        if !preferredAttempted, UserDefaults.standard.string(forKey: preferredKey) == peripheral.identifier.uuidString {
            preferredAttempted = true
            send(to: peripheral.identifier)
        }
    }
    func send(to id: UUID) {
        guard !sending, central?.state == .poweredOn, let peripheral = peripherals[id] else { return }
        stopScanning(); selected = peripheral; peripheral.delegate = self; sending = true
        status = "Connecting to selected iPhone…"
        central?.connect(peripheral, options: nil)
        sendTimer?.invalidate()
        sendTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self] _ in
            self?.stopSending(); self?.status = "Bluetooth transfer timed out. Keep both apps open and retry."
        }
    }
    func stopSending() {
        sendTimer?.invalidate(); sendTimer = nil
        let old = selected; selected = nil; sending = false; frames = []; frameIndex = 0; transferCharacteristic = nil
        if let old { central?.cancelPeripheralConnection(old) }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard selected?.identifier == peripheral.identifier else { return }
        status = "Connected. Preparing report transfer…"
        peripheral.discoverServices([Self.serviceID])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard selected?.identifier == peripheral.identifier else { return }
        stopSending(); status = "Cannot connect to iPhone: " + (error.map(describe) ?? "Bluetooth connection rejected.")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard selected?.identifier == peripheral.identifier else { return }
        stopSending(); status = "iPhone disconnected before confirming the saved report. Retry with both apps open."
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard selected?.identifier == peripheral.identifier else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.serviceID }) else {
            stopSending(); status = "iPhone report service is unavailable. Restart Get Watch report on iPhone."; return
        }
        peripheral.discoverCharacteristics([Self.reportID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard selected?.identifier == peripheral.identifier else { return }
        guard error == nil, let characteristic = service.characteristics?.first(where: { $0.uuid == Self.reportID && $0.properties.contains(.write) }) else {
            stopSending(); status = "iPhone does not expose the report receiver."; return
        }
        do {
            guard let reportProvider else { throw CocoaError(.fileReadUnknown) }
            frames = try ReportBluetoothProtocol.frames(reportProvider(), maximumWrite: peripheral.maximumWriteValueLength(for: .withResponse))
            frameIndex = 0; transferCharacteristic = characteristic
            writeNext(peripheral)
        } catch { stopSending(); status = "Run a scan on Watch before sending its report." }
    }
    private func writeNext(_ peripheral: CBPeripheral) {
        guard selected?.identifier == peripheral.identifier, let characteristic = transferCharacteristic, frameIndex < frames.count else { return }
        status = frameIndex == frames.count - 1 ? "Waiting for iPhone to save the report…" : "Sending report: \(frameIndex * 100 / frames.count)%"
        peripheral.writeValue(frames[frameIndex], for: characteristic, type: .withResponse)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard selected?.identifier == peripheral.identifier, characteristic.uuid == Self.reportID, frameIndex < frames.count else { return }
        if let error { stopSending(); status = "iPhone rejected the report: " + describe(error); return }
        frameIndex += 1
        if frameIndex == frames.count {
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: preferredKey)
            stopSending(); status = "iPhone received and saved the Watch report."
        } else { writeNext(peripheral) }
    }

    func startReceiving() {
        #if os(iOS) || os(macOS)
        guard !armed else { return }
        armed = true; receiverName = "WatchLink-" + String(UUID().uuidString.prefix(4))
        status = "Preparing nearby iPhone receiver…"
        if peripheralManager == nil { peripheralManager = CBPeripheralManager(delegate: self, queue: .main) }
        else { publishIfReady() }
        expiry?.invalidate()
        expiry = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            self?.stopReceiving(); self?.status = "Bluetooth receiver expired. Tap Get Watch report again."
        }
        #endif
    }
    func stopReceiving() {
        #if os(iOS) || os(macOS)
        armed = false; receiving = false; publishedService = false
        expiry?.invalidate(); expiry = nil
        peripheralManager?.stopAdvertising(); peripheralManager?.removeAllServices()
        peer = nil; assembly.reset()
        #endif
    }
    #if os(iOS) || os(macOS)
    private func publishIfReady() {
        guard armed, let manager = peripheralManager else { return }
        guard manager.state == .poweredOn else { status = stateMessage(manager.state); return }
        guard !publishedService else { return }
        let characteristic = CBMutableCharacteristic(type: Self.reportID, properties: [.write], value: nil, permissions: [.writeable])
        let service = CBMutableService(type: Self.serviceID, primary: true); service.characteristics = [characteristic]
        publishedService = true; manager.add(service)
    }
    #endif
}

#if os(iOS) || os(macOS)
extension BluetoothReportLink: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn { publishIfReady() }
        else { receiving = false; publishedService = false; status = stateMessage(peripheral.state) }
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard armed else { return }
        guard error == nil else { stopReceiving(); status = "Cannot publish Bluetooth receiver: " + describe(error!); return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Self.serviceID], CBAdvertisementDataLocalNameKey: receiverName])
    }
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard armed else { return }
        if let error { stopReceiving(); status = "Cannot advertise receiver: " + describe(error) }
        else { receiving = true; status = "Nearby receiver ready for 2 minutes. Open Send report on Watch." }
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let request = requests.first else { return }
        guard armed, receiving, requests.count == 1, request.characteristic.uuid == Self.reportID,
              request.offset == 0, let value = request.value, peer == nil || peer == request.central.identifier else {
            peripheral.respond(to: request, withResult: .requestNotSupported); return
        }
        do {
            peer = request.central.identifier
            if let report = try assembly.accept(value) {
                guard let onReport else { throw CocoaError(.fileWriteUnknown) }
                try onReport(report)
                // ATT success on the COMMIT frame is the persisted receipt.
                peripheral.respond(to: request, withResult: .success)
                status = "Watch report received and saved over Bluetooth."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.stopReceiving() }
            } else { peripheral.respond(to: request, withResult: .success) }
        } catch {
            assembly.reset(); peer = nil
            status = "Report rejected: " + describe(error)
            peripheral.respond(to: request, withResult: .unlikelyError)
        }
    }
}
#endif
