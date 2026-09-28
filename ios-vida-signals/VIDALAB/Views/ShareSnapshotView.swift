import PhotosUI
import SwiftUI
import UIKit

/// Make a card of today to share: pick a background (one of the field-note
/// photos or one of her own), pick what the card shows, and share it as a
/// story-sized image. Only what she chooses to show is drawn; nothing about
/// symptoms is included unless she picks the plate.
struct ShareSnapshotView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Style: String, CaseIterable, Identifiable {
        case today, plate, fieldNote
        var id: String { rawValue }
        var title: String {
            switch self {
            case .today: "Today"
            case .plate: "My week"
            case .fieldNote: "Field note"
            }
        }
    }

    @State private var style: Style = .today
    @State private var photoName: String = VidaHeroPhoto.current
    @State private var customPhoto: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showName = true
    @State private var rendered: Image?

    /// Story proportions (9:16).
    private let cardSize = CGSize(width: 360, height: 640)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    card
                        .frame(width: cardSize.width * 0.78, height: cardSize.height * 0.78)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                        .animation(Vida.Motion.gentle, value: style)
                        .animation(Vida.Motion.gentle, value: photoName)
                        .padding(.top, 8)

                    controls
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { VidaCanvas().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .foregroundStyle(Vida.inkSoft)
                        .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .principal) {
                    Text("SHARE")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Vida.forest)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let rendered {
                        ShareLink(item: rendered, preview: SharePreview("My VIDA LAB day", image: rendered)) {
                            Text("Share")
                                .font(Vida.sans(15, weight: .semibold))
                                .foregroundStyle(Vida.moss)
                        }
                    }
                }
            }
        }
        .task(id: renderKey) { render() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    customPhoto = image
                }
            }
        }
    }

    // MARK: - Card

    /// The card itself, drawn at story size and scaled for the preview.
    private var card: some View {
        ShareCard(
            style: style,
            background: backgroundImage,
            name: showName ? store.name : "",
            done: store.completedPeriodsToday.count,
            total: CheckInPeriod.allCases.count,
            progress: store.todayPeriodCompletion,
            daysLogged: store.loggedDayCount,
            cultures: SpecimenPlate.cultures(from: store),
            photoNumber: photoName.filter(\.isNumber)
        )
        .frame(width: cardSize.width, height: cardSize.height)
        .environment(\.colorScheme, .dark)
        .scaleEffect(0.78)
        .frame(width: cardSize.width * 0.78, height: cardSize.height * 0.78)
    }

    private var backgroundImage: Image {
        if let customPhoto { return Image(uiImage: customPhoto) }
        return Image(photoName)
    }

    /// Anything that changes the picture triggers a fresh render.
    private var renderKey: String {
        "\(style.rawValue)-\(photoName)-\(customPhoto?.hash ?? 0)-\(showName)-\(store.loggedDayCount)"
    }

    @MainActor
    private func render() {
        let content = ShareCard(
            style: style,
            background: backgroundImage,
            name: showName ? store.name : "",
            done: store.completedPeriodsToday.count,
            total: CheckInPeriod.allCases.count,
            progress: store.todayPeriodCompletion,
            daysLogged: store.loggedDayCount,
            cultures: SpecimenPlate.cultures(from: store),
            photoNumber: photoName.filter(\.isNumber)
        )
        .frame(width: cardSize.width, height: cardSize.height)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: content)
        // 360 × 640 points at 3× is 1080 × 1920, the size stories expect.
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            rendered = Image(uiImage: uiImage)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Card")
                HStack(spacing: 9) {
                    ForEach(Style.allCases) { item in
                        SelectChip(label: item.title, isSelected: style == item) {
                            withAnimation(Vida.Motion.gentle) { style = item }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Background")
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(Vida.forest)
                                .frame(width: 60, height: 84)
                                .background(Vida.shell, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .accessibilityLabel("Choose your own photo")

                        ForEach(VidaHeroPhoto.names, id: \.self) { name in
                            Button {
                                customPhoto = nil
                                pickerItem = nil
                                photoName = name
                            } label: {
                                Image(name)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                customPhoto == nil && photoName == name ? Vida.forest : .clear,
                                                lineWidth: 2
                                            )
                                    }
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Field note \(name.filter(\.isNumber))")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            Toggle(isOn: $showName) {
                Text("Show my name")
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.ink)
            }
            .tint(Vida.moss)

            Text("Your card only shows what's on it above. Nothing is posted until you choose where to share it.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The story-sized card: a photograph that dissolves into forest, a glass
/// panel with today's figure, and the wordmark in the corner.
struct ShareCard: View {
    let style: ShareSnapshotView.Style
    let background: Image
    let name: String
    let done: Int
    let total: Int
    let progress: Double
    let daysLogged: Int
    let cultures: [SpecimenPlate.Culture]
    let photoNumber: String

    private let forest = Color(red: 0.059, green: 0.110, blue: 0.086)
    private let cream = Color(red: 0.97, green: 0.96, blue: 0.93)

    var body: some View {
        ZStack {
            forest
            VStack(spacing: 0) {
                background
                    .resizable()
                    .scaledToFill()
                    .frame(height: 420)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(Vida.sans(10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(cream.opacity(0.85))
                    .padding(.top, 54)
                Spacer()
                panel
                    .padding(.horizontal, 34)
                Spacer()
                HStack {
                    if !name.isEmpty {
                        Text(name)
                            .font(Vida.serifItalic(17))
                            .foregroundStyle(cream.opacity(0.9))
                    }
                    Spacer()
                    Text("VIDA LAB")
                        .font(Vida.sans(12, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(cream)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 34)
            }
        }
    }

    @ViewBuilder
    private var panel: some View {
        VStack(spacing: 14) {
            switch style {
            case .today:
                Text("TODAY")
                    .font(Vida.sans(11, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(cream.opacity(0.8))
                ZStack {
                    LuminousRing(progress: progress, lineWidth: 9, animated: false)
                    VStack(spacing: 2) {
                        Text("\(done)")
                            .font(Vida.display(52))
                            .foregroundStyle(cream)
                        Text("of \(total) check-ins")
                            .font(Vida.sans(11, weight: .medium))
                            .foregroundStyle(cream.opacity(0.75))
                    }
                }
                .frame(width: 150, height: 150)
                Text("\(daysLogged) day\(daysLogged == 1 ? "" : "s") of listening to my body")
                    .font(Vida.sans(13))
                    .foregroundStyle(cream.opacity(0.85))
            case .plate:
                Text("THIS WEEK'S PLATE")
                    .font(Vida.sans(11, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(cream.opacity(0.8))
                if cultures.isEmpty {
                    Text("A week of check-ins grows the plate.")
                        .font(Vida.sans(14))
                        .foregroundStyle(cream.opacity(0.85))
                        .padding(.vertical, 40)
                } else {
                    SpecimenPlate(cultures: cultures, startsGrown: true)
                        .frame(width: 230, height: 230)
                    if let line = SpecimenPlate.headline(for: cultures) {
                        Text(line)
                            .font(Vida.sans(13))
                            .foregroundStyle(cream.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                }
            case .fieldNote:
                Text("FIELD NOTE Nº \(photoNumber.isEmpty ? "01" : photoNumber)")
                    .font(Vida.sans(11, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(cream.opacity(0.8))
                Text("\(daysLogged)")
                    .font(Vida.display(72))
                    .foregroundStyle(cream)
                Text("days of paying attention")
                    .font(Vida.serifItalic(19))
                    .foregroundStyle(cream.opacity(0.9))
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.38))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(cream.opacity(0.14), lineWidth: 0.8)
        }
    }
}
