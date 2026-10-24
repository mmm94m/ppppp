import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject private var library = AppLibraryStore.shared
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var showingDownloadSheet = false
    @State private var selection = Set<UUID>()
    @State private var isSelecting = false
    @State private var showingBatchSheet = false
    @State private var importError: String?
    @State private var isImporting = false
    @State private var importingCount = 0

    private var filteredApps: [AppEntry] {
        guard !searchText.isEmpty else { return library.apps }
        return library.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if library.apps.isEmpty && !isImporting {
                emptyState
            } else {
                libraryList
            }
        }
        .overlay {
            if isImporting {
                importingOverlay
            }
        }
        .siScreen()
        .navigationTitle("Library")
        .navigationDestination(for: AppEntry.self) { entry in
            AppDetailView(entryID: entry.id)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !library.apps.isEmpty {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        selection.removeAll()
                    }
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isSelecting {
                    Button("Sign All") { showingBatchSheet = true }
                        .disabled(selection.isEmpty)
                } else {
                    Menu {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import IPA", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showingDownloadSheet = true
                        } label: {
                            Label("Download from URL", systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isImporting)
                }
            }
        }
        .sheet(isPresented: $showingImporter) {
            DocumentPickerView(contentTypes: [.data, .item], allowsMultipleSelection: true) { urls in
                handleImport(urls)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingDownloadSheet) {
            DownloadByURLSheet()
        }
        .sheet(isPresented: $showingBatchSheet) {
            BatchQueueView(entryIDs: Array(selection))
                .onDisappear {
                    isSelecting = false
                    selection.removeAll()
                }
        }
        .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private var libraryList: some View {
        ScrollView {
            LazyVStack(spacing: SISpacing.sm + 2) {
                ForEach(filteredApps) { entry in
                    libraryRow(for: entry)
                        .contextMenu {
                            Button(role: .destructive) {
                                library.remove(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, SISpacing.md)
            .padding(.vertical, SISpacing.sm)
        }
        .searchable(text: $searchText, prompt: Text("Search your library"))
    }

    @ViewBuilder
    private func libraryRow(for entry: AppEntry) -> some View {
        if isSelecting {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { toggleSelection(entry) }
            } label: {
                AppRow(entry: entry, isSelected: selection.contains(entry.id))
            }
            .buttonStyle(.siPressableCard)
        } else {
            NavigationLink(value: entry) {
                AppRow(entry: entry, isSelected: false)
            }
            .buttonStyle(.siPressableCard)
        }
    }

    private var emptyState: some View {
        SIEmptyState(
            systemImage: "square.stack.3d.up",
            title: "Your library is empty",
            message: "Import an IPA, download one from a source, or share one in from another app."
        ) {
            Button("Import IPA") { showingImporter = true }
                .buttonStyle(.siPrimary)
        }
    }

    private var importingOverlay: some View {
        VStack(spacing: SISpacing.md) {
            ProgressView()
                .tint(SIColor.accent)
            Text(importingCount > 1 ? String(localized: "Importing \(importingCount) apps…") : String(localized: "Importing…"))
                .font(SIFont.headline)
                .foregroundStyle(SIColor.textPrimary)
        }
        .padding(SISpacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SIRadius.md, style: .continuous))
    }

    private func toggleSelection(_ entry: AppEntry) {
        if selection.contains(entry.id) {
            selection.remove(entry.id)
        } else {
            selection.insert(entry.id)
        }
    }

    private func handleImport(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        importingCount = urls.count
        isImporting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.beginImport(urls)
        }
    }

    private func beginImport(_ urls: [URL]) {
        Task {
            var firstError: String?
            for url in urls {
                do {
                    _ = try await library.importIPA(at: url)
                } catch {
                    if firstError == nil { firstError = error.localizedDescription }
                }
            }
            await MainActor.run {
                isImporting = false
                importError = firstError
            }
        }
    }
}

struct AppRow: View {
    let entry: AppEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: SISpacing.md) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(SIColor.accent)
            }

            iconView
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(SIColor.border.opacity(0.6), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(SIColor.textPrimary)
                    .lineLimit(1)
                Text(entry.bundleIdentifier)
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.textSecondary)
                    .lineLimit(1)
                Text("\(entry.displayVersion) · \(entry.displaySize)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(SIColor.textSecondary)
            }

            Spacer(minLength: 8)

            if entry.isSigned {
                StatusBadge(text: String(localized: "Signed"), color: SIColor.success)
            } else {
                StatusBadge(text: String(localized: "Unsigned"), color: SIColor.textSecondary, style: .plain)
            }
        }
        .padding(SISpacing.md)
        .background(SIColor.surface, in: RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous)
                .stroke(isSelected ? SIColor.accent : SIColor.border.opacity(0.5), lineWidth: isSelected ? 2 : 0.5)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL = AppLibraryStore.shared.iconURL(for: entry), let uiImage = UIImage(contentsOfFile: iconURL.path) {
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else {
            ZStack {
                SIColor.accentMuted
                Image(systemName: "app.dashed").font(.system(size: 22)).foregroundStyle(SIColor.accent)
            }
        }
    }
}
