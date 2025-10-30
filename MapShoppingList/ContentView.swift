import SwiftUI

private struct EditorConfig: Identifiable {
    let mode: ItemEditorMode
    var id: String {
        switch mode {
        case .create: return "create"
        case let .edit(id): return id.uuidString
        }
    }
}

struct ContentView: View {
    private let environment: AppEnvironment
    @StateObject private var viewModel: ShoppingListViewModel
    @State private var editorConfig: EditorConfig?
    @State private var showPlaceManagement = false

    init(environment: AppEnvironment = AppEnvironment()) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ShoppingListViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            List {
                if !viewModel.pendingItems.isEmpty {
                    Section("未購入") {
                        ForEach(viewModel.pendingItems) { item in
                            ShoppingItemRowView(item: item) {
                                Task { await viewModel.togglePurchased(item: item) }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(item: item) }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { editorConfig = EditorConfig(mode: .edit(item.id)) }
                        }
                    }
                }
                if !viewModel.purchasedItems.isEmpty {
                    Section("購入済み") {
                        ForEach(viewModel.purchasedItems) { item in
                            ShoppingItemRowView(item: item) {
                                Task { await viewModel.togglePurchased(item: item) }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(item: item) }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { editorConfig = EditorConfig(mode: .edit(item.id)) }
                        }
                    }
                }
                if viewModel.pendingItems.isEmpty && viewModel.purchasedItems.isEmpty && viewModel.isLoading == false {
                    VStack(alignment: .center) {
                        Image(systemName: "cart")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("アイテムがありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .overlay { ProgressView().opacity(viewModel.isLoading ? 1 : 0) }
            .navigationTitle("買い忘れリスト")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { editorConfig = EditorConfig(mode: .create) } label: {
                        Image(systemName: "plus")
                    }
                    Button { showPlaceManagement = true } label: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                }
            }
            .task { await viewModel.load() }
            .alert("エラー", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $editorConfig, onDismiss: { Task { await viewModel.load() } }) { config in
                ItemEditorView(mode: config.mode, environment: environment)
            }
            .sheet(isPresented: $showPlaceManagement) {
                PlaceManagementView(environment: environment)
            }
        }
    }
}

private struct ShoppingItemRowView: View {
    let item: ShoppingListViewModel.ItemRow
    let toggleAction: () -> Void

    var body: some View {
        HStack {
            Button(action: toggleAction) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                if item.placeCount > 0 {
                    Text("紐付くお店: \(item.placeCount)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
