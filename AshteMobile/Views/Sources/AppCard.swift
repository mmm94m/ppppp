import SwiftUI

/// Shared download + sign hand-off state for apps listed from a source.
@MainActor
final class AppDownloadModel: ObservableObject {
    @Published var downloadingID: String?
    @Published var progress: Double?
    @Published var downloadedBytes: Int64 = 0
    @Published var errorMessage: String?
    @Published var signEntryID: UUID?

    func download(_ app: RepositoryApp, sourceName: String?) {
        guard downloadingID == nil, let version = app.latest else { return }
        downloadingID = app.id
        progress = 0
        downloadedBytes = 0
        Task {
            do {
                let url = try await RepositoryService.download(version) { [weak self] fraction, bytesWritten in
                    Task { @MainActor in
                        self?.progress = fraction
                        self?.downloadedBytes = bytesWritten
                    }
                }
                let entry = try await AppLibraryStore.shared.importIPA(at: url, sourceName: sourceName)
                try? FileManager.default.removeItem(at: url)
                downloadingID = nil
                signEntryID = entry.id
            } catch {
                downloadingID = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct RepositoryAppCard: View {
    let app: RepositoryApp
    let sourceName: String?
    @ObservedObject var model: AppDownloadModel
    @State private var expanded = false

    private var isDownloading: Bool { model.downloadingID == app.id }

    var body: some View {
        VStack(alignment: .leading, spacing: SISpacing.sm + 2) {
            HStack(spacing: SISpacing.md) {
                RemoteIcon(url: app.iconURL, name: app.name, cornerRadius: 15)
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(SIColor.textPrimary)
                        .lineLimit(1)
                    if let line = app.subtitle ?? app.developerName {
                        Text(line)
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        if let version = app.latest?.version {
                            chip("v\(version)")
                        }
                        if let size = app.latest?.displaySize {
                            chip(size)
                        }
                    }
                }

                Spacer(minLength: 8)
                getButton
            }

            if let description = app.localizedDescription, !description.isEmpty {
                Text(description)
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.textSecondary)
                    .lineLimit(expanded ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() } }
            }
        }
        .padding(SISpacing.md)
        .background(SIColor.surface, in: RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous).stroke(SIColor.border.opacity(0.5), lineWidth: 0.5))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(SIColor.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(SIColor.surfaceElevated, in: Capsule())
    }

    @ViewBuilder
    private var getButton: some View {
        if isDownloading {
            VStack(spacing: 2) {
                if let progress = model.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(SIColor.accent)
                        .frame(width: 64)
                } else {
                    ProgressView()
                    Text(ByteCountFormatter.string(fromByteCount: model.downloadedBytes, countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundStyle(SIColor.textSecondary)
                }
            }
            .frame(minWidth: 64)
        } else {
            Button {
                model.download(app, sourceName: sourceName)
            } label: {
                Text("Get")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(SIColor.onAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                    .background(SIColor.accent, in: Capsule())
            }
            .buttonStyle(.siPressableCard)
            .disabled(model.downloadingID != nil || app.latest == nil)
        }
    }
}
