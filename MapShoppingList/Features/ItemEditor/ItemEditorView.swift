import SwiftUI

struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let mode: ItemEditorMode
    private let environment: AppEnvironment
    @StateObject private var viewModel: ItemEditorViewModel
    @State private var showDeleteConfirmation = false
    @State private var showPlaceSearch = false
    @State private var showPlaceCreation = false

    init(mode: ItemEditorMode, environment: AppEnvironment) {
        self.mode = mode
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ItemEditorViewModel(mode: mode, environment: environment))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("アイテム")) {
                    TextField("タイトル", text: $viewModel.title)
                    TextField("メモ", text: $viewModel.note)
                }

                Section(header: Text("紐付けるお店")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button { showPlaceSearch = true } label: {
                            Label("Googleで地点を検索", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button { showPlaceCreation = true } label: {
                            Label("緯度・経度を手入力", systemImage: "plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                    }
                    if viewModel.availablePlaces.isEmpty {
                        Text("地点が登録されていません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.availablePlaces, id: \.id) { place in
                            PlaceSelectionRow(place: place, isSelected: viewModel.selectedPlaceIds.contains(place.id)) {
                                viewModel.togglePlace(place)
                            }
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode == .create ? "アイテム追加" : "アイテム編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .bottomBar) {
                    if case .edit = mode {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("アイテムを削除", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
            .overlay { ProgressView().opacity(viewModel.isLoading ? 1 : 0) }
            .task { await viewModel.load() }
            .confirmationDialog("アイテムを削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    Task {
                        if await viewModel.deleteCurrentItem() { dismiss() }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showPlaceCreation, onDismiss: { Task { await viewModel.load() } }) {
                PlaceCreationView(environment: environment)
            }
            .sheet(isPresented: $showPlaceSearch) {
                PlaceSearchView(environment: environment) { place in
                    viewModel.handlePlaceCreated(place)
                }
            }
        }
    }
}

private struct PlaceSelectionRow: View {
    let place: Place
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text(place.name)
                    if let note = place.note, note.isEmpty == false {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
