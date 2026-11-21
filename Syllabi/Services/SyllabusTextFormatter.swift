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

    static func display(_ text: String) -> String {
        var result = text
        for (latex, symbol) in symbols {
            result = result.replacingOccurrences(of: latex, with: symbol)
        }
        return result
            .replacingOccurrences(of: "\\(", with: "")
            .replacingOccurrences(of: "\\)", with: "")
            .replacingOccurrences(of: "\\[", with: "")
            .replacingOccurrences(of: "\\]", with: "")
            .replacingOccurrences(of: "$", with: "")
    }
}
