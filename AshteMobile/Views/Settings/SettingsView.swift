import SwiftUI

private enum ResetAction: Identifiable, Equatable {
    case signedApps
    case importedApps
    case certificates
    case everything

    var id: Int {
        switch self {
        case .signedApps: return 0
        case .importedApps: return 1
        case .certificates: return 2
        case .everything: return 3
        }
    }

    var title: String {
        switch self {
        case .signedApps: return String(localized: "Remove all signed apps?")
        case .importedApps: return String(localized: "Remove all imported apps?")
        case .certificates: return String(localized: "Remove all certificates?")
        case .everything: return String(localized: "Reset AshteMobile completely?")
        }
    }

    var message: String {
        switch self {
        case .signedApps: return String(localized: "This deletes every signed app from your library. Their original imported IPAs are removed too.")
        case .importedApps: return String(localized: "This deletes every app in your library that hasn't been signed yet. Signed apps are left alone.")
        case .certificates: return String(localized: "This deletes every certificate, its saved password, and its expiry tracking.")
        case .everything: return String(localized: "This deletes your entire library, all certificates, tweaks, presets, sources, and the signing cache, and resets every setting. There's no undo.")
        }
    }

    var confirmTitle: String {
        self == .everything ? String(localized: "Reset Everything") : String(localized: "Remove")
    }
}

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var certificateStore = CertificateStore.shared
    @ObservedObject private var dylibStore = DylibLibraryStore.shared
    @State private var cacheSize: Int64 = SigningCache.shared.totalSize
    @State private var updateResult: UpdateCheckResult?
    @State private var isCheckingUpdate = false
    @State private var updateError: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: SISpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [SIColor.accent, SIColor.accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "signature")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(SIColor.onAccent)
                    }
                    .frame(width: 64, height: 64)
                    .shadow(color: SIColor.accent.opacity(0.35), radius: 14, y: 5)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("AshteMobile")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(SIColor.textPrimary)
                        Text(versionString)
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, SISpacing.xs)
            }
            .listRowBackground(
                LinearGradient(colors: [SIColor.accent.opacity(0.18), SIColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            )

            Section {
                NavigationLink {
                    CertificatesView()
                } label: {
                    SettingsLabel(title: "Certificates", icon: "checkmark.seal.fill", color: Color(hex: 0x30D158), value: "\(certificateStore.certificates.count)")
                }
                NavigationLink {
                    TweaksLibraryView()
                } label: {
                    SettingsLabel(title: "Tweak Library", icon: "puzzlepiece.extension.fill", color: Color(hex: 0xBF5AF2), value: "\(dylibStore.dylibs.count)")
                }
                NavigationLink { PresetsView() } label: { SettingsLabel(title: "Signing Presets", icon: "slider.horizontal.3", color: Color(hex: 0x0A84FF)) }
                NavigationLink { DefaultSigningOptionsView() } label: { SettingsLabel(title: "Default Signing Options", icon: "signature", color: Color(hex: 0xFF9F0A)) }
            } header: {
                Text("Signing")
            }
        .siRowBackground()

            Section {
                NavigationLink {
                    ThemePickerView()
                } label: {
                    HStack(spacing: SISpacing.md) {
                        SIIconBadge(systemName: "paintpalette.fill", color: Color(hex: 0xFF375F))
                        Text("Theme")
                        Spacer()
                        Circle()
                            .fill(SIColor.accent)
                            .frame(width: 10, height: 10)
                        Text(themeManager.current.id.displayName)
                            .foregroundStyle(SIColor.textSecondary)
                    }
                }
            } header: {
                Text("Appearance")
            }
        .siRowBackground()

            Section {
                LabeledContent("Instant-Resign Cache", value: ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file))
                Button("Clear Cache", role: .destructive) {
                    SigningCache.shared.clear()
                    cacheSize = 0
                }
            } header: {
                Text("Cache")
            }
        .siRowBackground()

            Section {
                NavigationLink { BugReportView() } label: { SettingsLabel(title: "Bugs & Issues", icon: "ladybug.fill", color: Color(hex: 0xFF453A)) }
                NavigationLink { ChangelogView() } label: { SettingsLabel(title: "Changelog", icon: "clock.arrow.circlepath", color: Color(hex: 0x64D2FF)) }
                Link(destination: BugReportView.repositoryURL) { SettingsLabel(title: "Source on GitHub", icon: "chevron.left.forwardslash.chevron.right", color: Color(hex: 0x5E5CE6)) }
            } header: {
                Text("Support")
            }
        .siRowBackground()

            Section {
                LabeledContent("Version", value: versionString)
                Button {
                    checkForUpdate()
                } label: {
                    if isCheckingUpdate {
                        ProgressView()
                    } else {
                        Text("Check for Updates")
                    }
                }
                if let updateResult {
                    if updateResult.isUpdateAvailable {
                        Link("Update to \(updateResult.latestVersion) available", destination: updateResult.releaseURL)
                    } else {
                        Text("You're up to date.").foregroundStyle(SIColor.textSecondary)
                    }
                }
                if let updateError {
                    Text(updateError).foregroundStyle(SIColor.danger).font(SIFont.caption)
                }
            } header: {
                Text("About")
            }
        .siRowBackground()

            Section {
                NavigationLink { StorageResetView() } label: { SettingsLabel(title: "Storage & Reset", icon: "externaldrive.fill", color: Color(hex: 0x8E8E93)) }
            }
        .siRowBackground()
        }
        .listStyle(.insetGrouped)
        .siScreen()
        .navigationTitle("Settings")
        .onAppear { cacheSize = SigningCache.shared.totalSize }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func checkForUpdate() {
        isCheckingUpdate = true
        updateError = nil
        Task {
            do {
                let result = try await UpdateChecker.shared.checkForUpdate()
                await MainActor.run {
                    updateResult = result
                    isCheckingUpdate = false
                }
            } catch {
                await MainActor.run {
                    updateError = error.localizedDescription
                    isCheckingUpdate = false
                }
            }
        }
    }
}

