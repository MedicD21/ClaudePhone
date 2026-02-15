import Foundation
import CoreMotion

private let motionManager = CMMotionManager()
private let pedometer = CMPedometer()

// MARK: - Get Motion Data
struct GetMotionDataTool: ClaudeTool {
    let name = "get_motion_data"
    let description = "Get current device motion data including accelerometer, gyroscope, and attitude"
    let category = ToolCategory.motion

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        guard motionManager.isDeviceMotionAvailable else {
            throw ToolError.executionFailed("Device motion is not available")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                motionManager.stopDeviceMotionUpdates()

                if let error = error {
                    continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
                    return
                }

                guard let motion = motion else {
                    continuation.resume(throwing: ToolError.executionFailed("No motion data"))
                    return
                }

                let result = """
                Device Motion Data:

                Attitude (orientation):
                - Pitch: \(String(format: "%.2f", motion.attitude.pitch * 180 / .pi)) degrees
                - Roll: \(String(format: "%.2f", motion.attitude.roll * 180 / .pi)) degrees
                - Yaw: \(String(format: "%.2f", motion.attitude.yaw * 180 / .pi)) degrees

                Acceleration (user, excluding gravity):
                - X: \(String(format: "%.4f", motion.userAcceleration.x)) g
                - Y: \(String(format: "%.4f", motion.userAcceleration.y)) g
                - Z: \(String(format: "%.4f", motion.userAcceleration.z)) g

                Gravity:
                - X: \(String(format: "%.4f", motion.gravity.x)) g
                - Y: \(String(format: "%.4f", motion.gravity.y)) g
                - Z: \(String(format: "%.4f", motion.gravity.z)) g

                Rotation Rate:
                - X: \(String(format: "%.4f", motion.rotationRate.x)) rad/s
                - Y: \(String(format: "%.4f", motion.rotationRate.y)) rad/s
                - Z: \(String(format: "%.4f", motion.rotationRate.z)) rad/s

                Magnetic Field:
                - X: \(String(format: "%.2f", motion.magneticField.field.x)) microtesla
                - Y: \(String(format: "%.2f", motion.magneticField.field.y)) microtesla
                - Z: \(String(format: "%.2f", motion.magneticField.field.z)) microtesla
                """
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Get Pedometer Data
struct GetPedometerDataTool: ClaudeTool {
    let name = "get_pedometer_data"
    let description = "Get pedometer data including steps, distance, and floors for today"
    let category = ToolCategory.motion

    let parameters = [
        ToolParameter(name: "days_back", type: .integer, description: "Number of days back (default 1 for today)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        guard CMPedometer.isStepCountingAvailable() else {
            throw ToolError.executionFailed("Step counting is not available on this device")
        }

        let daysBack = arguments["days_back"] as? Int ?? 1
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: Date()))!
        let endDate = Date()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            pedometer.queryPedometerData(from: startDate, to: endDate) { data, error in
                if let error = error {
                    continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
                    return
                }

                guard let data = data else {
                    continuation.resume(returning: "No pedometer data available.")
                    return
                }

                var result = "Pedometer Data:\n"
                result += "- Steps: \(data.numberOfSteps)\n"

                if let distance = data.distance {
                    let km = distance.doubleValue / 1000
                    result += "- Distance: \(String(format: "%.2f", km)) km\n"
                }

                if let floors = data.floorsAscended {
                    result += "- Floors Ascended: \(floors)\n"
                }
                if let floorsDesc = data.floorsDescended {
                    result += "- Floors Descended: \(floorsDesc)\n"
                }

                if let pace = data.currentPace {
                    let minPerKm = pace.doubleValue / 60
                    result += "- Current Pace: \(String(format: "%.1f", minPerKm)) min/km\n"
                }

                if let cadence = data.currentCadence {
                    result += "- Current Cadence: \(cadence) steps/sec\n"
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                result += "\nPeriod: \(dateFormatter.string(from: startDate)) to \(dateFormatter.string(from: endDate))"

                continuation.resume(returning: result)
            }
        }
    }
}
