import Foundation
import CoreBluetooth

// MARK: - Scan Bluetooth Devices
struct ScanBluetoothDevicesTool: ClaudeTool {
    let name = "scan_bluetooth_devices"
    let description = "Scan for nearby Bluetooth Low Energy (BLE) devices"
    let category = ToolCategory.bluetooth

    let parameters = [
        ToolParameter(name: "duration_seconds", type: .integer, description: "Scan duration in seconds (default 5, max 15)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let duration = min(15, arguments["duration_seconds"] as? Int ?? 5)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            class Scanner: NSObject, CBCentralManagerDelegate {
                var centralManager: CBCentralManager!
                var discoveredDevices: [(name: String?, rssi: Int, uuid: String)] = []
                var continuation: CheckedContinuation<String, Error>?
                let duration: Int

                init(duration: Int, continuation: CheckedContinuation<String, Error>) {
                    self.duration = duration
                    self.continuation = continuation
                    super.init()
                    self.centralManager = CBCentralManager(delegate: self, queue: nil)
                }

                func centralManagerDidUpdateState(_ central: CBCentralManager) {
                    switch central.state {
                    case .poweredOn:
                        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) { [weak self] in
                            self?.finishScan()
                        }

                    case .poweredOff:
                        continuation?.resume(throwing: ToolError.executionFailed("Bluetooth is turned off"))
                        continuation = nil

                    case .unauthorized:
                        continuation?.resume(throwing: ToolError.permissionDenied("Bluetooth access denied"))
                        continuation = nil

                    default:
                        continuation?.resume(throwing: ToolError.executionFailed("Bluetooth unavailable (state: \(central.state.rawValue))"))
                        continuation = nil
                    }
                }

                func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
                    let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
                    let uuid = peripheral.identifier.uuidString

                    if !discoveredDevices.contains(where: { $0.uuid == uuid }) {
                        discoveredDevices.append((name: name, rssi: RSSI.intValue, uuid: uuid))
                    }
                }

                func finishScan() {
                    centralManager.stopScan()

                    let sorted = discoveredDevices.sorted { $0.rssi > $1.rssi }

                    if sorted.isEmpty {
                        continuation?.resume(returning: "No Bluetooth devices found during \(duration)s scan.")
                        continuation = nil
                        return
                    }

                    var result = "Bluetooth Scan Results (\(duration)s):\n"
                    result += "Found \(sorted.count) device(s):\n\n"

                    for (i, device) in sorted.enumerated() {
                        result += "\(i + 1). \(device.name ?? "Unknown Device")\n"
                        result += "   Signal: \(device.rssi) dBm"

                        if device.rssi > -50 {
                            result += " (Excellent)"
                        } else if device.rssi > -70 {
                            result += " (Good)"
                        } else if device.rssi > -85 {
                            result += " (Fair)"
                        } else {
                            result += " (Weak)"
                        }

                        result += "\n   UUID: \(device.uuid)\n\n"
                    }

                    continuation?.resume(returning: result)
                    continuation = nil
                }
            }

            let _ = Scanner(duration: duration, continuation: continuation)
        }
    }
}
