import Foundation
import CoreLocation
import MapKit

// MARK: - Location Manager Helper
private class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() async throws -> CLLocation {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else {
            throw ToolError.permissionDenied("Location access denied. Please enable in Settings.")
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: ToolError.executionFailed("Location error: \(error.localizedDescription)"))
        continuation = nil
    }
}

// MARK: - Get Current Location
struct GetCurrentLocationTool: ClaudeTool {
    let name = "get_current_location"
    let description = "Get the user's current GPS location with coordinates and address"
    let category = ToolCategory.location

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let helper = LocationHelper()
        let location = try await helper.requestLocation()

        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        let placemark = placemarks?.first

        var result = "Current Location:\n"
        result += "- Latitude: \(String(format: "%.6f", location.coordinate.latitude))\n"
        result += "- Longitude: \(String(format: "%.6f", location.coordinate.longitude))\n"
        result += "- Altitude: \(String(format: "%.1f", location.altitude))m\n"
        result += "- Accuracy: \(String(format: "%.1f", location.horizontalAccuracy))m\n"

        if let pm = placemark {
            var addressParts: [String] = []
            if let street = pm.thoroughfare { addressParts.append(street) }
            if let subLocality = pm.subLocality { addressParts.append(subLocality) }
            if let city = pm.locality { addressParts.append(city) }
            if let state = pm.administrativeArea { addressParts.append(state) }
            if let zip = pm.postalCode { addressParts.append(zip) }
            if let country = pm.country { addressParts.append(country) }

            if !addressParts.isEmpty {
                result += "- Address: \(addressParts.joined(separator: ", "))\n"
            }
        }

        return result
    }
}

// MARK: - Search Nearby Places
struct SearchNearbyPlacesTool: ClaudeTool {
    let name = "search_nearby_places"
    let description = "Search for places, businesses, or points of interest near a location"
    let category = ToolCategory.location

    let parameters = [
        ToolParameter(name: "query", type: .string, description: "Search query (e.g. 'coffee shop', 'gas station', 'pharmacy')", isRequired: true),
        ToolParameter(name: "latitude", type: .number, description: "Latitude to search near (uses current location if omitted)"),
        ToolParameter(name: "longitude", type: .number, description: "Longitude to search near"),
        ToolParameter(name: "radius", type: .number, description: "Search radius in meters (default 1000)")
    ]

    let requiredParams = ["query"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("query is required")
        }

        let radius = arguments["radius"] as? Double ?? 1000

        let coordinate: CLLocationCoordinate2D
        if let lat = arguments["latitude"] as? Double, let lon = arguments["longitude"] as? Double {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            let helper = LocationHelper()
            let location = try await helper.requestLocation()
            coordinate = location.coordinate
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        if response.mapItems.isEmpty {
            return "No places found matching '\(query)' nearby."
        }

        var result = "Found \(response.mapItems.count) place(s) for '\(query)':\n\n"
        for (i, item) in response.mapItems.prefix(10).enumerated() {
            result += "\(i + 1). \(item.name ?? "Unknown")\n"

            if let phone = item.phoneNumber {
                result += "   Phone: \(phone)\n"
            }

            if let address = item.placemark.title {
                result += "   Address: \(address)\n"
            }

            let itemLat = item.placemark.coordinate.latitude
            let itemLon = item.placemark.coordinate.longitude
            let itemLocation = CLLocation(latitude: itemLat, longitude: itemLon)
            let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = userLocation.distance(from: itemLocation)

            if distance < 1000 {
                result += "   Distance: \(Int(distance))m\n"
            } else {
                result += "   Distance: \(String(format: "%.1f", distance / 1000))km\n"
            }

            result += "\n"
        }

        return result
    }
}

// MARK: - Get Directions
struct GetDirectionsTool: ClaudeTool {
    let name = "get_directions"
    let description = "Get directions and estimated travel time between two locations"
    let category = ToolCategory.location

    let parameters = [
        ToolParameter(name: "destination", type: .string, description: "Destination address or place name", isRequired: true),
        ToolParameter(name: "transport_type", type: .string, description: "Transport type", enumValues: ["driving", "walking", "transit"])
    ]

    let requiredParams = ["destination"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let destination = arguments["destination"] as? String else {
            throw ToolError.invalidArguments("destination is required")
        }

        let transportType = arguments["transport_type"] as? String ?? "driving"

        // Get current location
        let helper = LocationHelper()
        let currentLocation = try await helper.requestLocation()

        // Geocode destination
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(destination)
        guard let destPlacemark = placemarks.first, let destLocation = destPlacemark.location else {
            throw ToolError.executionFailed("Could not find location: \(destination)")
        }

        // Get directions
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destLocation.coordinate))

        switch transportType {
        case "walking": request.transportType = .walking
        case "transit": request.transportType = .transit
        default: request.transportType = .automobile
        }

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            return "No route found to \(destination)."
        }

        let distanceKm = route.distance / 1000
        let travelMinutes = Int(route.expectedTravelTime / 60)
        let hours = travelMinutes / 60
        let minutes = travelMinutes % 60

        var timeString: String
        if hours > 0 {
            timeString = "\(hours)h \(minutes)min"
        } else {
            timeString = "\(minutes)min"
        }

        var result = "Directions to \(destination):\n"
        result += "- Distance: \(String(format: "%.1f", distanceKm)) km\n"
        result += "- Estimated time: \(timeString)\n"
        result += "- Transport: \(transportType)\n\n"

        result += "Steps:\n"
        for (i, step) in route.steps.enumerated() where !step.instructions.isEmpty {
            let stepDist = step.distance < 1000
                ? "\(Int(step.distance))m"
                : "\(String(format: "%.1f", step.distance / 1000))km"
            result += "\(i + 1). \(step.instructions) (\(stepDist))\n"
        }

        return result
    }
}

// MARK: - Reverse Geocode
struct ReverseGeocodeTool: ClaudeTool {
    let name = "reverse_geocode"
    let description = "Convert GPS coordinates to a human-readable address"
    let category = ToolCategory.location

    let parameters = [
        ToolParameter(name: "latitude", type: .number, description: "Latitude coordinate", isRequired: true),
        ToolParameter(name: "longitude", type: .number, description: "Longitude coordinate", isRequired: true)
    ]

    let requiredParams = ["latitude", "longitude"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let lat = arguments["latitude"] as? Double,
              let lon = arguments["longitude"] as? Double else {
            throw ToolError.invalidArguments("latitude and longitude are required")
        }

        let location = CLLocation(latitude: lat, longitude: lon)
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let pm = placemarks.first else {
            return "No address found for coordinates (\(lat), \(lon))."
        }

        var result = "Address for (\(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))):\n"
        if let name = pm.name { result += "- Name: \(name)\n" }
        if let street = pm.thoroughfare { result += "- Street: \(street)\n" }
        if let subLocality = pm.subLocality { result += "- Area: \(subLocality)\n" }
        if let city = pm.locality { result += "- City: \(city)\n" }
        if let state = pm.administrativeArea { result += "- State: \(state)\n" }
        if let zip = pm.postalCode { result += "- Postal Code: \(zip)\n" }
        if let country = pm.country { result += "- Country: \(country)\n" }

        return result
    }
}
