import Foundation
import Network
import SystemConfiguration.CaptiveNetwork

// MARK: - Get Network Status
struct GetNetworkStatusTool: ClaudeTool {
    let name = "get_network_status"
    let description = "Get the current network connectivity status"
    let category = ToolCategory.network

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "network.monitor")

            monitor.pathUpdateHandler = { path in
                monitor.cancel()

                var result = "Network Status:\n"
                result += "- Connected: \(path.status == .satisfied ? "Yes" : "No")\n"

                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        result += "- Type: WiFi\n"
                    } else if path.usesInterfaceType(.cellular) {
                        result += "- Type: Cellular\n"
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        result += "- Type: Ethernet\n"
                    }

                    result += "- Expensive: \(path.isExpensive ? "Yes" : "No")\n"
                    result += "- Constrained: \(path.isConstrained ? "Yes" : "No")\n"
                    result += "- Supports DNS: \(path.supportsDNS ? "Yes" : "No")\n"
                    result += "- Supports IPv4: \(path.supportsIPv4 ? "Yes" : "No")\n"
                    result += "- Supports IPv6: \(path.supportsIPv6 ? "Yes" : "No")\n"
                } else if path.status == .unsatisfied {
                    result += "- Reason: No network connection\n"
                } else {
                    result += "- Reason: Network path requires connection\n"
                }

                continuation.resume(returning: result)
            }

            monitor.start(queue: queue)

            // Timeout after 5 seconds
            queue.asyncAfter(deadline: .now() + 5) {
                monitor.cancel()
                continuation.resume(returning: "Network status check timed out.")
            }
        }
    }
}

// MARK: - Get WiFi Info
struct GetWiFiInfoTool: ClaudeTool {
    let name = "get_wifi_info"
    let description = "Get information about the current WiFi connection"
    let category = ToolCategory.network

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
            let queue = DispatchQueue(label: "wifi.monitor")

            monitor.pathUpdateHandler = { path in
                monitor.cancel()

                if path.status != .satisfied {
                    continuation.resume(returning: "Not connected to WiFi.")
                    return
                }

                var result = "WiFi Connection:\n"
                result += "- Status: Connected\n"
                result += "- Expensive: \(path.isExpensive ? "Yes (possibly hotspot)" : "No")\n"
                result += "- Constrained: \(path.isConstrained ? "Yes (Low Data Mode)" : "No")\n"

                for interface in path.availableInterfaces where interface.type == .wifi {
                    result += "- Interface: \(interface.name)\n"
                }

                continuation.resume(returning: result)
            }

            monitor.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 5) {
                monitor.cancel()
                continuation.resume(returning: "WiFi status check timed out.")
            }
        }
    }
}
