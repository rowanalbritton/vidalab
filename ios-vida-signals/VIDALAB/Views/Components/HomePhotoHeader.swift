import SwiftUI

/// Rowan's own photographs, shown full-bleed at the top of Today.
///
/// One is chosen each time the app launches, and never the same one twice
/// in a row, so opening the app feels like looking out of a different
/// window each time.
enum VidaHeroPhoto {
    static let names: [String] = (1...12).map { String(format: "Hero%02d", $0) }

    private static let lastKey = "vida.lastHeroPhoto"

    /// The photo for this launch.
    static let current: String = {
        let defaults = UserDefaults.standard
        let last = defaults.string(forKey: lastKey)
        let pick = names.filter { $0 != last }.randomElement() ?? names[0]
        defaults.set(pick, forKey: lastKey)
        return pick
    }()
}

/// An arch: straight sides and a fully rounded top, like a greenhouse or
/// conservatory window.
struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Today's photograph, framed as an arched window.
///
/// Vida's own take on a photo-led home screen: instead of a full-bleed image,
/// her photograph sits inside an arch, the shape of a greenhouse window,
/// labelled like a specimen in a field notebook ("Field note Nº 07"). The
/// bottom of the arch dissolves into the canvas so it never ends in a hard
/// line, and the greeting is set inside the window over a soft scrim.
struct ArchWindow<Overlay: View>: View {
    let photo: String
    var height: CGFloat = 470
    @ViewBuilder var overlay: Overlay

    @Environment(\.colorScheme) private var colorScheme

    private var noteNumber: String {
        let digits = photo.filter(\.isNumber)
        return "Nº " + (digits.isEmpty ? "01" : digits)
    }

    var body: some View {
        let fade = LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.7),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        ZStack(alignment: .bottomLeading) {
            Image(photo)
                .resizable()
                .scaledToFill()
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.05), location: 0),
                            .init(color: .black.opacity(0.12), location: 0.4),
                            .init(color: .black.opacity(0.5), location: 0.82),
                            .init(color: .black.opacity(0.35), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .accessibilityHidden(true)

            overlay
                .padding(.horizontal, 24)
                .padding(.bottom, height * 0.2)
        }
        .overlay(alignment: .top) {
            Text("FIELD NOTE \(noteNumber)")
                .font(Vida.sans(10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(OnPhoto.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.22), in: Capsule())
                .overlay { Capsule().strokeBorder(OnPhoto.primary.opacity(0.35), lineWidth: 0.6) }
                .padding(.top, 34)
                .accessibilityHidden(true)
        }
        .frame(height: height)
        .clipShape(ArchShape())
        .overlay {
            // A fine frame on the window, like the leading of a glasshouse.
            ArchShape()
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.18) : Vida.forest.opacity(0.18),
                    lineWidth: 0.8
                )
        }
        .mask(fade)
    }
}

/// Colours for text that sits on top of the photo, which stays dark enough
/// in both appearances thanks to the scrim.
enum OnPhoto {
    static let primary = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let secondary = Color(red: 0.97, green: 0.96, blue: 0.93).opacity(0.82)
    static let accent = Color(red: 0.75, green: 0.89, blue: 0.80)
}
