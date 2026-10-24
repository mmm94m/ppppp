import SwiftUI

struct AppDetailView: View {
    let entryID: UUID
    @ObservedObject private var library = AppLibraryStore.shared
    @State private var showingSigningSheet = false
    @State private var showingInspector = false
    @State private var showingRename = false
    @State private var showingShareSheet = false
    @State private var showingInstall = false
    @State private var inspectionError: String?
    @Environment(\.dismiss) private var dismiss

    private var entry: AppEntry? {
        library.apps.first { $0.id == entryID }
    }

    var body: some View {
        Group {
            if let entry {
                content(for: entry)
            } else {
                Text("This app was removed.")
                    .foregroundStyle(SIColor.textSecondary)
            }
        }
        .siScreen()
        .navigationTitle(entry?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for entry: AppEntry) -> some View {
        ScrollView {
            VStack(spacing: SISpacing.lg) {
                hero(for: entry)

                VStack(alignment: .leading, spacing: SISpacing.sm) {
                    card {
                        actionRow(icon: "square.and.arrow.up.fill", title: "Export IPA", color: SIColor.accent) {
                            showingShareSheet = true
                        }
                        divider
                        actionRow(icon: "magnifyingglass", title: "Inspect", color: Color(hex: 0x0A84FF)) {
                            inspect(entry)
                        }
                    }
                    if entry.isSigned {
                        Text("Export IPA works every time — open it with AltStore, Sideloadly, or TrollStore. Direct on-device install depends on your iOS version and network, so it doesn't always succeed.")
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                            .padding(.horizontal, SISpacing.sm)
                    }
                }

                card {
                    actionRow(icon: "pencil", title: "Rename", color: Color(hex: 0x8E8E93)) {
                        showingRename = true
                    }
                    divider
                    actionRow(icon: "trash.fill", title: "Delete", color: SIColor.danger, titleColor: SIColor.danger) {
                        library.remove(entry)
                        dismiss()
                    }
                }

                if entry.isSigned, let signedAt = entry.signedAt {
                    VStack(alignment: .leading, spacing: SISpacing.sm) {
                        Text("Signing Info")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(SIColor.textSecondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, SISpacing.sm)
                        card {
                            infoRow(title: "Signed", value: signedAt.formatted(date: .abbreviated, time: .shortened))
                            if let certificate = CertificateStore.shared.certificate(withID: entry.certificateID) {
                                divider
                                infoRow(title: "Certificate", value: certificate.name)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SISpacing.md)
            .padding(.vertical, SISpacing.sm)
        }
        .sheet(isPresented: $showingSigningSheet) {
            SigningSheetView(entryID: entry.id) {
                showingInstall = true
            }
        }
        .sheet(isPresented: $showingInspector) {
            if let report = inspectionReport {
                InspectorReportView(report: report)
            }
        }
        .sheet(isPresented: $showingRename) {
            NameInputSheet(title: String(localized: "Rename App"), placeholder: String(localized: "Name"), text: entry.name, confirmTitle: String(localized: "Save")) { newName in
                library.rename(entry, to: newName)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [library.ipaURL(for: entry)])
        }
        .overlay(alignment: .bottom) {
            if showingInstall {
                InstallStatusPill(entryID: entry.id) {
                    showingInstall = false
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showingInstall)
        .alert("Inspection Failed", isPresented: Binding(get: { inspectionError != nil }, set: { if !$0 { inspectionError = nil } })) {
            Button("OK") { inspectionError = nil }
        } message: {
            Text(inspectionError ?? "")
        }
    }

    @State private var inspectionReport: InspectionReport?

    private func inspect(_ entry: AppEntry) {
        do {
            inspectionReport = try InspectorService.inspect(ipaURL: library.ipaURL(for: entry))
            showingInspector = true
        } catch {
            inspectionError = error.localizedDescription
        }
    }

    private func hero(for entry: AppEntry) -> some View {
        VStack(spacing: SISpacing.md) {
            iconView(for: entry)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(SIColor.border.opacity(0.6), lineWidth: 0.5))
                .shadow(color: SIColor.accent.opacity(0.35), radius: 22, y: 8)

            VStack(spacing: 5) {
                Text(entry.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(SIColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(entry.bundleIdentifier)
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.textSecondary)
                HStack(spacing: 6) {
                    heroChip(entry.displayVersion)
                    heroChip(entry.displaySize)
                    if entry.isSigned {
                        StatusBadge(text: String(localized: "Signed"), color: SIColor.success)
                    }
                }
                .padding(.top, 2)
            }

            HStack(spacing: SISpacing.sm + 2) {
                Button(entry.isSigned ? LocalizedStringKey("Re-sign") : LocalizedStringKey("Sign")) {
                    showingSigningSheet = true
                }
                .buttonStyle(.siPrimaryWide)
                if entry.isSigned {
                    Button("Install") {
                        showingInstall = true
                    }
                    .buttonStyle(.siSecondaryWide)
                }
            }
            .padding(.top, SISpacing.xs)
        }
        .padding(SISpacing.lg - 4)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [SIColor.accent.opacity(0.20), SIColor.surface],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: SIRadius.lg + 6, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: SIRadius.lg + 6, style: .continuous).stroke(SIColor.border.opacity(0.5), lineWidth: 0.5))
    }

    private func heroChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(SIColor.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(SIColor.surfaceElevated, in: Capsule())
    }

    private var divider: some View {
        Divider().overlay(SIColor.border.opacity(0.6)).padding(.leading, 56)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(SIColor.surface, in: RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous).stroke(SIColor.border.opacity(0.5), lineWidth: 0.5))
    }

    private func actionRow(icon: String, title: LocalizedStringKey, color: Color, titleColor: Color = SIColor.textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SISpacing.md) {
                SIIconBadge(systemName: icon, color: color)
                Text(title).font(SIFont.headline).foregroundStyle(titleColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SIColor.textSecondary.opacity(0.7))
            }
            .padding(SISpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.siPressableCard)
    }

    private func infoRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(SIColor.textPrimary)
            Spacer()
            Text(value).foregroundStyle(SIColor.textSecondary).lineLimit(1)
        }
        .padding(SISpacing.md)
    }

    @ViewBuilder
    private func iconView(for entry: AppEntry) -> some View {
        if let iconURL = library.iconURL(for: entry), let uiImage = UIImage(contentsOfFile: iconURL.path) {
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else {
            ZStack {
                SIColor.accentMuted
                Image(systemName: "app.dashed").font(.system(size: 34)).foregroundStyle(SIColor.accent)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
