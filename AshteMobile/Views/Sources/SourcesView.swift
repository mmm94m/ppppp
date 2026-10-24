import SwiftUI

private struct SourceApp: Identifiable {
    let app: RepositoryApp
    let sourceName: String
    let sourceID: UUID
    var id: String { sourceID.uuidString + "|" + app.id }
}

struct SourcesView: View {
    @ObservedObject private var sourceStore = SourceStore.shared
    @StateObject private var model = AppDownloadModel()
    @State private var showingAddSheet = false
    @State private var showingManageSheet = false
    @State private var searchText = ""
    @State private var category: AppCategory = .all

    private var allItems: [SourceApp] {
        sourceStore.sources.flatMap { source in
            sourceStore.apps(for: source).map { SourceApp(app: $0, sourceName: source.name, sourceID: source.id) }
        }
    }

    private var isLoading: Bool { !sourceStore.loading.isEmpty }

    var body: some View {
        let items = allItems
        let counts = Dictionary(grouping: items, by: { $0.app.kind }).mapValues(\.count)
        let visible = filter(items)

        return Group {
            if sourceStore.sources.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    header(counts: counts, total: items.count)
                    content(items: items, visible: visible)
                }
            }
        }
        .siScreen()
        .navigationTitle("Sources")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button {
                        Task { await sourceStore.refreshAll() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Button {
                        showingManageSheet = true
                    } label: {
                        Label("Manage Sources", systemImage: "tray.2")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
        .sheet(isPresented: $showingManageSheet) {
            ManageSourcesSheet()
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

    private func filter(_ items: [SourceApp]) -> [SourceApp] {
        var list = items
        if category != .all {
            list = list.filter { $0.app.kind == category }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter {
                $0.app.name.localizedCaseInsensitiveContains(query) ||
                $0.app.bundleIdentifier.localizedCaseInsensitiveContains(query)
            }
        }
        return list
    }

    // MARK: - Header

    private func header(counts: [AppCategory: Int], total: Int) -> some View {
        VStack(spacing: SISpacing.sm + 2) {
            HStack(spacing: SISpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SIColor.textSecondary)
                TextField("Search apps…", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundStyle(SIColor.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SIColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SISpacing.md)
            .padding(.vertical, 12)
            .background(SIColor.surface, in: RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SIRadius.lg, style: .continuous).stroke(SIColor.border.opacity(0.6), lineWidth: 0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SISpacing.sm) {
                    ForEach(AppCategory.allCases) { item in
                        let count = item == .all ? total : (counts[item] ?? 0)
                        if item == .all || count > 0 {
                            chip(item, count: count)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, SISpacing.md)
        .padding(.bottom, SISpacing.sm)
    }

    private func chip(_ item: AppCategory, count: Int) -> some View {
        let selected = category == item
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { category = item }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(item.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(selected ? Color.black.opacity(0.18) : SIColor.surfaceElevated, in: Capsule())
            }
            .foregroundStyle(selected ? SIColor.onAccent : SIColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if selected {
                    Capsule().fill(LinearGradient(colors: [SIColor.accent, SIColor.accent.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: SIColor.accent.opacity(0.35), radius: 8, y: 3)
                } else {
                    Capsule().fill(SIColor.surface)
                        .overlay(Capsule().stroke(SIColor.border.opacity(0.7), lineWidth: 0.5))
                }
            }
        }
        .buttonStyle(.siPressableCard)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(items: [SourceApp], visible: [SourceApp]) -> some View {
        if items.isEmpty {
            VStack(spacing: SISpacing.md) {
                Spacer()
                if isLoading {
                    ProgressView().tint(SIColor.accent)
                    Text("Loading apps…")
                        .font(SIFont.caption)
                        .foregroundStyle(SIColor.textSecondary)
                } else {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(SIColor.textSecondary)
                    Text("Couldn't reach that source.")
                        .font(SIFont.caption)
                        .foregroundStyle(SIColor.textSecondary)
                    Button("Try Again") {
                        Task { await sourceStore.refreshAll() }
                    }
                    .buttonStyle(.siSecondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if visible.isEmpty {
            VStack(spacing: SISpacing.sm) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(SIColor.textSecondary)
                Text("No apps found")
                    .font(SIFont.headline)
                    .foregroundStyle(SIColor.textPrimary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: SISpacing.sm + 2) {
                    ForEach(visible) { item in
                        RepositoryAppCard(app: item.app, sourceName: item.sourceName, model: model)
                    }
                }
                .padding(.horizontal, SISpacing.md)
                .padding(.bottom, SISpacing.md)
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                await sourceStore.refreshAll()
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

struct ManageSourcesSheet: View {
    @ObservedObject private var sourceStore = SourceStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sourceStore.sources) { source in
                    SourceHeader(source: source)
                        .listRowBackground(SIColor.surface)
                        .swipeActions {
                            Button(role: .destructive) {
                                sourceStore.removeSource(source)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.insetGrouped)
            .siScreen()
            .navigationTitle("Manage Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
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
                    .font(.system(.headline, design: .rounded))
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
        }
        .contentShape(Rectangle())
    }
}
