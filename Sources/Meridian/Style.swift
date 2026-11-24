import AppKit
import SwiftUI

/// Paper and ink for everything around the hours, as in the iOS app; the hours themselves take `Sky` colours.
enum Palette {
    static let paper = adaptive(0xF2EFE8, 0x141412)
    static let ink = adaptive(0x141412, 0xF2EFE8)
    static let secondary = ink.opacity(0.7)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { NSColor(Color(hex: $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)) })
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

/// Meridian's time, as in the iOS app: heavy hours beside light minutes, set in compressed digits.
struct Numerals: View {
    /// "9:41" or "09:41".
    let time: String
    var period: String?
    let size: CGFloat

    var body: some View {
        let parts = time.split(separator: ":", maxSplits: 1).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: size * 0.05) {
            Text(parts.first ?? time).fontWeight(.heavy)
            // Light minutes go spindly at small sizes.
            if parts.count == 2 { Text(parts[1]).fontWeight(size < 28 ? .regular : .light) }
            if let period { Text(period).font(.system(size: max(size * 0.3, 9), weight: .semibold)).padding(.leading, size * 0.05) }
        }
        .font(.system(size: size))
        .fontWidth(.compressed)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

extension View {
    /// Small tracked capitals for city names and offsets.
    func caps(_ size: CGFloat = 11) -> some View {
        font(.system(size: size, weight: .semibold)).tracking(size * 0.12).textCase(.uppercase).lineLimit(1)
    }

    /// A hairline in the hour's text colour, so night hours show on a dark background and midday ones on a yellow band.
    func skyEdge(_ text: Color, cornerRadius: CGFloat = 2) -> some View {
        modifier(SkyEdge(text: text, cornerRadius: cornerRadius))
    }
}

/// One device pixel wide, so it stays crisp on non-Retina screens.
private struct SkyEdge: ViewModifier {
    @Environment(\.displayScale) private var displayScale
    let text: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay { RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(text.opacity(0.2), lineWidth: 1 / displayScale) }
    }
}
