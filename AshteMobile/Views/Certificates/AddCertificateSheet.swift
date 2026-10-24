import SwiftUI
import UniformTypeIdentifiers

struct AddCertificateSheet: View {
    @State private var name = ""
    @State private var password = ""
    @State private var p12URL: URL?
    @State private var provisionURL: URL?
    @State private var showingP12Picker = false
    @State private var showingProvisionPicker = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SISpacing.lg) {
                    header

                    VStack(alignment: .leading, spacing: SISpacing.sm) {
                        sectionLabel("Certificate Name")
                        HStack(spacing: SISpacing.md) {
                            iconBadge("tag.fill")
                            TextField("Name", text: $name)
                                .autocorrectionDisabled()
                                .foregroundStyle(SIColor.textPrimary)
                        }
                        .padding(SISpacing.md)
                        .modifier(CertCard())
                    }

                    VStack(alignment: .leading, spacing: SISpacing.sm) {
                        sectionLabel("Files")
                        VStack(spacing: 0) {
                            filePickerRow(
                                icon: "key.fill",
                                title: String(localized: "Certificate (.p12)"),
                                selectedName: p12URL?.lastPathComponent
                            ) { showingP12Picker = true }
                            Divider().overlay(SIColor.border.opacity(0.6)).padding(.leading, 64)
                            filePickerRow(
                                icon: "doc.badge.gearshape.fill",
                                title: String(localized: "Provisioning Profile (.mobileprovision)"),
                                selectedName: provisionURL?.lastPathComponent
                            ) { showingProvisionPicker = true }
                            Divider().overlay(SIColor.border.opacity(0.6)).padding(.leading, 64)
                            HStack(spacing: SISpacing.md) {
                                iconBadge("lock.fill")
                                SecureField("P12 Password", text: $password)
                                    .foregroundStyle(SIColor.textPrimary)
                            }
                            .padding(SISpacing.md)
                        }
                        .modifier(CertCard())
                    }

                    if let errorMessage {
                        HStack(alignment: .top, spacing: SISpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage).font(SIFont.caption)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(SIColor.danger)
                        .padding(SISpacing.md)
                        .background(SIColor.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: SIRadius.md, style: .continuous))
                    }

                    Button {
                        addCertificate()
                    } label: {
                        HStack(spacing: SISpacing.sm) {
                            if isImporting {
                                ProgressView().tint(SIColor.onAccent)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                            }
                            Text("Add Certificate")
                        }
                    }
                    .buttonStyle(.siPrimaryWide)
                    .disabled(!canAdd || isImporting)
                    .opacity(canAdd ? 1 : 0.45)
                }
                .padding(.horizontal, SISpacing.md)
                .padding(.vertical, SISpacing.md)
            }
            .siScreen()
            .presentationDragIndicator(.visible)
            .navigationTitle("Add Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingP12Picker) {
                DocumentPickerView(contentTypes: [.data, .item], allowsMultipleSelection: false) { urls in
                    p12URL = urls.first
                }
            }
            .sheet(isPresented: $showingProvisionPicker) {
                DocumentPickerView(contentTypes: [.data, .item], allowsMultipleSelection: false) { urls in
                    provisionURL = urls.first
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: SISpacing.sm) {
            ZStack {
                Circle().fill(SIColor.accentMuted).frame(width: 72, height: 72)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(SIColor.accent)
            }
            Text("Import a .p12 and its matching .mobileprovision to start signing.")
                .font(SIFont.caption)
                .foregroundStyle(SIColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SISpacing.lg)
        }
        .padding(.top, SISpacing.sm)
    }

    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(SIColor.textSecondary)
            .textCase(.uppercase)
            .padding(.horizontal, SISpacing.xs)
    }

    private func iconBadge(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(SIColor.accent)
            .frame(width: 36, height: 36)
            .background(SIColor.accentMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && p12URL != nil && provisionURL != nil
    }

    private func filePickerRow(icon: String, title: String, selectedName: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SISpacing.md) {
                iconBadge(icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SIFont.headline)
                        .foregroundStyle(SIColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(selectedName ?? String(localized: "Choose…"))
                        .font(SIFont.caption)
                        .foregroundStyle(selectedName == nil ? SIColor.textSecondary : SIColor.success)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Image(systemName: selectedName == nil ? "chevron.right" : "checkmark.circle.fill")
                    .font(.system(size: selectedName == nil ? 13 : 20, weight: .semibold))
                    .foregroundStyle(selectedName == nil ? SIColor.textSecondary : SIColor.success)
            }
            .padding(SISpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addCertificate() {
        guard let p12URL, let provisionURL else { return }
        isImporting = true
        errorMessage = nil

        Task {
            do {
                _ = try await CertificateStore.shared.addCertificate(
                    name: name,
                    p12SourceURL: p12URL,
                    provisionSourceURL: provisionURL,
                    password: password
                )
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct CertCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SIColor.surface, in: RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous).stroke(SIColor.border.opacity(0.5), lineWidth: 0.5))
    }
}
