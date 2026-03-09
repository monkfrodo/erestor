import SwiftUI

// MARK: - Vesper Dark Design System

enum DS {
    // MARK: Colors

    static let surface  = Color(hex: "1e1c1a")
    static let border   = Color(hex: "2a2725")
    static let muted    = Color(hex: "3d3733")
    static let dim      = Color(hex: "4a4540")
    static let subtle   = Color(hex: "6b5b50")
    static let text     = Color(hex: "b8a99d")
    static let bright   = Color(hex: "e0d5ca")

    static let green    = Color(hex: "4a9e69")
    static let blue     = Color(hex: "5b6d99")
    static let red      = Color(hex: "c25a4a")
    static let amber    = Color(hex: "c9a84c")

    static let greenDim = Color(hex: "4a9e69").opacity(0.08)
    static let blueDim  = Color(hex: "5b6d99").opacity(0.08)
    static let redDim   = Color(hex: "c25a4a").opacity(0.08)
    static let amberDim = Color(hex: "c9a84c").opacity(0.08)

    static let s2       = Color(hex: "242120")
    static let bg       = Color(hex: "1a1816")

    // MARK: Fonts

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
