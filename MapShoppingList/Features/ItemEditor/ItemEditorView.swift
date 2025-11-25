import SwiftUI

struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let mode: ItemEditorMode
    private let environment: AppEnvironment
    @StateObject private var viewModel: ItemEditorViewModel
    @State private var showDeleteConfirmation = false
    @State private var showPlaceSearch = false
    @State private var showRecentPlaces = false

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
                        .accessibilityIdentifier(UITestIdentifiers.ItemEditor.titleField)
                    TextField("メモ", text: $viewModel.note)
                        .accessibilityIdentifier(UITestIdentifiers.ItemEditor.noteField)
                }

                Section(header: Text("紐付けるお店")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button { showPlaceSearch = true } label: {
                            Label("Googleで地点を検索", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button { showRecentPlaces = true } label: {
                            Label("最近使った地点から選ぶ", systemImage: "clock")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier(UITestIdentifiers.ItemEditor.recentPlacesButton)
                    }

                    let selectedPlaces = viewModel.selectedPlaces()
                    if selectedPlaces.isEmpty {
                        Text("地点が選択されていません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedPlaces, id: \.id) { place in
                            SelectedPlaceRow(place: place) {
                                viewModel.removePlace(place)
                            }
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Text(message)
                            .foregroundColor(.appError)
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
                    .accessibilityIdentifier(UITestIdentifiers.ItemEditor.saveButton)
                }
                ToolbarItem(placement: .bottomBar) {
                    if case .edit = mode {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Label("アイテムを削除", systemImage: "trash")
                                .foregroundColor(.appTertiary)
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
            .sheet(isPresented: $showPlaceSearch) {
                if #available(iOS 18.0, *) {
                    PlaceSearchView(environment: environment) { place in
                        viewModel.handlePlaceCreated(place)
                    }
                    .presentationSizing(.page)
                } else {
                    PlaceSearchView(environment: environment) { place in
                        viewModel.handlePlaceCreated(place)
                    }
                }
            }
            .sheet(isPresented: $showRecentPlaces) {
                if #available(iOS 18.0, *) {
                    RecentPlacesPickerView(environment: environment, initialSelection: viewModel.selectedPlaceIds) { selection in
                        viewModel.selectedPlaceIds = selection
                    }
                    .presentationSizing(.page)
                } else {
                    RecentPlacesPickerView(environment: environment, initialSelection: viewModel.selectedPlaceIds) { selection in
                        viewModel.selectedPlaceIds = selection
                    }
                }
            }
        }
    }
}

private struct SelectedPlaceRow: View {
    let place: Place
    let remove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(place.name)
                if let note = place.note, note.isEmpty == false {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.appTertiary)
            }
            .buttonStyle(.borderless)
        }
        .accessibilityIdentifier(UITestIdentifiers.ItemEditor.selectedPlacePrefix + place.name)
    }
}