private struct ThemePickerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        List {
            ForEach(SIThemeID.allCases) { id in
                Button {
                    themeManager.select(id)
                } label: {
                    HStack {
                        Circle()
                            .fill(SITheme.theme(for: id).accent)
                            .frame(width: 14, height: 14)
                        Text(id.displayName)
                            .foregroundStyle(SIColor.textPrimary)
                        Spacer()
                        if themeManager.current.id == id {
                            Image(systemName: "checkmark").foregroundStyle(SIColor.accent)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .siScreen()
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StorageResetView: View {
    @State private var pendingReset: ResetAction?

    var body: some View {
        List {
            Section {
                Button {
                    openAppFolder()
                } label: {
                    Label("View App Folder", systemImage: "folder")
                }
            } footer: {
                Text("Opens AshteMobile's Documents folder in the Files app — imported and signed IPAs, certificates, tweaks, and presets all live there.")
            }
        .siRowBackground()

            Section {
                Button("Remove All Signed Apps", role: .destructive) { pendingReset = .signedApps }
                Button("Remove All Imported Apps", role: .destructive) { pendingReset = .importedApps }
                Button("Remove All Certificates", role: .destructive) { pendingReset = .certificates }
                Button("Reset Everything", role: .destructive) { pendingReset = .everything }
            } header: {
                Text("Reset")
            } footer: {
                Text("These remove data from this device only and can't be undone.")
            }
        .siRowBackground()
        }
        .listStyle(.insetGrouped)
        .siScreen()
        .navigationTitle("Storage & Reset")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            pendingReset?.title ?? "",
            isPresented: Binding(get: { pendingReset != nil }, set: { if !$0 { pendingReset = nil } }),
            titleVisibility: .visible
        ) {
            if let pendingReset {
                Button(pendingReset.confirmTitle, role: .destructive) {
                    performReset(pendingReset)
                }
            }
        } message: {
            if let pendingReset {
                Text(pendingReset.message)
            }
        }
    }

    private func openAppFolder() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let url = URL(string: "shareddocuments://" + documents.path) else { return }
        UIApplication.shared.open(url)
    }

    private func performReset(_ action: ResetAction) {
        switch action {
        case .signedApps:
            AppLibraryStore.shared.removeAll { $0.isSigned }
        case .importedApps:
            AppLibraryStore.shared.removeAll { !$0.isSigned }
        case .certificates:
            CertificateStore.shared.removeAllCertificates()
        case .everything:
            AppLibraryStore.shared.removeAll { _ in true }
            CertificateStore.shared.removeAllCertificates()
            DylibLibraryStore.shared.removeAll()
            PresetStore.shared.removeAll()
            SourceStore.shared.removeAll()
            DefaultSigningOptionsStore.shared.resetToDefaults()
            SigningCache.shared.clear()
        }
    }
}
