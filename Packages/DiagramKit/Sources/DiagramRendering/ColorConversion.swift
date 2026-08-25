import AppKit
import DiagramModel

/// `ColorRef <-> NSColor` conversion lives at the AppKit boundary only —
/// `DiagramModel` never imports AppKit — per the "system-dynamic colors,
/// never hardcoded hex" visual style rule.
extension NSColor {
    convenience init(_ ref: ColorRef) {
        self.init(srgbRed: ref.red, green: ref.green, blue: ref.blue, alpha: ref.alpha)
    }
}

extension ColorRef {
    /// Resolves a `SystemColorToken` to sRGB components via the real
    /// `NSColor.system*` value, rather than the model layer inventing its
    /// own hex approximations.
    public static func system(_ token: SystemColorToken) -> ColorRef {
        let color = token.nsColor.usingColorSpace(.sRGB) ?? token.nsColor
        return ColorRef(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }
}

extension SystemColorToken {
    fileprivate var nsColor: NSColor {
        switch self {
        case .systemBlue: return .systemBlue
        case .systemTeal: return .systemTeal
        case .systemOrange: return .systemOrange
        case .systemPink: return .systemPink
        case .systemIndigo: return .systemIndigo
        case .systemGray: return .systemGray
        case .systemBrown: return .systemBrown
        case .systemGreen: return .systemGreen
        case .systemRed: return .systemRed
        case .systemYellow: return .systemYellow
        case .systemPurple: return .systemPurple
        case .systemMint: return .systemMint
        }
    }
}
