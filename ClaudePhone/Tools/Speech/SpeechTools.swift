import Foundation
import AVFoundation

// MARK: - Speak Text
struct SpeakTextTool: ClaudeTool {
    let name = "speak_text"
    let description = "Convert text to speech and speak it aloud using the device speaker"
    let category = ToolCategory.speech

    let parameters = [
        ToolParameter(name: "text", type: .string, description: "Text to speak aloud", isRequired: true),
        ToolParameter(name: "language", type: .string, description: "Language code (e.g. 'en-US', 'es-ES', 'fr-FR'). Default 'en-US'"),
        ToolParameter(name: "rate", type: .number, description: "Speech rate from 0.0 (slowest) to 1.0 (fastest). Default 0.5"),
        ToolParameter(name: "pitch", type: .number, description: "Voice pitch from 0.5 (low) to 2.0 (high). Default 1.0")
    ]

    let requiredParams = ["text"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String else {
            throw ToolError.invalidArguments("text is required")
        }

        let language = arguments["language"] as? String ?? "en-US"
        let rate = Float(arguments["rate"] as? Double ?? 0.5)
        let pitch = Float(arguments["pitch"] as? Double ?? 1.0)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, rate))
        utterance.pitchMultiplier = max(0.5, min(2.0, pitch))

        let synthesizer = AVSpeechSynthesizer()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            // FIXED: Add @unchecked Sendable for Swift 6 compatibility
            class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
                let continuation: CheckedContinuation<String, Error>
                let text: String

                init(continuation: CheckedContinuation<String, Error>, text: String) {
                    self.continuation = continuation
                    self.text = text
                }

                func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
                    continuation.resume(returning: "Spoke aloud: \"\(String(text.prefix(100)))\(text.count > 100 ? "..." : "")\"")
                }

                func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
                    continuation.resume(returning: "Speech was cancelled.")
                }
            }

            let delegate = SpeechDelegate(continuation: continuation, text: text)
            synthesizer.delegate = delegate
            // Keep a reference so ARC doesn't deallocate
            objc_setAssociatedObject(synthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            synthesizer.speak(utterance)
        }
    }
}
