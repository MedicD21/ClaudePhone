import Foundation
import CoreNFC

// MARK: - Scan NFC Tag
struct ScanNFCTagTool: ClaudeTool {
    let name = "scan_nfc_tag"
    let description = "Scan a nearby NFC tag and read its contents"
    let category = ToolCategory.nfc

    let parameters = [
        ToolParameter(name: "message", type: .string, description: "Custom message to show on the NFC scanning UI")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw ToolError.executionFailed("NFC is not available on this device")
        }

        let message = arguments["message"] as? String ?? "Hold your iPhone near an NFC tag"

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            class NFCReader: NSObject, NFCNDEFReaderSessionDelegate {
                var continuation: CheckedContinuation<String, Error>?

                func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
                    let nfcError = error as! NFCReaderError
                    if nfcError.code != .readerSessionInvalidationErrorFirstNDEFTagRead &&
                       nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                        continuation?.resume(throwing: ToolError.executionFailed("NFC Error: \(error.localizedDescription)"))
                        continuation = nil
                    }
                }

                func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
                    var result = "NFC Tag Read Successfully:\n\n"

                    for (msgIndex, message) in messages.enumerated() {
                        result += "Message \(msgIndex + 1):\n"

                        for (recIndex, record) in message.records.enumerated() {
                            result += "  Record \(recIndex + 1):\n"
                            result += "    Type: \(String(data: record.type, encoding: .utf8) ?? "Unknown")\n"

                            if let payload = String(data: record.payload, encoding: .utf8) {
                                result += "    Payload: \(payload)\n"
                            } else {
                                result += "    Payload: \(record.payload.count) bytes (binary)\n"
                            }

                            result += "    Format: \(record.typeNameFormat.description)\n"
                        }
                    }

                    continuation?.resume(returning: result)
                    continuation = nil
                }
            }

            let reader = NFCReader()
            reader.continuation = continuation

            let session = NFCNDEFReaderSession(delegate: reader, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = message
            session.begin()

            // Keep reader alive
            objc_setAssociatedObject(session, "reader", reader, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// MARK: - TNF Description
extension NFCTypeNameFormat {
    var description: String {
        switch self {
        case .empty: return "Empty"
        case .nfcWellKnown: return "NFC Well-Known"
        case .media: return "Media"
        case .absoluteURI: return "Absolute URI"
        case .nfcExternal: return "NFC External"
        case .unknown: return "Unknown"
        case .unchanged: return "Unchanged"
        @unknown default: return "Other"
        }
    }
}
