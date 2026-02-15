import Foundation
import Vision
import UIKit

// MARK: - Recognize Text (OCR)
struct RecognizeTextTool: ClaudeTool {
    let name = "recognize_text"
    let description = "Perform OCR text recognition on an image from the photo library"
    let category = ToolCategory.vision

    let parameters = [
        ToolParameter(name: "photo_id", type: .string, description: "Photo local identifier to perform OCR on", isRequired: true),
        ToolParameter(name: "language", type: .string, description: "Recognition language (e.g., 'en-US'). Default auto-detect.")
    ]

    let requiredParams = ["photo_id"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let photoId = arguments["photo_id"] as? String else {
            throw ToolError.invalidArguments("photo_id is required")
        }

        guard let image = await loadImageFromPhotoLibrary(identifier: photoId) else {
            throw ToolError.executionFailed("Could not load image with ID: \(photoId)")
        }

        guard let cgImage = image.cgImage else {
            throw ToolError.executionFailed("Could not convert image to CGImage")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "No text found in the image.")
                    return
                }

                if observations.isEmpty {
                    continuation.resume(returning: "No text detected in the image.")
                    return
                }

                var recognizedText = ""
                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        recognizedText += topCandidate.string + "\n"
                    }
                }

                let result = """
                Text Recognition Results:
                - Characters detected: \(recognizedText.count)
                - Lines: \(observations.count)

                Recognized Text:
                \(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines))
                """
                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Classify Image
struct ClassifyImageTool: ClaudeTool {
    let name = "classify_image"
    let description = "Classify an image to identify its content using machine learning"
    let category = ToolCategory.vision

    let parameters = [
        ToolParameter(name: "photo_id", type: .string, description: "Photo local identifier to classify", isRequired: true)
    ]

    let requiredParams = ["photo_id"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let photoId = arguments["photo_id"] as? String else {
            throw ToolError.invalidArguments("photo_id is required")
        }

        guard let image = await loadImageFromPhotoLibrary(identifier: photoId) else {
            throw ToolError.executionFailed("Could not load image with ID: \(photoId)")
        }

        guard let cgImage = image.cgImage else {
            throw ToolError.executionFailed("Could not convert image to CGImage")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: "Could not classify the image.")
                    return
                }

                let topResults = observations
                    .filter { $0.confidence > 0.1 }
                    .prefix(10)

                if topResults.isEmpty {
                    continuation.resume(returning: "No strong classifications found for this image.")
                    return
                }

                var result = "Image Classification Results:\n\n"
                for (i, observation) in topResults.enumerated() {
                    let confidence = Int(observation.confidence * 100)
                    result += "\(i + 1). \(observation.identifier): \(confidence)%\n"
                }

                continuation.resume(returning: result)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Detect Faces
struct DetectFacesTool: ClaudeTool {
    let name = "detect_faces"
    let description = "Detect faces in a photo and get count, positions, and attributes"
    let category = ToolCategory.vision

    let parameters = [
        ToolParameter(name: "photo_id", type: .string, description: "Photo local identifier to analyze", isRequired: true)
    ]

    let requiredParams = ["photo_id"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let photoId = arguments["photo_id"] as? String else {
            throw ToolError.invalidArguments("photo_id is required")
        }

        guard let image = await loadImageFromPhotoLibrary(identifier: photoId) else {
            throw ToolError.executionFailed("Could not load image with ID: \(photoId)")
        }

        guard let cgImage = image.cgImage else {
            throw ToolError.executionFailed("Could not convert image to CGImage")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: "No faces detected.")
                    return
                }

                if observations.isEmpty {
                    continuation.resume(returning: "No faces detected in this image.")
                    return
                }

                var result = "Face Detection Results:\n"
                result += "- Faces found: \(observations.count)\n\n"

                for (i, face) in observations.enumerated() {
                    let bbox = face.boundingBox
                    result += "Face \(i + 1):\n"
                    result += "  Position: (\(String(format: "%.1f", bbox.origin.x * 100))%, \(String(format: "%.1f", bbox.origin.y * 100))%)\n"
                    result += "  Size: \(String(format: "%.1f", bbox.width * 100))% x \(String(format: "%.1f", bbox.height * 100))%\n"
                    result += "  Confidence: \(String(format: "%.0f", face.confidence * 100))%\n"

                    if let yaw = face.yaw {
                        result += "  Yaw: \(String(format: "%.1f", yaw.doubleValue * 180 / .pi)) degrees\n"
                    }
                    if let roll = face.roll {
                        result += "  Roll: \(String(format: "%.1f", roll.doubleValue * 180 / .pi)) degrees\n"
                    }

                    result += "\n"
                }

                continuation.resume(returning: result)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Shared Image Loading Helper
import Photos

private func loadImageFromPhotoLibrary(identifier: String) async -> UIImage? {
    let results = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
    guard let asset = results.firstObject else { return nil }

    return await withCheckedContinuation { continuation in
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1024, height: 1024),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            continuation.resume(returning: image)
        }
    }
}
