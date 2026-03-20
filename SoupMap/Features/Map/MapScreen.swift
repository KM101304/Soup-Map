import MapboxMaps
import SwiftUI

struct MapScreen: View {
    @ObservedObject var environment: AppEnvironment
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel: MapViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(
            wrappedValue: MapViewModel(
                activityService: environment.activityService,
                moderationService: environment.moderationService
            )
        )
    }

    var body: some View {
        ZStack {
            MapboxMaps.Map(
                initialViewport: .camera(
                    center: AppConstants.vancouverCenter,
                    zoom: AppConstants.defaultBubbleZoom
                )
            ) {
                ForEvery(viewModel.bubbleNodes) { node in
                    MapViewAnnotation(coordinate: node.coordinate) {
                        BubbleAnnotationView(node: node)
                            .onTapGesture {
                                viewModel.handleTap(on: node)
                            }
                    }
                    .allowOverlap(false)
                    .variableAnchors([.init(anchor: .center), .init(anchor: .bottom), .init(anchor: .top)])
                }

                if let currentLocation = environment.locationManager.currentLocation {
                    MapViewAnnotation(coordinate: currentLocation) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "#70A8FF"), lineWidth: 4)
                            )
                            .shadow(color: Color(hex: "#70A8FF").opacity(0.3), radius: 12)
                    }
                    .allowOverlap(true)
                }
            }
            .mapStyle(.standard(lightPreset: .dusk))
            .ignoresSafeArea()
            .onCameraChanged { context in
                viewModel.cameraZoom = context.cameraState.zoom
            }

            LinearGradient(
                colors: [Color.black.opacity(0.42), .clear, Color.black.opacity(0.48)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                Spacer()
                footer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if viewModel.isShowingExamples {
                VStack {
                    Spacer()
                    EmptyMapStateCard {
                        viewModel.openCreate(sessionStore: sessionStore)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 104)
                }
            }
        }
        .task {
            await viewModel.load(for: sessionStore.currentUser?.id)
        }
        .onChange(of: sessionStore.currentUser?.id) { userID in
            Task {
                await viewModel.reload(for: userID)
            }
        }
        .sheet(item: $viewModel.selectedActivity) { activity in
            ActivityDetailSheet(
                activity: activity,
                isJoined: viewModel.isJoined(activity),
                isHost: viewModel.isHost(activity, currentUserID: sessionStore.currentUser?.id),
                isExample: viewModel.isExample(activity),
                isAuthenticated: sessionStore.isAuthenticated,
                moderationService: environment.moderationService,
                onCreateFromExample: {
                    viewModel.selectedActivity = nil
                    viewModel.openCreate(sessionStore: sessionStore)
                },
                onRequireSignIn: {
                    sessionStore.requireAuthentication()
                },
                onJoin: {
                    await viewModel.join(
                        activity: activity,
                        sessionStore: sessionStore,
                        notificationManager: environment.notificationManager
                    )
                },
                onLeave: {
                    await viewModel.leave(activity: activity, sessionStore: sessionStore)
                },
                onEnd: {
                    await viewModel.end(activity: activity)
                },
                onBlock: {
                    await viewModel.blockHost(of: activity, sessionStore: sessionStore)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.isShowingClusterSheet) {
            NearbyActivitiesSheet(
                activities: viewModel.selectedClusterActivities,
                selectActivity: { activity in
                    viewModel.isShowingClusterSheet = false
                    viewModel.selectedActivity = activity
                }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCreate) {
            CreateActivityView(environment: environment) {
                viewModel.isShowingCreate = false
                Task {
                    await viewModel.reload(for: sessionStore.currentUser?.id)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingProfile) {
            ProfileView(environment: environment)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SoupMap")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Vancouver is moving")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(14)
                    .soupGlass(cornerRadius: 18)
            }

            Button {
                environment.locationManager.requestWhenInUse()
                environment.locationManager.refreshLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(14)
                    .soupGlass(cornerRadius: 18)
            }

            Button {
                viewModel.openProfile(sessionStore: sessionStore)
            } label: {
                Group {
                    if let displayName = sessionStore.currentUser?.displayName {
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 48, height: 48)
                .soupGlass(cornerRadius: 18)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(14)
                    .soupGlass(cornerRadius: 20)
            }

            Spacer()

            Button {
                viewModel.openCreate(sessionStore: sessionStore)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                    Text("Create Bubble")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.84))
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color(hex: "#65D1B6"), in: Capsule())
                .shadow(color: Color(hex: "#65D1B6").opacity(0.35), radius: 18, y: 10)
            }
        }
    }
}

private struct EmptyMapStateCard: View {
    let createAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing live right now.")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text("We’re showing example bubbles so the city never feels dead. Start the first real bubble nearby and the map updates instantly.")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(AppTheme.textSecondary)

            Button(action: createAction) {
                Text("Start Something")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.84))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#F8BA53"), in: Capsule())
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .soupGlass(cornerRadius: 24)
    }
}

private struct NearbyActivitiesSheet: View {
    let activities: [Activity]
    let selectActivity: (Activity) -> Void

    var body: some View {
        NavigationStack {
            List(activities) { activity in
                Button {
                    selectActivity(activity)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activity.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(activity.participantCount) people • \(activity.categoryName)")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppTheme.backgroundSecondary)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Nearby bubbles")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
