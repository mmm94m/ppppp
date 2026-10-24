import SwiftUI

struct SourcesView: View {
    @ObservedObject private var sourceStore = SourceStore.shared
    @StateObject private var model = AppDownloadModel()
    @State private var showingAddSheet = false

    var body: some View {
        Group {
            if sourceStore.sources.isEmpty {
                emptyState
            } else {
                feed
            }
        }
        .siScreen()
        .navigationTitle("Sources")
        .navigationDestination(for: RepositorySource.self) { source in
            SourceDetailView(sourceID: source.id)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSourceSheet()
        }
        .sheet(isPresented: Binding(get: { model.signEntryID != nil }, set: { if !$0 { model.signEntryID = nil } })) {
            if let entryID = model.signEntryID {
                SigningSheetView(entryID: entryID)
            }
        }
        .alert("Download Failed", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            sourceStore.ensureDefaultSource()
            await sourceStore.refreshAll()
        }
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SISpacing.lg) {
                ForEach(sourceStore.sources) { source in
                    sourceSection(source)
                }
            }
            .padding(.horizontal, SISpacing.md)
            .padding(.vertical, SISpacing.sm)
        }
        .refreshable {
            await sourceStore.refreshAll()
        }
    }

    private func sourceSection(_ source: RepositorySource) -> some View {
        let apps = sourceStore.apps(for: source)
        return VStack(alignment: .leading, spacing: SISpacing.sm + 2) {
            NavigationLink(value: source) {
                SourceHeader(source: source)
            }
            .buttonStyle(.siPressableCard)
            .contextMenu {
                Button {
                    Task { await sourceStore.refresh(source) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    sourceStore.removeSource(source)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }

            if apps.isEmpty {
                if sourceStore.loading.contains(source.id) {
                    HStack(spacing: SISpacing.sm) {
                        ProgressView()
                        Text("Loading apps…")
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SISpacing.lg)
                } else if sourceStore.failed.contains(source.id) {
                    VStack(spacing: SISpacing.sm) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(SIColor.textSecondary)
                        Text("Couldn't reach that source.")
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                        Button("Try Again") {
                            Task { await sourceStore.refresh(source) }
                        }
                        .buttonStyle(.siSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SISpacing.lg)
                }
            } else {
                ForEach(apps) { app in
                    RepositoryAppCard(app: app, sourceName: source.name, model: model)
                }
            }
        }
    }

    private var emptyState: some View {
        SIEmptyState(
            systemImage: "tray",
            title: "No sources yet",
            message: "Add an AltStore or ESign-compatible repo URL to browse and sign apps straight from it."
        ) {
            Button("Add Source") { showingAddSheet = true }
                .buttonStyle(.siPrimary)
        }
    }
}

struct SourceHeader: View {
    let source: RepositorySource

    var body: some View {
        HStack(spacing: SISpacing.md) {
            RemoteIcon(url: source.iconURL, name: source.name, cornerRadius: 11)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(SIColor.textPrimary)
                    .lineLimit(1)
                Text(source.subtitle ?? source.url.host ?? "")
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(source.appCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(SIColor.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(SIColor.accentMuted, in: Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SIColor.textSecondary)
        }
        .contentShape(Rectangle())
    }
}
