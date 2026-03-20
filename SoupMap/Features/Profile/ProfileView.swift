import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @ObservedObject var environment: AppEnvironment
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProfileViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ProfileViewModel(profileService: environment.profileService))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let user = sessionStore.currentUser {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            avatarSection(user: user)
                            profileFields
                            interestsSection
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(AppTheme.danger)
                            }
                        }
                        .padding(20)
                    }
                    .background(AppTheme.background.ignoresSafeArea())
                    .task {
                        viewModel.load(user: user)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Sign in to personalize your profile.")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background.ignoresSafeArea())
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
                    NavigationLink {
                        SettingsView(environment: environment)
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if sessionStore.currentUser != nil {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.black.opacity(0.8))
                            }
                            Text("Save Profile")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black.opacity(0.84))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#65D1B6"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func avatarSection(user: AppUser) -> some View {
        VStack(spacing: 14) {
            Group {
                if let preview = viewModel.avatarPreviewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                } else if let avatarURL = user.avatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Circle().fill(AppTheme.panelStrong)
                        }
                    }
                } else {
                    Circle().fill(Color(hex: "#70A8FF").opacity(0.6))
                        .overlay(
                            Text(String(user.displayName.prefix(1)).uppercased())
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )
                }
            }
            .frame(width: 118, height: 118)
            .clipShape(Circle())

            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                Text("Choose Avatar")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.panelStrong, in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .soupGlass(cornerRadius: 28)
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Username", text: $viewModel.username)
                .textInputAutocapitalization(.never)
                .padding(16)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            TextField("Display Name", text: $viewModel.displayName)
                .padding(16)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            TextEditor(text: $viewModel.bio)
                .frame(minHeight: 120)
                .padding(12)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .soupGlass(cornerRadius: 28)
        .padding(20)
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Interests")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 10) {
                TextField("Add interest", text: $viewModel.interestInput)
                    .padding(16)
                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button("Add") {
                    viewModel.addInterest()
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.black.opacity(0.84))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white, in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(viewModel.interests, id: \.self) { interest in
                    HStack(spacing: 6) {
                        Text(interest)
                        Button {
                            viewModel.removeInterest(interest)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.panelStrong, in: Capsule())
                }
            }
        }
        .padding(20)
        .soupGlass(cornerRadius: 28)
        .onChange(of: viewModel.selectedPhotoItem) { item in
            Task {
                await viewModel.loadAvatar(item)
            }
        }
    }

    private func save() async {
        guard let userID = sessionStore.currentUser?.id else { return }
        let didSave = await viewModel.save(userID: userID)
        if didSave {
            await sessionStore.refreshSession()
        }
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var username = ""
    @Published var displayName = ""
    @Published var bio = ""
    @Published var interests: [String] = []
    @Published var interestInput = ""
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var avatarData: Data?
    @Published var avatarPreviewImage: UIImage?
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let profileService: ProfileService
    private var didLoad = false

    init(profileService: ProfileService) {
        self.profileService = profileService
    }

    func load(user: AppUser) {
        guard didLoad == false else { return }
        didLoad = true
        username = user.username
        displayName = user.displayName
        bio = user.bio
        interests = user.interests
    }

    func addInterest() {
        let trimmed = interestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        interests.append(trimmed)
        interestInput = ""
    }

    func removeInterest(_ interest: String) {
        interests.removeAll { $0 == interest }
    }

    func loadAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                avatarData = data
                avatarPreviewImage = UIImage(data: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(userID: UUID) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let avatarURL = try await uploadAvatarIfNeeded(userID: userID)
            _ = try await profileService.updateProfile(
                userID: userID,
                input: ProfileUpdateInput(
                    username: username,
                    displayName: displayName,
                    bio: bio,
                    interests: interests
                ),
                avatarURL: avatarURL
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func uploadAvatarIfNeeded(userID: UUID) async throws -> URL? {
        guard let avatarData else { return nil }
        return try await profileService.uploadAvatar(data: avatarData, userID: userID)
    }
}
