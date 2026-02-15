import Foundation

// MARK: - Fetch Web Content
struct FetchWebContentTool: ClaudeTool {
    let name = "fetch_web_content"
    let description = "Fetch and extract text content from a webpage URL"
    let category = ToolCategory.webKit

    let parameters = [
        ToolParameter(name: "url", type: .string, description: "The URL to fetch content from", isRequired: true),
        ToolParameter(name: "max_length", type: .integer, description: "Maximum characters to return (default 2000)")
    ]

    let requiredParams = ["url"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let urlString = arguments["url"] as? String,
              let url = URL(string: urlString) else {
            throw ToolError.invalidArguments("Valid URL is required")
        }

        let maxLength = arguments["max_length"] as? Int ?? 2000

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ToolError.executionFailed("Invalid response from server")
        }

        guard httpResponse.statusCode == 200 else {
            throw ToolError.executionFailed("HTTP \(httpResponse.statusCode)")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ToolError.executionFailed("Could not decode response")
        }

        // Basic HTML to text extraction
        let text = extractTextFromHTML(html)
        let trimmed = String(text.prefix(maxLength))

        var result = "Web Content from \(url.host ?? urlString):\n"
        result += "- URL: \(urlString)\n"
        result += "- Status: \(httpResponse.statusCode)\n"
        result += "- Content Length: \(html.count) chars\n\n"
        result += trimmed
        if text.count > maxLength {
            result += "\n\n... (truncated, \(text.count - maxLength) more characters)"
        }

        return result
    }

    private func extractTextFromHTML(_ html: String) -> String {
        var text = html

        // Remove script and style blocks
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)

        // Replace common block elements with newlines
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n")
        text = text.replacingOccurrences(of: "</div>", with: "\n")
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</li>", with: "\n")

        // Remove all remaining HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")

        // Clean up whitespace
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
