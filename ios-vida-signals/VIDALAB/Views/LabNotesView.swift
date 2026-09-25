import SwiftUI

/// The monthly recap, one card at a time.
///
/// Wrapped-style in shape, not in tone. The genre celebrates a big number,
/// and "you logged pain on 22 days" is not a celebration — so this reports
/// and never congratulates, and a worse month is never framed as a failure.
struct LabNotesView: View {
    let notes: LabNotes

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    var body: some View {
        ZStack {
            Vida.forest.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                TabView(selection: $index) {
                    ForEach(Array(notes.cards.enumerated()), id: \.element.id) { position, card in
                        cardView(card)
                            .tag(position)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(notes.cards.indices, id: \.self) { position in
                Capsule()
                    .fill(position <= index ? Vida.onForest : Vida.onForest.opacity(0.25))
                    .frame(height: 3)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: index)
        .accessibilityHidden(true)
    }

    private func cardView(_ card: LabNoteCard) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)

            Image(systemName: card.symbol)
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(Vida.onForest.opacity(0.75))

            Text(card.eyebrow.uppercased())
                .font(Vida.sans(11, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(Vida.onForest.opacity(0.7))

            Text(card.headline)
                .font(Vida.serif(42))
                .foregroundStyle(Vida.onForest)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.detail)
                .font(Vida.sans(16))
                .foregroundStyle(Vida.onForest.opacity(0.82))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.eyebrow). \(card.headline). \(card.detail)")
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Text(notes.monthName)
                .font(Vida.sans(12))
                .foregroundStyle(Vida.onForest.opacity(0.55))

            Button {
                if index < notes.cards.count - 1 {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { index += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(index < notes.cards.count - 1 ? "Next" : "Done")
                    .font(Vida.sans(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Vida.onForest, in: Capsule())
                    .foregroundStyle(Vida.forest)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 22)
    }
}

/// Presents Lab Notes once a month, from the home screen.
///
/// Attached as a modifier rather than built into HomeView so the trigger is
/// one readable thing: check on appear, show at most once, and mark it seen
/// the moment it opens rather than when it closes — a recap that reappears
/// because someone swiped away is worse than one they missed.
struct LabNotesPresenter: ViewModifier {
    @Environment(VidaStore.self) private var store
    @State private var pending: LabNotes?

    func body(content: Content) -> some View {
        content
            .sheet(item: $pending) { notes in
                LabNotesView(notes: notes)
            }
            .task {
                guard let notes = store.pendingLabNotes() else { return }
                store.markLabNotesSeen(notes)
                pending = notes
            }
    }
}

extension View {
    func monthlyLabNotes() -> some View {
        modifier(LabNotesPresenter())
    }
}
