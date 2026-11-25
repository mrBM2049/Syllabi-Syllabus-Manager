import Foundation

enum SyllabusTextFormatter {
    private static let symbols: [String: String] = [
        "\\delta": "δ", "\\Delta": "Δ", "\\alpha": "α", "\\beta": "β",
        "\\gamma": "γ", "\\Gamma": "Γ", "\\theta": "θ", "\\Theta": "Θ",
        "\\lambda": "λ", "\\Lambda": "Λ", "\\mu": "μ", "\\pi": "π",
        "\\sigma": "σ", "\\Sigma": "Σ", "\\omega": "ω", "\\Omega": "Ω",
        "\\infty": "∞", "\\leq": "≤", "\\geq": "≥", "\\neq": "≠",
        "\\times": "×", "\\cdot": "·"
    ]
    private static let delimiters = try! NSRegularExpression(
        pattern: #"(?<!\\)\$([^$\n]+)(?<!\\)\$|\\\((.+?)\\\)|\\\[(.+?)\\\]"#
    )
    private static let commands = try! NSRegularExpression(pattern: #"\\[A-Za-z]+"#)
    private static let scripts: [(NSRegularExpression, [Character: Character])] = [
        (try! NSRegularExpression(pattern: #"_(?:\{([A-Za-z0-9]+)\}|([A-Za-z0-9]))"#),
         Dictionary(uniqueKeysWithValues: zip("0123456789aehijklmnoprstuvx", "₀₁₂₃₄₅₆₇₈₉ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ"))),
        (try! NSRegularExpression(pattern: #"\^(?:\{([A-Za-z0-9]+)\}|([A-Za-z0-9]))"#),
         Dictionary(uniqueKeysWithValues: zip("0123456789in", "⁰¹²³⁴⁵⁶⁷⁸⁹ⁱⁿ")))
    ]

    static func display(_ text: String) -> String {
        let formatted = replacing(delimiters, in: text) { match in
            let expression = capture(in: text, match: match)
            // Keep dollar prices intact when they occur in ordinary prose.
            guard expression.first?.isNumber != true || expression.contains(where: { "=^_/".contains($0) }) else {
                return nil
            }
            return scripts.reduce(expression) { value, script in
                replacing(script.0, in: value) { scriptMatch in
                    let token = capture(in: value, match: scriptMatch)
                    let glyphs = token.compactMap { script.1[$0] }
                    return glyphs.count == token.count ? String(glyphs) : nil
                }
            }
        }
        return replacing(commands, in: formatted) { match in
            Range(match.range, in: formatted).flatMap { symbols[String(formatted[$0])] }
        }
    }

    private static func capture(in text: String, match: NSTextCheckingResult) -> String {
        for index in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: index), in: text) { return String(text[range]) }
        }
        return ""
    }

    private static func replacing(_ regex: NSRegularExpression, in text: String,
                                  with replacement: (NSTextCheckingResult) -> String?) -> String {
        let result = NSMutableString(string: text)
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            if let value = replacement(match) { result.replaceCharacters(in: match.range, with: value) }
        }
        return result as String
    }
}
