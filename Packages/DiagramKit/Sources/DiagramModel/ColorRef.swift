import Foundation

/// Colors are stored as sRGB components, never as a platform color type
/// directly — `NSColor` isn't a safe `Codable` persisted value. The UI layer
/// maps `ColorRef <-> Color(nsColor:)` / `NSColor` only at its boundary, per
/// the "system-dynamic colors only" visual style rule: for shape-category or
/// criticality color coding, `.system(_:)` resolves a small set of distinct
/// `NSColor.system*` tokens to components at creation time rather than the
/// app inventing a custom hex palette.
public struct ColorRef: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Names of the small set of distinct `NSColor.system*` tokens used for
/// shape-category / criticality color coding. Resolved to `ColorRef`
/// components by the UI layer (which owns the `NSColor` import) — kept here
/// only as a stable, Codable-safe token so the model layer never imports
/// AppKit.
public enum SystemColorToken: String, Codable, Sendable, CaseIterable {
    case systemBlue, systemTeal, systemOrange, systemPink
    case systemIndigo, systemGray, systemBrown, systemGreen
    case systemRed, systemYellow, systemPurple, systemMint
}
