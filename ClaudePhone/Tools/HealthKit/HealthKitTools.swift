import Foundation
import HealthKit

private let healthStore = HKHealthStore()

private func requestHealthAccess(read: Set<HKObjectType>) async throws {
    guard HKHealthStore.isHealthDataAvailable() else {
        throw ToolError.executionFailed("HealthKit is not available on this device")
    }

    try await healthStore.requestAuthorization(toShare: [], read: read)
}

// MARK: - Get Step Count
struct GetStepCountTool: ClaudeTool {
    let name = "get_step_count"
    let description = "Get step count for today or a specified date range"
    let category = ToolCategory.health

    let parameters = [
        ToolParameter(name: "days_back", type: .integer, description: "Number of days back to fetch (default 1 for today)"),
        ToolParameter(name: "daily_breakdown", type: .boolean, description: "Show per-day breakdown (default false)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let stepType = HKQuantityType(.stepCount)
        try await requestHealthAccess(read: [stepType])

        let daysBack = arguments["days_back"] as? Int ?? 1
        let dailyBreakdown = arguments["daily_breakdown"] as? Bool ?? false
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: endDate))!

        if dailyBreakdown && daysBack > 1 {
            return try await fetchDailySteps(from: startDate, to: endDate, stepType: stepType)
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium

                let response = """
                Step Count:
                - Steps: \(Int(steps))
                - Period: \(dateFormatter.string(from: startDate)) to \(dateFormatter.string(from: endDate))
                """
                continuation.resume(returning: response)
            }
            healthStore.execute(query)
        }

        return result
    }

    private func fetchDailySteps(from startDate: Date, to endDate: Date, stepType: HKQuantityType) async throws -> String {
        let calendar = Calendar.current
        let interval = DateComponents(day: 1)
        let anchorDate = calendar.startOfDay(for: startDate)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d"

                var result = "Daily Step Count:\n\n"
                var totalSteps = 0.0

                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    totalSteps += steps
                    result += "  \(formatter.string(from: statistics.startDate)): \(Int(steps)) steps\n"
                }

                result += "\nTotal: \(Int(totalSteps)) steps"
                let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
                result += "\nDaily average: \(Int(totalSteps / Double(days))) steps"

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - Get Heart Rate
struct GetHeartRateTool: ClaudeTool {
    let name = "get_heart_rate"
    let description = "Get recent heart rate measurements"
    let category = ToolCategory.health

    let parameters = [
        ToolParameter(name: "limit", type: .integer, description: "Number of recent readings to fetch (default 10)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let heartRateType = HKQuantityType(.heartRate)
        try await requestHealthAccess(read: [heartRateType])

        let limit = arguments["limit"] as? Int ?? 10

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: "No heart rate data available.")
                    return
                }

                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short

                let unit = HKUnit.count().unitDivided(by: .minute())
                var result = "Recent Heart Rate Readings:\n\n"

                for sample in samples {
                    let bpm = Int(sample.quantity.doubleValue(for: unit))
                    result += "  \(formatter.string(from: sample.endDate)): \(bpm) BPM\n"
                }

                let bpmValues = samples.map { Int($0.quantity.doubleValue(for: unit)) }
                let avg = bpmValues.reduce(0, +) / bpmValues.count
                let min = bpmValues.min() ?? 0
                let max = bpmValues.max() ?? 0

                result += "\nSummary: Avg \(avg) BPM | Min \(min) BPM | Max \(max) BPM"

                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Get Workouts
struct GetWorkoutsTool: ClaudeTool {
    let name = "get_workouts"
    let description = "Get recent workout sessions with duration, calories, and distance"
    let category = ToolCategory.health

    let parameters = [
        ToolParameter(name: "limit", type: .integer, description: "Number of recent workouts (default 5)"),
        ToolParameter(name: "days_back", type: .integer, description: "Days to look back (default 7)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let workoutType = HKObjectType.workoutType()
        try await requestHealthAccess(read: [workoutType])

        let limit = arguments["limit"] as? Int ?? 5
        let daysBack = arguments["days_back"] as? Int ?? 7
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    continuation.resume(returning: "No workouts found in the last \(daysBack) days.")
                    return
                }

                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short

                var result = "Recent Workouts:\n\n"

                for (i, workout) in workouts.enumerated() {
                    let duration = Int(workout.duration / 60)
                    let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    let distance = workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0

                    result += "\(i + 1). \(workout.workoutActivityType.displayName)\n"
                    result += "   Date: \(formatter.string(from: workout.startDate))\n"
                    result += "   Duration: \(duration) min\n"
                    if calories > 0 { result += "   Calories: \(Int(calories)) kcal\n" }
                    if distance > 0 { result += "   Distance: \(String(format: "%.2f", distance)) km\n" }
                    result += "\n"
                }

                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Log Water Intake
struct LogWaterIntakeTool: ClaudeTool {
    let name = "log_water_intake"
    let description = "Log water intake in milliliters"
    let category = ToolCategory.health

    let parameters = [
        ToolParameter(name: "amount_ml", type: .number, description: "Amount of water in milliliters", isRequired: true)
    ]

    let requiredParams = ["amount_ml"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let amount = arguments["amount_ml"] as? Double else {
            throw ToolError.invalidArguments("amount_ml is required")
        }

        let waterType = HKQuantityType(.dietaryWater)

        guard HKHealthStore.isHealthDataAvailable() else {
            throw ToolError.executionFailed("HealthKit is not available")
        }

        try await healthStore.requestAuthorization(toShare: [waterType], read: [waterType])

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amount)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())

        try await healthStore.save(sample)

        return "Logged \(Int(amount))ml of water (\(String(format: "%.1f", amount / 250)) glasses)."
    }
}

// MARK: - Get Sleep Analysis
struct GetSleepAnalysisTool: ClaudeTool {
    let name = "get_sleep_analysis"
    let description = "Get recent sleep data including duration and quality"
    let category = ToolCategory.health

    let parameters = [
        ToolParameter(name: "days_back", type: .integer, description: "Number of days to look back (default 7)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let sleepType = HKCategoryType(.sleepAnalysis)
        try await requestHealthAccess(read: [sleepType])

        let daysBack = arguments["days_back"] as? Int ?? 7
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: "No sleep data found in the last \(daysBack) days.")
                    return
                }

                let asleepSamples = samples.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }

                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d"
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short

                var result = "Sleep Analysis (Last \(daysBack) days):\n\n"

                var dailySleep: [String: Double] = [:]
                for sample in asleepSamples {
                    let dayKey = formatter.string(from: sample.startDate)
                    let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    dailySleep[dayKey, default: 0] += hours
                }

                for (day, hours) in dailySleep.sorted(by: { $0.key > $1.key }).prefix(daysBack) {
                    let h = Int(hours)
                    let m = Int((hours - Double(h)) * 60)
                    result += "  \(day): \(h)h \(m)m\n"
                }

                let totalHours = dailySleep.values.reduce(0, +)
                let avgHours = totalHours / Double(max(1, dailySleep.count))
                let avgH = Int(avgHours)
                let avgM = Int((avgHours - Double(avgH)) * 60)

                result += "\nAverage: \(avgH)h \(avgM)m per night"

                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Workout Activity Type Display Names
extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .dance: return "Dance"
        case .pilates: return "Pilates"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        default: return "Workout"
        }
    }
}
