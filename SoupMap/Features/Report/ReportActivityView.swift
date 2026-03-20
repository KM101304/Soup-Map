import SwiftUI

struct ReportActivityView: View {
    let activity: Activity

    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReportViewModel

    init(activity: Activity, moderationService: ModerationService) {
        self.activity = activity
        _viewModel = StateObject(wrappedValue: ReportViewModel(moderationService: moderationService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $viewModel.reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.rawValue).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 120)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Report Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        Task {
                            await submit()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let userID = sessionStore.currentUser?.id else {
            dismiss()
            return
        }

        let success = await viewModel.submit(
            activity: activity,
            reporterID: userID
        )

        if success {
            dismiss()
        }
    }
}

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var reason: ReportReason = .misleading
    @Published var notes = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let moderationService: ModerationService

    init(moderationService: ModerationService) {
        self.moderationService = moderationService
    }

    func submit(activity: Activity, reporterID: UUID) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await moderationService.reportActivity(
                activityID: activity.id,
                reportedUserID: activity.hostID,
                reporterID: reporterID,
                reason: reason,
                notes: notes
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
