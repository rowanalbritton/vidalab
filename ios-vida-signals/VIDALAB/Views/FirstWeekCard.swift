import SwiftUI

/// The "Your first week" checklist on Today.
///
/// Every step ticks itself off from real activity, so there is nothing to
/// mark manually. The card leaves once every step is done, or when she hides
/// it, and never comes back uninvited. The tour stays reachable in Settings.
struct FirstWeekCard: View {
    @Environment(VidaStore.self) private var store
    @AppStorage(FirstWeekGuide.dismissedKey) private var dismissed: Bool = false
    @AppStorage(FirstWeekGuide.askedKey) private var hasAskedQuestion: Bool = false

    /// Tapping a step that isn't done yet takes her to where it happens.
    var onStep: (FirstWeekGuide.Step) -> Void
    var onTour: () -> Void

    private var completed: Set<FirstWeekGuide.Step> {
        FirstWeekGuide.completed(.init(
            logs: store.logs,
            healthSyncEnabled: store.healthSyncEnabled,
            hasAskedQuestion: hasAskedQuestion,
            experimentCount: store.experiments.count,
            prepCount: store.preps.count
        ))
    }

    private var steps: [FirstWeekGuide.Step] { FirstWeekGuide.Step.allCases }

    var body: some View {
        let done = completed
        if !dismissed && done.count < steps.count {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: "Your first week")
                        Text("\(done.count) of \(steps.count) done")
                            .font(Vida.serif(22))
                            .foregroundStyle(Vida.forest)
                    }
                    Spacer(minLength: 8)
                    Button("Hide") {
                        withAnimation(.smooth) { dismissed = true }
                    }
                    .font(Vida.sans(13, weight: .medium))
                    .foregroundStyle(Vida.taupe)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Hide first-week checklist")
                }

                ProgressView(value: Double(done.count), total: Double(steps.count))
                    .tint(Vida.moss)
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    ForEach(steps) { step in
                        row(step, isDone: done.contains(step))
                    }
                }

                Button {
                    onTour()
                } label: {
                    HStack(spacing: 6) {
                        Text("Take the tour of Vida")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(Vida.sans(14, weight: .semibold))
                    .foregroundStyle(Vida.moss)
                    .frame(minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }
            .paperCard(padding: 20)
        }
    }

    private func row(_ step: FirstWeekGuide.Step, isDone: Bool) -> some View {
        Button {
            if !isDone { onStep(step) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : step.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(isDone ? Vida.moss : Vida.taupe)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(isDone ? Vida.inkSoft : Vida.ink)
                        .strikethrough(isDone, color: Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !isDone {
                        Text(step.detail)
                            .font(Vida.sans(13))
                            .foregroundStyle(Vida.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if !isDone {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Vida.taupe)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDone)
        .accessibilityLabel(isDone ? "\(step.title), done" : step.title)
        .accessibilityHint(isDone ? "" : step.detail)
    }
}
