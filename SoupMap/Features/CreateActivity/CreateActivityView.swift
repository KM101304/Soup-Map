import MapboxMaps
import SwiftUI

struct CreateActivityView: View {
    @ObservedObject var environment: AppEnvironment
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel: CreateActivityViewModel
    @State private var viewport = Viewport.camera(center: AppConstants.vancouverCenter, zoom: 13.2)

    init(environment: AppEnvironment, onComplete: @escaping () -> Void) {
        self.environment = environment
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: CreateActivityViewModel(activityService: environment.activityService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start a bubble")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Keep it simple, live, and close to now.")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        formSection
                        locationSection

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundStyle(AppTheme.danger)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Post")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .disabled(viewModel.canSubmit == false || viewModel.isSaving)
                }
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("Title", text: $viewModel.draft.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(16)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            TextEditor(text: $viewModel.draft.description)
                .frame(minHeight: 110)
                .padding(12)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            categoryPicker

            HStack(spacing: 14) {
                DatePicker("Start", selection: $viewModel.draft.startTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $viewModel.draft.endTime, in: viewModel.draft.startTime..., displayedComponents: [.date, .hourAndMinute])
            }
            .datePickerStyle(.compact)
            .font(.system(size: 14, weight: .semibold, design: .rounded))

            HStack(spacing: 14) {
                TextField("Capacity", text: $viewModel.capacityText)
                    .keyboardType(.numberPad)
                    .padding(16)
                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                tagComposer
            }
        }
        .padding(20)
        .soupGlass(cornerRadius: 28)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick the location")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Pan the map until the crosshair sits where you want people to gather.")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(AppTheme.textSecondary)

            ZStack {
                MapboxMaps.Map(viewport: $viewport) {
                    MapViewAnnotation(coordinate: viewModel.draft.coordinate) {
                        Circle()
                            .fill(Color(hex: "#65D1B6"))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 3))
                    }
                    .allowOverlap(true)
                }
                .mapStyle(.standard(lightPreset: .dusk))
                .onCameraChanged { context in
                    viewModel.draft.coordinate = context.cameraState.center
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 16)
            }

            Text(String(format: "Lat %.4f • Lng %.4f", viewModel.draft.coordinate.latitude, viewModel.draft.coordinate.longitude))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .soupGlass(cornerRadius: 28)
    }

    private var categoryPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(ActivityCategoryKind.allCases) { category in
                Button {
                    viewModel.draft.category = category
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: category.iconName)
                        Text(category.title)
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(viewModel.draft.category == category ? category.palette.text : AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.draft.category == category
                        ? category.palette.fill
                        : AppTheme.panelStrong,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
            }
        }
    }

    private var tagComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Add tag", text: $viewModel.tagInput)
                    .textInputAutocapitalization(.words)

                Button("Add") {
                    viewModel.addTag()
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(16)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.draft.tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag)
                            Button {
                                viewModel.removeTag(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.panelStrong, in: Capsule())
                    }
                }
            }
        }
    }

    private func save() async {
        guard let userID = sessionStore.currentUser?.id else {
            sessionStore.requireAuthentication()
            return
        }

        let success = await viewModel.save(hostID: userID)
        if success {
            onComplete()
            dismiss()
        }
    }
}

@MainActor
final class CreateActivityViewModel: ObservableObject {
    @Published var draft = ActivityDraft()
    @Published var tagInput = ""
    @Published var capacityText = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let activityService: ActivityService

    init(activityService: ActivityService) {
        self.activityService = activityService
    }

    var canSubmit: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        draft.endTime > draft.startTime &&
        AppConstants.vancouverLatitudeRange.contains(draft.coordinate.latitude) &&
        AppConstants.vancouverLongitudeRange.contains(draft.coordinate.longitude)
    }

    func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        draft.tags.append(trimmed)
        tagInput = ""
    }

    func removeTag(_ tag: String) {
        draft.tags.removeAll { $0 == tag }
    }

    func save(hostID: UUID) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        let trimmedCapacity = capacityText.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.capacity = trimmedCapacity.isEmpty ? nil : Int(trimmedCapacity)

        do {
            try await activityService.createActivity(draft: draft, hostID: hostID)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
