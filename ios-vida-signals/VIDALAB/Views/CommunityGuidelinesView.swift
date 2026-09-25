import SwiftUI

/// The house rules, shown once before a member's first post.
///
/// App Review guideline 1.2 asks for published rules and a way to reach a
/// human about user-generated content. Both live here rather than buried in
/// Settings, because the moment they matter is the moment somebody is about to
/// write something.
struct CommunityGuidelinesView: View {
    /// Set once the member has read these. Stored per install rather than per
    /// account: the rules are about conduct on this device's board, and
    /// re-reading them after a reinstall is no hardship.
    @AppStorage("vida.community.guidelines.accepted.v1")
    private var hasAccepted: Bool = false

    /// Shown before composing, where declining has to be possible, and from
    /// Settings, where it is a reference page and there is nothing to accept.
    let isGate: Bool
    var onAccept: () -> Void = { }

    @Environment(\.dismiss) private var dismiss

    private let rules: [(String, String)] = [
        ("Kind first",
         "Everyone here is unwell or worried about someone who is. Disagree with an idea, never with a person."),
        ("No diagnosing",
         "Share what happened to you. Don't tell anyone what they have, or what to take and how much."),
        ("Nobody's details",
         "Not yours, not your doctor's, not a family member's. Posts are plain text and other members can read them."),
        ("No selling",
         "No products, referral links, recruiting, or promoting a practice."),
        ("Report, don't retaliate",
         "If a post breaks these rules, report it. You can also block someone and never see them again.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("How this board works")
                        .font(Vida.serif(26))
                        .foregroundStyle(Vida.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("VIDA LAB's community is the one part of the app other people can read. These are the rules, and they're enforced.")
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(rules, id: \.0) { rule in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.0)
                                    .font(Vida.sans(15, weight: .semibold))
                                    .foregroundStyle(Vida.ink)
                                Text(rule.1)
                                    .font(Vida.sans(14))
                                    .foregroundStyle(Vida.inkSoft)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .background(Vida.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Vida.hairline, lineWidth: 0.9)
                    }

                    contact

                    if isGate { agreeButton }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationTitle("Community guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isGate ? "Not now" : "Done") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
    }

    private var contact: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Reporting and moderation")
            Text("Report anything that breaks these rules from the menu on a post or reply. To reach a person about moderation, email us.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Link(VidaLinks.supportAddress, destination: VidaLinks.support)
                .font(Vida.sans(14, weight: .medium))
                .foregroundStyle(Vida.forest)
                .frame(minHeight: 44)
                .accessibilityLabel("Email VIDA LAB support at \(VidaLinks.supportAddress)")
        }
    }

    private var agreeButton: some View {
        Button {
            hasAccepted = true
            onAccept()
            dismiss()
        } label: {
            Text("I've read these")
                .font(Vida.sans(16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Vida.cream)
        .background(Vida.forest, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension CommunityGuidelinesView {
    /// Whether the gate still needs to be shown before composing.
    static var needsAcceptance: Bool {
        !UserDefaults.standard.bool(forKey: "vida.community.guidelines.accepted.v1")
    }
}
