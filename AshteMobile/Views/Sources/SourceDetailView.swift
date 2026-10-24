import SwiftUI

struct SourceDetailView: View {
    let sourceID: UUID

    @ObservedObject private var sourceStore = SourceStore.shared
    @StateObject private var model = AppDownloadModel()

    private var source: RepositorySource? {
        sourceStore.sources.first { $0.id == sourceID }
    }

    var body: some View {
        Group {
            if let source {
                ScrollView {
                    LazyVStack(spacing: SISpacing.sm + 2) {
                        ForEach(sourceStore.apps(for: source)) { app in
                            RepositoryAppCard(app: app, sourceName: source.name, model: model)
                        }
                    }
                    .padding(.horizontal, SISpacing.md)
                    .padding(.vertical, SISpacing.sm)
                }
                .refreshable {
                    await sourceStore.refresh(source)
                }
            }
        }
        .siScreen()
        .task {
            if let source, sourceStore.apps(for: source).isEmpty {
                await sourceStore.refresh(source)
            }
        }
        .navigationTitle(source?.name ?? "Source")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Download Failed", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(isPresented: Binding(get: { model.signEntryID != nil }, set: { if !$0 { model.signEntryID = nil } })) {
            if let entryID = model.signEntryID {
                SigningSheetView(entryID: entryID)
            }
        }
    }
}
