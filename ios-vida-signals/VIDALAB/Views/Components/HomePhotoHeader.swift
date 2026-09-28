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

/// The photograph behind the top of Today, dissolving into the canvas.
///
/// Sits behind the scroll view rather than inside it, so it can run edge to
/// edge under the status bar. It drifts up at a little over half the scroll
/// speed (parallax) and grows when she pulls past the top. A soft scrim keeps
/// the greeting legible on any photo, and a long gradient melts the bottom
/// edge into the canvas so there is never a hard line where the photo ends.
struct HomePhotoBackdrop: View {
    let photo: String
    var height: CGFloat = 500

    @Environment(\.vidaScrollOffset) private var offset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let pulled = max(0, -offset)
        let pushed = max(0, offset)
        let drift = reduceMotion ? pushed : pushed * 0.55
        let fadeTo = colorScheme == .dark
            ? Color(red: 0.071, green: 0.137, blue: 0.106)
            : Vida.cream

        Image(photo)
            .resizable()
            .scaledToFill()
            .frame(height: height + pulled)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay {
                // Scrim: darker at the very top for the status bar, a light
                // veil through the middle for the greeting.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.45), location: 0),
                        .init(color: .black.opacity(0.18), location: 0.3),
                        .init(color: .black.opacity(0.28), location: 0.62),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.45),
                        .init(color: fadeTo.opacity(0.7), location: 0.78),
                        .init(color: fadeTo, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .offset(y: -drift)
            .opacity(1 - min(0.6, pushed / 700))
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// Colours for text that sits on top of the photo, which stays dark in both
/// appearances thanks to the scrim.
enum OnPhoto {
    static let primary = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let secondary = Color(red: 0.97, green: 0.96, blue: 0.93).opacity(0.82)
    static let accent = Color(red: 0.75, green: 0.89, blue: 0.80)
}
