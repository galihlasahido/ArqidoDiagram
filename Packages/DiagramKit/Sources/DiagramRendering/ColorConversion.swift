import AppKit
import DiagramModel

/// `ColorRef <-> NSColor` conversion lives at the AppKit boundary only —
/// `DiagramModel` never imports AppKit — per the "system-dynamic colors,
/// never hardcoded hex" visual style rule. `public` so the app target's
/// Inspector (step 12) can convert at its own SwiftUI `Color` boundary too,
/// rather than re-deriving this logic.
extension NSColor {
    public convenience init(_ ref: ColorRef) {
        self.init(srgbRed: ref.red, green: ref.green, blue: ref.blue, alpha: ref.alpha)
    }
}

extension ColorRef {
    public init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.init(
            red: Double(converted.redComponent),
            green: Double(converted.greenComponent),
            blue: Double(converted.blueComponent),
            alpha: Double(converted.alphaComponent)
        )
    }

    /// Resolves a `SystemColorToken` to sRGB components via the real
    /// `NSColor.system*` value, rather than the model layer inventing its
    /// own hex approximations.
    public static func system(_ token: SystemColorToken) -> ColorRef {
        ColorRef(nsColor: token.nsColor)
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
