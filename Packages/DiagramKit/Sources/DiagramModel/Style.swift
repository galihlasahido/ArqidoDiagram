import Foundation

public struct ShadowStyle: Codable, Hashable, Sendable {
    public var color: ColorRef
    public var radius: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(color: ColorRef, radius: Double, offsetX: Double = 0, offsetY: Double = 0) {
        self.color = color
        self.radius = radius
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

public enum FontWeight: String, Codable, Sendable {
    case regular, medium, semibold, bold
}

public enum TextAlignment: String, Codable, Sendable {
    case leading, center, trailing
}

public struct FontStyle: Codable, Hashable, Sendable {
    public var size: Double
    public var weight: FontWeight
    public var alignment: TextAlignment

    public init(size: Double = 13, weight: FontWeight = .regular, alignment: TextAlignment = .center) {
        self.size = size
        self.weight = weight
        self.alignment = alignment
    }
}

public struct ShapeStyle: Codable, Hashable, Sendable {
    public var fill: ColorRef?
    public var strokeColor: ColorRef?
    public var strokeWidth: Double
    public var opacity: Double
    public var cornerRadius: Double
    public var shadow: ShadowStyle?
    public var font: FontStyle?

    public init(
        fill: ColorRef? = nil,
        strokeColor: ColorRef? = nil,
        strokeWidth: Double = 1,
        opacity: Double = 1,
        cornerRadius: Double = 0,
        shadow: ShadowStyle? = nil,
        font: FontStyle? = nil
    ) {
        self.fill = fill
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.font = font
    }
}

public enum ArrowheadStyle: String, Codable, Sendable, CaseIterable {
    case none, open, filled, diamond, circle
}

public enum LineDashStyle: String, Codable, Sendable, CaseIterable {
    case solid, dashed, dotted
}

public struct LineStyle: Codable, Hashable, Sendable {
    public var strokeColor: ColorRef?
    public var strokeWidth: Double
    public var dash: LineDashStyle
    public var startArrow: ArrowheadStyle
    public var endArrow: ArrowheadStyle

    public init(
        strokeColor: ColorRef? = nil,
        strokeWidth: Double = 1,
        dash: LineDashStyle = .solid,
        startArrow: ArrowheadStyle = .none,
        endArrow: ArrowheadStyle = .open
    ) {
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.dash = dash
        self.startArrow = startArrow
        self.endArrow = endArrow
    }
}
