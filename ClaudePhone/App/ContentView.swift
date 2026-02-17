import SwiftUI
import EventKit
import Contacts
import CoreLocation
import HealthKit
import Photos
import HomeKit
import Speech
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatViewModel: ChatViewModel

    var body: some View {
        Group {
            if appState.isOnboarding {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if appState.needsPermissions {
                PermissionsOnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(AppTheme.springAnimation, value: appState.isOnboarding)
        .animation(AppTheme.springAnimation, value: appState.needsPermissions)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var tabBarVisible = true

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                ChatView()
                    .tag(AppTab.chat)

                ToolsBrowserView()
                    .tag(AppTab.tools)

                SettingsView()
                    .tag(AppTab.settings)
            }
            .tabViewStyle(.automatic)
            .tint(AppTheme.primary)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            ZStack {
                // Blurred background
                Rectangle()
                    .fill(.ultraThinMaterial)

                // Tinted overlay
                Rectangle()
                    .fill(AppTheme.backgroundPrimary.opacity(0.85))

                // Top border
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.glassBorder.opacity(0.8),
                                    AppTheme.glassBorder.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                    Spacer()
                }
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            withAnimation(AppTheme.springAnimation) {
                selectedTab = tab
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Selection indicator
                    if selectedTab == tab {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                        .symbolEffect(.bounce, value: selectedTab == tab)
                        .foregroundColor(selectedTab == tab ? AppTheme.primary : AppTheme.textTertiary)
                }

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                    .foregroundColor(selectedTab == tab ? AppTheme.primary : AppTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKey = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAnimating = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: AppTheme.primary.opacity(0.4), radius: 20, y: 8)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)

                    Text("ClaudePhone")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Your AI assistant with full iOS integration")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // API Key Input
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Anthropic API Key", systemImage: "key.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)

                        SecureField("sk-ant-...", text: $apiKey)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                    .fill(AppTheme.backgroundTertiary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                    .stroke(isFieldFocused ? AppTheme.primary : AppTheme.glassBorder, lineWidth: 1)
                            )
                            .focused($isFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    if showError {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Button {
                        saveAndContinue()
                    } label: {
                        HStack {
                            Text("Get Started")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if apiKey.isEmpty {
                                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                        .fill(AppTheme.primary.opacity(0.4))
                                } else {
                                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                        .fill(AppTheme.primaryGradient)
                                }
                            }
                        )
                        .shadow(color: apiKey.isEmpty ? .clear : AppTheme.primary.opacity(0.3), radius: 10, y: 4)
                    }
                    .disabled(apiKey.isEmpty)
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Your API key is stored securely in the iOS Keychain")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isAnimating = true
            }
        }
    }

    private func saveAndContinue() {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError(message: "Please enter your API key")
            return
        }

        do {
            try KeychainManager.shared.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            withAnimation(AppTheme.springAnimation) {
                appState.isOnboarding = false
                appState.needsPermissions = true
            }
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    private func showError(message: String) {
        errorMessage = message
        withAnimation(AppTheme.springAnimation) {
            showError = true
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Permissions Onboarding View
struct PermissionsOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: AppTheme.primary.opacity(0.4), radius: 20, y: 8)

                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)

                    Text("Permissions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("ClaudePhone needs access to help you with your daily tasks. You can change these anytime in Settings.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                // Permissions List
                ScrollView {
                    VStack(spacing: 12) {
                        PermissionRow(
                            icon: "calendar",
                            title: "Calendar & Reminders",
                            description: "Create events and manage reminders",
                            status: permissionsManager.calendarStatus,
                            action: { permissionsManager.requestCalendarAccess() }
                        )

                        PermissionRow(
                            icon: "person.crop.circle",
                            title: "Contacts",
                            description: "Search and manage your contacts",
                            status: permissionsManager.contactsStatus,
                            action: { permissionsManager.requestContactsAccess() }
                        )

                        PermissionRow(
                            icon: "location.fill",
                            title: "Location",
                            description: "Provide location-based features",
                            status: permissionsManager.locationStatus,
                            action: { permissionsManager.requestLocationAccess() }
                        )

                        PermissionRow(
                            icon: "heart.fill",
                            title: "Health",
                            description: "Read and track health metrics",
                            status: permissionsManager.healthStatus,
                            action: { permissionsManager.requestHealthAccess() }
                        )

                        PermissionRow(
                            icon: "photo.on.rectangle",
                            title: "Photos",
                            description: "Access and save photos",
                            status: permissionsManager.photosStatus,
                            action: { permissionsManager.requestPhotosAccess() }
                        )

                        PermissionRow(
                            icon: "house.fill",
                            title: "HomeKit",
                            description: "Control smart home devices",
                            status: permissionsManager.homeKitStatus,
                            action: { permissionsManager.requestHomeKitAccess() }
                        )

                        PermissionRow(
                            icon: "mic.fill",
                            title: "Microphone",
                            description: "Voice input and speech recognition",
                            status: permissionsManager.microphoneStatus,
                            action: { permissionsManager.requestMicrophoneAccess() }
                        )
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Continue Button
                VStack(spacing: 12) {
                    Button {
                        appState.completePermissionsOnboarding()
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } label: {
                        HStack {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                .fill(AppTheme.primaryGradient)
                        )
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, y: 4)
                    }

                    Button {
                        appState.completePermissionsOnboarding()
                    } label: {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        Button {
            if status == .notDetermined {
                action()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                statusIcon
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(AppTheme.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.glassBorder, lineWidth: 0.5)
            )
        }
        .disabled(status != .notDetermined)
    }

    private var statusColor: Color {
        switch status {
        case .notDetermined:
            return AppTheme.primary
        case .authorized:
            return .green
        case .denied:
            return AppTheme.textTertiary
        }
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .notDetermined:
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            case .authorized:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
    }
}

// MARK: - Permission Status
enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
}

// MARK: - Permissions Manager
class PermissionsManager: ObservableObject {
    @Published var calendarStatus: PermissionStatus = .notDetermined
    @Published var contactsStatus: PermissionStatus = .notDetermined
    @Published var locationStatus: PermissionStatus = .notDetermined
    @Published var healthStatus: PermissionStatus = .notDetermined
    @Published var photosStatus: PermissionStatus = .notDetermined
    @Published var homeKitStatus: PermissionStatus = .notDetermined
    @Published var microphoneStatus: PermissionStatus = .notDetermined

    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()
    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private let homeManager = HMHomeManager()

    init() {
        checkAllStatuses()
    }

    func checkAllStatuses() {
        checkCalendarStatus()
        checkContactsStatus()
        checkLocationStatus()
        checkHealthStatus()
        checkPhotosStatus()
        checkHomeKitStatus()
        checkMicrophoneStatus()
    }

    // MARK: - Calendar
    func checkCalendarStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarStatus = status == .fullAccess || status == .authorized ? .authorized :
                        status == .denied || status == .restricted ? .denied : .notDetermined
    }

    func requestCalendarAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.checkCalendarStatus()
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.checkCalendarStatus()
                }
            }
        }
    }

    // MARK: - Contacts
    func checkContactsStatus() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsStatus = status == .authorized ? .authorized :
                        status == .denied || status == .restricted ? .denied : .notDetermined
    }

    func requestContactsAccess() {
        contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.checkContactsStatus()
            }
        }
    }

    // MARK: - Location
    func checkLocationStatus() {
        let status = locationManager.authorizationStatus
        locationStatus = status == .authorizedWhenInUse || status == .authorizedAlways ? .authorized :
                        status == .denied || status == .restricted ? .denied : .notDetermined
    }

    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkLocationStatus()
        }
    }

    // MARK: - Health
    func checkHealthStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthStatus = .denied
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        let status = healthStore.authorizationStatus(for: readTypes.first!)
        healthStatus = status == .sharingAuthorized ? .authorized : .notDetermined
    }

    func requestHealthAccess() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!
        ]

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.checkHealthStatus()
            }
        }
    }

    // MARK: - Photos
    func checkPhotosStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosStatus = status == .authorized || status == .limited ? .authorized :
                      status == .denied || status == .restricted ? .denied : .notDetermined
    }

    func requestPhotosAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.checkPhotosStatus()
            }
        }
    }

    // MARK: - HomeKit
    func checkHomeKitStatus() {
        // HomeKit doesn't have a simple authorization check
        // We'll assume not determined until first use
        homeKitStatus = .notDetermined
    }

    func requestHomeKitAccess() {
        // HomeKit permissions are granted through the HMHomeManager
        // The actual permission request happens when accessing homes
        homeKitStatus = .authorized
    }

    // MARK: - Microphone
    func checkMicrophoneStatus() {
        let status = AVAudioSession.sharedInstance().recordPermission
        microphoneStatus = status == .granted ? .authorized :
                          status == .denied ? .denied : .notDetermined
    }

    func requestMicrophoneAccess() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.checkMicrophoneStatus()
            }
        }
    }
}
