import SwiftUI

struct TreatmentLogView: View {
    @Environment(AuthManager.self) private var auth
    @State private var treatments: [TreatmentRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddTreatment = false

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    ContentUnavailableView(
                        "Sign in to track treatments",
                        systemImage: "lock",
                        description: Text("Treatment notes are private to your VIDA LAB account.")
                    )
                } else if isLoading {
                    ProgressView("Loading treatment log")
                } else {
                    TreatmentLogContent(
                        treatments: treatments,
                        onDelete: delete,
                        onAdd: { showAddTreatment = true }
                    )
                }
            }
            .vidaMenu()
            .vidaSectionSwitch()
            .vidaBackground()
            .navigationTitle("Treatment Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTreatment = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add treatment")
                    .disabled(!auth.isSignedIn)
                }
            }
            .task(id: auth.user?.id) {
                await refresh()
            }
            .sheet(isPresented: $showAddTreatment) {
                AddTreatmentView { draft in
                    await add(draft)
                }
            }
            .alert("Treatment log", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func refresh() async {
        guard auth.isSignedIn else {
            treatments = []
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            treatments = try await TreatmentService.load()
        } catch {
            errorMessage = "Your treatment log couldn't load. Please try again."
        }
    }

    private func add(_ draft: TreatmentDraft) async {
        guard let userID = auth.user?.id else { return }
        do {
            let treatment = try await TreatmentService.add(draft, userID: userID)
            treatments.insert(treatment, at: 0)
        } catch {
            errorMessage = "Your treatment couldn't be saved. Please try again."
        }
    }

    private func delete(_ treatment: TreatmentRecord) {
        Task {
            do {
                try await TreatmentService.remove(id: treatment.id)
                treatments.removeAll { $0.id == treatment.id }
            } catch {
                errorMessage = "Your treatment couldn't be removed. Please try again."
            }
        }
    }
}

private struct TreatmentLogContent: View {
    let treatments: [TreatmentRecord]
    let onDelete: (TreatmentRecord) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TreatmentLogHeader()
                if treatments.isEmpty {
                    TreatmentLogEmptyState(onAdd: onAdd)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(treatments) { treatment in
                            TreatmentRow(treatment: treatment, onDelete: onDelete)
                        }
                    }
                }
            }
            .padding(22)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
    }
}

private struct TreatmentLogHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track what you’re trying.")
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
            Text("Record treatments, therapies, and routines in your own words. This log does not provide medical advice.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
        }
    }
}

private struct TreatmentLogEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nothing logged yet")
                .font(Vida.sans(16, weight: .semibold))
                .foregroundStyle(Vida.forest)
            Text("Add something you’re currently using, have tried before, or want to discuss at an appointment.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
            Button("Add a treatment", action: onAdd)
                .font(Vida.sans(14, weight: .semibold))
                .foregroundStyle(Vida.onForest)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Vida.forest, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }
}

private struct TreatmentRow: View {
    let treatment: TreatmentRecord
    let onDelete: (TreatmentRecord) -> Void

    private var ratingLabel: String {
        treatment.effectiveness.map { "\($0)/5 helpful" } ?? "Not rated"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(treatment.name)
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                Text("\(treatment.type.capitalized) · \(treatment.status.capitalized) · \(ratingLabel)")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                if let notes = treatment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(3)
                }
            }
            Spacer(minLength: 8)
            Button(role: .destructive) {
                onDelete(treatment)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .accessibilityLabel("Remove \(treatment.name)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 16)
    }
}

private struct AddTreatmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = TreatmentDraft()
    let onSave: (TreatmentDraft) async -> Void

    private let types = ["medication", "supplement", "therapy", "lifestyle", "procedure", "other"]
    private let statuses = ["current", "past", "discontinued"]

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you tracking?") {
                    TextField("Name", text: $draft.name)
                    Picker("Type", selection: $draft.type) {
                        ForEach(types, id: \.self) { Text($0.capitalized) }
                    }
                    Picker("Status", selection: $draft.status) {
                        ForEach(statuses, id: \.self) { Text($0.capitalized) }
                    }
                }

                Section("Your experience") {
                    Stepper("How helpful has it felt? \(draft.effectiveness)/5", value: $draft.effectiveness, in: 1...5)
                    TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Text("This is a personal log, not medical advice. Don’t change a prescribed treatment without speaking with a qualified clinician.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Treatment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
