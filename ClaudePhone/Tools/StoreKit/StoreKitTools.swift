import Foundation
import StoreKit

// MARK: - Get Product Info
struct GetProductInfoTool: ClaudeTool {
    let name = "get_product_info"
    let description = "Get information about in-app purchase products by their identifiers"
    let category = ToolCategory.storeKit

    let parameters = [
        ToolParameter(name: "product_ids", type: .array, description: "Array of product identifier strings to look up", isRequired: true)
    ]

    let requiredParams = ["product_ids"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let productIds = arguments["product_ids"] as? [String] else {
            throw ToolError.invalidArguments("product_ids array is required")
        }

        let products = try await Product.products(for: Set(productIds))

        if products.isEmpty {
            return "No products found for the given identifiers: \(productIds.joined(separator: ", "))"
        }

        var result = "Product Information (\(products.count)):\n\n"

        for (i, product) in products.enumerated() {
            result += "\(i + 1). \(product.displayName)\n"
            result += "   ID: \(product.id)\n"
            result += "   Price: \(product.displayPrice)\n"
            result += "   Description: \(product.description)\n"

            switch product.type {
            case .consumable: result += "   Type: Consumable\n"
            case .nonConsumable: result += "   Type: Non-Consumable\n"
            case .autoRenewable: result += "   Type: Auto-Renewable Subscription\n"
            case .nonRenewable: result += "   Type: Non-Renewing Subscription\n"
            default: result += "   Type: Unknown\n"
            }

            if let subscription = product.subscription {
                result += "   Period: \(subscription.subscriptionPeriod.displayDescription)\n"
            }

            result += "\n"
        }

        return result
    }
}

extension Product.SubscriptionPeriod {
    var displayDescription: String {
        switch unit {
        case .day: return value == 1 ? "Daily" : "Every \(value) days"
        case .week: return value == 1 ? "Weekly" : "Every \(value) weeks"
        case .month: return value == 1 ? "Monthly" : "Every \(value) months"
        case .year: return value == 1 ? "Yearly" : "Every \(value) years"
        @unknown default: return "\(value) units"
        }
    }
}
