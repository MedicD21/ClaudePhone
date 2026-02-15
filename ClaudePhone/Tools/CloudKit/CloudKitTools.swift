import Foundation
import CloudKit

private let container = CKContainer.default()
private let privateDB = CKContainer.default().privateCloudDatabase

// MARK: - Save Cloud Record
struct SaveCloudRecordTool: ClaudeTool {
    let name = "save_cloud_record"
    let description = "Save a key-value record to iCloud using CloudKit"
    let category = ToolCategory.cloudKit

    let parameters = [
        ToolParameter(name: "record_type", type: .string, description: "Type/category of the record (e.g., 'Note', 'Bookmark')", isRequired: true),
        ToolParameter(name: "fields", type: .object, description: "Key-value pairs to store in the record", isRequired: true)
    ]

    let requiredParams = ["record_type", "fields"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let recordType = arguments["record_type"] as? String,
              let fields = arguments["fields"] as? [String: Any] else {
            throw ToolError.invalidArguments("record_type and fields are required")
        }

        let record = CKRecord(recordType: recordType)

        for (key, value) in fields {
            if let stringValue = value as? String {
                record[key] = stringValue as CKRecordValue
            } else if let intValue = value as? Int {
                record[key] = intValue as CKRecordValue
            } else if let doubleValue = value as? Double {
                record[key] = doubleValue as CKRecordValue
            } else if let boolValue = value as? Bool {
                record[key] = (boolValue ? 1 : 0) as CKRecordValue
            }
        }

        let savedRecord = try await privateDB.save(record)

        var result = "CloudKit record saved:\n"
        result += "- Type: \(recordType)\n"
        result += "- Record ID: \(savedRecord.recordID.recordName)\n"
        result += "- Fields: \(fields.keys.joined(separator: ", "))\n"
        result += "- Saved at: \(Date())"

        return result
    }
}

// MARK: - Fetch Cloud Records
struct FetchCloudRecordsTool: ClaudeTool {
    let name = "fetch_cloud_records"
    let description = "Fetch records from iCloud CloudKit by type"
    let category = ToolCategory.cloudKit

    let parameters = [
        ToolParameter(name: "record_type", type: .string, description: "Type of records to fetch", isRequired: true),
        ToolParameter(name: "limit", type: .integer, description: "Maximum records to return (default 10)")
    ]

    let requiredParams = ["record_type"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let recordType = arguments["record_type"] as? String else {
            throw ToolError.invalidArguments("record_type is required")
        }

        let limit = arguments["limit"] as? Int ?? 10

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let (matchResults, _) = try await privateDB.records(matching: query, resultsLimit: limit)

        let records = matchResults.compactMap { try? $0.1.get() }

        if records.isEmpty {
            return "No '\(recordType)' records found in iCloud."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var result = "CloudKit Records (\(records.count) '\(recordType)'):\n\n"

        for (i, record) in records.enumerated() {
            result += "\(i + 1). Record: \(record.recordID.recordName)\n"

            if let created = record.creationDate {
                result += "   Created: \(dateFormatter.string(from: created))\n"
            }

            for key in record.allKeys() {
                if let value = record[key] {
                    result += "   \(key): \(value)\n"
                }
            }
            result += "\n"
        }

        return result
    }
}
