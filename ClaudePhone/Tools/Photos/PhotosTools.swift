import Foundation
import Photos

private func requestPhotoAccess() async throws {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .notDetermined {
        let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if granted != .authorized && granted != .limited {
            throw ToolError.permissionDenied("Photo library access denied")
        }
    } else if status == .denied || status == .restricted {
        throw ToolError.permissionDenied("Photo library access is restricted. Please enable in Settings.")
    }
}

// MARK: - Fetch Recent Photos
struct FetchRecentPhotosTool: ClaudeTool {
    let name = "fetch_recent_photos"
    let description = "Get information about recent photos in the library"
    let category = ToolCategory.photos

    let parameters = [
        ToolParameter(name: "limit", type: .integer, description: "Number of recent photos to fetch (default 10)"),
        ToolParameter(name: "media_type", type: .string, description: "Filter by media type", enumValues: ["photo", "video", "all"])
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestPhotoAccess()

        let limit = arguments["limit"] as? Int ?? 10
        let mediaType = arguments["media_type"] as? String ?? "all"

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit

        let results: PHFetchResult<PHAsset>
        switch mediaType {
        case "photo":
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        case "video":
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            results = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        default:
            results = PHAsset.fetchAssets(with: fetchOptions)
        }

        if results.count == 0 {
            return "No \(mediaType == "all" ? "media" : mediaType)s found in the library."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var response = "Recent \(mediaType == "all" ? "media" : mediaType)s (\(results.count)):\n\n"

        results.enumerateObjects { asset, index, _ in
            let type = asset.mediaType == .image ? "Photo" : (asset.mediaType == .video ? "Video" : "Other")
            response += "\(index + 1). \(type)"

            if let date = asset.creationDate {
                response += " - \(dateFormatter.string(from: date))"
            }

            response += "\n   Size: \(asset.pixelWidth) x \(asset.pixelHeight)"

            if asset.mediaType == .video {
                let duration = Int(asset.duration)
                let min = duration / 60
                let sec = duration % 60
                response += " | Duration: \(min):\(String(format: "%02d", sec))"
            }

            if asset.isFavorite {
                response += " | Favorite"
            }

            if let location = asset.location {
                response += "\n   Location: \(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))"
            }

            response += "\n   ID: \(asset.localIdentifier)\n\n"
        }

        return response
    }
}

// MARK: - Search Photos
struct SearchPhotosTool: ClaudeTool {
    let name = "search_photos"
    let description = "Search photos by date range, location, or favorites"
    let category = ToolCategory.photos

    let parameters = [
        ToolParameter(name: "start_date", type: .string, description: "Start date in yyyy-MM-dd format"),
        ToolParameter(name: "end_date", type: .string, description: "End date in yyyy-MM-dd format"),
        ToolParameter(name: "favorites_only", type: .boolean, description: "Only return favorited photos"),
        ToolParameter(name: "limit", type: .integer, description: "Maximum results (default 10)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestPhotoAccess()

        let limit = arguments["limit"] as? Int ?? 10
        let favoritesOnly = arguments["favorites_only"] as? Bool ?? false

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit

        var predicates: [NSPredicate] = []

        if favoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if let startStr = arguments["start_date"] as? String, let startDate = dateFormatter.date(from: startStr) {
            predicates.append(NSPredicate(format: "creationDate >= %@", startDate as NSDate))
        }

        if let endStr = arguments["end_date"] as? String, let endDate = dateFormatter.date(from: endStr) {
            let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
            predicates.append(NSPredicate(format: "creationDate < %@", dayAfter as NSDate))
        }

        if !predicates.isEmpty {
            fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        if results.count == 0 {
            return "No photos found matching the criteria."
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        var response = "Found \(results.count) photo(s):\n\n"
        results.enumerateObjects { asset, index, _ in
            response += "\(index + 1). Photo"
            if let date = asset.creationDate {
                response += " - \(displayFormatter.string(from: date))"
            }
            response += "\n   \(asset.pixelWidth)x\(asset.pixelHeight)"
            if asset.isFavorite { response += " | Favorite" }
            response += "\n   ID: \(asset.localIdentifier)\n\n"
        }

        return response
    }
}

// MARK: - Get Photo Details
struct GetPhotoDetailsTool: ClaudeTool {
    let name = "get_photo_details"
    let description = "Get detailed metadata for a specific photo by its identifier"
    let category = ToolCategory.photos

    let parameters = [
        ToolParameter(name: "photo_id", type: .string, description: "Photo local identifier from a previous search", isRequired: true)
    ]

    let requiredParams = ["photo_id"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestPhotoAccess()

        guard let photoId = arguments["photo_id"] as? String else {
            throw ToolError.invalidArguments("photo_id is required")
        }

        let results = PHAsset.fetchAssets(withLocalIdentifiers: [photoId], options: nil)
        guard let asset = results.firstObject else {
            throw ToolError.executionFailed("Photo not found with ID: \(photoId)")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium

        var response = "Photo Details:\n"
        response += "- Type: \(asset.mediaType == .image ? "Photo" : "Video")\n"
        response += "- Dimensions: \(asset.pixelWidth) x \(asset.pixelHeight)\n"

        if let date = asset.creationDate {
            response += "- Created: \(dateFormatter.string(from: date))\n"
        }
        if let modified = asset.modificationDate {
            response += "- Modified: \(dateFormatter.string(from: modified))\n"
        }

        response += "- Favorite: \(asset.isFavorite ? "Yes" : "No")\n"
        response += "- Hidden: \(asset.isHidden ? "Yes" : "No")\n"
        response += "- Source: \(asset.sourceType == .typeUserLibrary ? "Camera Roll" : "Other")\n"

        if let location = asset.location {
            response += "- Location: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))\n"
            response += "- Altitude: \(String(format: "%.1f", location.altitude))m\n"
        }

        if asset.mediaType == .video {
            let duration = Int(asset.duration)
            response += "- Duration: \(duration / 60):\(String(format: "%02d", duration % 60))\n"
        }

        return response
    }
}
