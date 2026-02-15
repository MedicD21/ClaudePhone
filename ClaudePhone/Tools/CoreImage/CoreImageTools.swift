import Foundation
import CoreImage
import UIKit
import Photos

// MARK: - Apply Filter
struct ApplyFilterTool: ClaudeTool {
    let name = "apply_image_filter"
    let description = "Apply a Core Image filter to a photo (sepia, blur, noir, etc.)"
    let category = ToolCategory.coreImage

    let parameters = [
        ToolParameter(name: "photo_id", type: .string, description: "Photo local identifier to apply the filter to", isRequired: true),
        ToolParameter(name: "filter", type: .string, description: "Filter to apply", enumValues: ["sepia", "noir", "blur", "chrome", "fade", "instant", "sharpen", "vignette"], isRequired: true),
        ToolParameter(name: "intensity", type: .number, description: "Filter intensity from 0.0 to 1.0 (default 0.8)")
    ]

    let requiredParams = ["photo_id", "filter"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let photoId = arguments["photo_id"] as? String,
              let filterName = arguments["filter"] as? String else {
            throw ToolError.invalidArguments("photo_id and filter are required")
        }

        let intensity = arguments["intensity"] as? Double ?? 0.8

        let ciFilterName: String
        let filterParams: [String: Any]

        switch filterName.lowercased() {
        case "sepia":
            ciFilterName = "CISepiaTone"
            filterParams = [kCIInputIntensityKey: intensity]
        case "noir":
            ciFilterName = "CIPhotoEffectNoir"
            filterParams = [:]
        case "blur":
            ciFilterName = "CIGaussianBlur"
            filterParams = ["inputRadius": intensity * 20]
        case "chrome":
            ciFilterName = "CIPhotoEffectChrome"
            filterParams = [:]
        case "fade":
            ciFilterName = "CIPhotoEffectFade"
            filterParams = [:]
        case "instant":
            ciFilterName = "CIPhotoEffectInstant"
            filterParams = [:]
        case "sharpen":
            ciFilterName = "CISharpenLuminance"
            filterParams = ["inputSharpness": intensity * 2]
        case "vignette":
            ciFilterName = "CIVignette"
            filterParams = [kCIInputIntensityKey: intensity * 2, kCIInputRadiusKey: intensity * 3]
        default:
            throw ToolError.invalidArguments("Unknown filter: \(filterName)")
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photoId], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw ToolError.executionFailed("Photo not found with ID: \(photoId)")
        }

        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Void>) in
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

        guard let uiImage = image, let ciImage = CIImage(image: uiImage) else {
            throw ToolError.executionFailed("Could not load image for filtering")
        }

        guard let filter = CIFilter(name: ciFilterName) else {
            throw ToolError.executionFailed("Filter '\(ciFilterName)' not available")
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        for (key, value) in filterParams {
            filter.setValue(value, forKey: key)
        }

        guard let outputImage = filter.outputImage else {
            throw ToolError.executionFailed("Filter produced no output")
        }

        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else {
            throw ToolError.executionFailed("Could not create output image")
        }

        let filteredImage = UIImage(cgImage: cgImage)

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: filteredImage)
        }

        return """
        Filter applied successfully:
        - Filter: \(filterName)
        - Intensity: \(String(format: "%.1f", intensity))
        - Original: \(asset.pixelWidth)x\(asset.pixelHeight)
        - Saved as new photo in library
        """
    }
}

// MARK: - Generate QR Code
struct GenerateQRCodeTool: ClaudeTool {
    let name = "generate_qr_code"
    let description = "Generate a QR code image from text or URL and save to photo library"
    let category = ToolCategory.coreImage

    let parameters = [
        ToolParameter(name: "content", type: .string, description: "Text or URL to encode in the QR code", isRequired: true),
        ToolParameter(name: "size", type: .integer, description: "Output size in pixels (default 512)")
    ]

    let requiredParams = ["content"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let content = arguments["content"] as? String else {
            throw ToolError.invalidArguments("content is required")
        }

        let size = arguments["size"] as? Int ?? 512

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw ToolError.executionFailed("QR code generator not available")
        }

        filter.setValue(Data(content.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            throw ToolError.executionFailed("Failed to generate QR code")
        }

        let scaleX = CGFloat(size) / outputImage.extent.width
        let scaleY = CGFloat(size) / outputImage.extent.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ToolError.executionFailed("Failed to render QR code image")
        }

        let uiImage = UIImage(cgImage: cgImage)

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }

        return """
        QR Code generated and saved:
        - Content: \(String(content.prefix(100)))\(content.count > 100 ? "..." : "")
        - Size: \(size)x\(size) pixels
        - Saved to photo library
        """
    }
}
