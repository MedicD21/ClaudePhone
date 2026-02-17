import Foundation
import NaturalLanguage

// MARK: - Analyze Sentiment
struct AnalyzeSentimentTool: ClaudeTool {
    let name = "analyze_sentiment"
    let description = "Analyze the sentiment (positive/negative/neutral) of a given text"
    let category = ToolCategory.naturalLanguage

    let parameters = [
        ToolParameter(name: "text", type: .string, description: "Text to analyze for sentiment", isRequired: true)
    ]

    let requiredParams = ["text"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String else {
            throw ToolError.invalidArguments("text is required")
        }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)

        let score = Double(sentiment?.rawValue ?? "0") ?? 0

        let label: String
        let description: String
        if score > 0.2 {
            label = "Positive"
            description = "The text expresses a positive sentiment."
        } else if score < -0.2 {
            label = "Negative"
            description = "The text expresses a negative sentiment."
        } else {
            label = "Neutral"
            description = "The text is relatively neutral in sentiment."
        }

        return """
        Sentiment Analysis:
        - Text: "\(String(text.prefix(100)))\(text.count > 100 ? "..." : "")"
        - Sentiment: \(label)
        - Score: \(String(format: "%.3f", score)) (range: -1.0 to 1.0)
        - \(description)
        """
    }
}

// MARK: - Detect Language
struct DetectLanguageTool: ClaudeTool {
    let name = "detect_language"
    let description = "Detect the dominant language of a given text"
    let category = ToolCategory.naturalLanguage

    let parameters = [
        ToolParameter(name: "text", type: .string, description: "Text to analyze for language", isRequired: true)
    ]

    let requiredParams = ["text"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String else {
            throw ToolError.invalidArguments("text is required")
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage else {
            return "Could not detect the language of the given text."
        }

        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)

        var result = "Language Detection:\n"
        result += "- Dominant Language: \(language.displayName)\n\n"

        if hypotheses.count > 1 {
            result += "Confidence Scores:\n"
            for (lang, confidence) in hypotheses.sorted(by: { $0.value > $1.value }) {
                result += "  \(lang.displayName): \(String(format: "%.1f", confidence * 100))%\n"
            }
        }

        return result
    }
}

// MARK: - Tokenize Text
struct TokenizeTextTool: ClaudeTool {
    let name = "tokenize_text"
    let description = "Tokenize text into words, sentences, or paragraphs"
    let category = ToolCategory.naturalLanguage

    let parameters = [
        ToolParameter(name: "text", type: .string, description: "Text to tokenize", isRequired: true),
        ToolParameter(name: "unit", type: .string, description: "Tokenization unit", enumValues: ["word", "sentence", "paragraph"])
    ]

    let requiredParams = ["text"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String else {
            throw ToolError.invalidArguments("text is required")
        }

        let unit = arguments["unit"] as? String ?? "word"

        let tokenUnit: NLTokenUnit
        switch unit {
        case "sentence": tokenUnit = .sentence
        case "paragraph": tokenUnit = .paragraph
        default: tokenUnit = .word
        }

        let tokenizer = NLTokenizer(unit: tokenUnit)
        tokenizer.string = text

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range]))
            return true
        }

        var result = "Tokenization (\(unit)s):\n"
        result += "- Input length: \(text.count) characters\n"
        result += "- \(unit.capitalized) count: \(tokens.count)\n\n"

        if tokenUnit == .word {
            result += "Tokens: \(tokens.prefix(50).joined(separator: ", "))"
            if tokens.count > 50 { result += "... (\(tokens.count - 50) more)" }
        } else {
            for (i, token) in tokens.prefix(20).enumerated() {
                result += "\(i + 1). \(token.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
            if tokens.count > 20 { result += "... (\(tokens.count - 20) more)" }
        }

        return result
    }
}

// MARK: - Extract Named Entities
struct ExtractEntitesTool: ClaudeTool {
    let name = "extract_entities"
    let description = "Extract named entities (people, places, organizations) from text"
    let category = ToolCategory.naturalLanguage

    let parameters = [
        ToolParameter(name: "text", type: .string, description: "Text to extract entities from", isRequired: true)
    ]

    let requiredParams = ["text"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let text = arguments["text"] as? String else {
            throw ToolError.invalidArguments("text is required")
        }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        var entities: [String: [String]] = [
            "People": [],
            "Places": [],
            "Organizations": []
        ]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag {
                let entity = String(text[range])
                switch tag {
                case .personalName:
                    if !entities["People"]!.contains(entity) { entities["People"]!.append(entity) }
                case .placeName:
                    if !entities["Places"]!.contains(entity) { entities["Places"]!.append(entity) }
                case .organizationName:
                    if !entities["Organizations"]!.contains(entity) { entities["Organizations"]!.append(entity) }
                default: break
                }
            }
            return true
        }

        var result = "Named Entity Extraction:\n"
        result += "- Input: \"\(String(text.prefix(80)))\(text.count > 80 ? "..." : "")\"\n\n"

        for (category, items) in entities where !items.isEmpty {
            result += "\(category): \(items.joined(separator: ", "))\n"
        }

        let totalEntities = entities.values.flatMap { $0 }.count
        if totalEntities == 0 {
            result += "No named entities detected."
        }

        return result
    }
}

// MARK: - Language Display Name
extension NLLanguage {
    var displayName: String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: rawValue) ?? rawValue
    }
}
