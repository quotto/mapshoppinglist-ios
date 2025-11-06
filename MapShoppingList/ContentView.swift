import SwiftUI
import Combine

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
    @StateObject private var permissionViewModel: PermissionStatusViewModel
    @State private var editorConfig: EditorConfig?
    @State private var showSidebar = false
    @State private var showPlaceManagement = false
    @State private var showPrivacyPolicy = false
    @State private var showOssLicenses = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ShoppingListViewModel(environment: environment))
        _permissionViewModel = StateObject(wrappedValue: PermissionStatusViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            List {
                if permissionViewModel.needsLocationPrompt || permissionViewModel.needsNotificationPrompt {
                    PermissionPromptSection(viewModel: permissionViewModel)
                }
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
                    Section {
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
            }
            .overlay { ProgressView().opacity(viewModel.isLoading ? 1 : 0) }
            .navigationTitle("買い忘れリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSidebar = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .accessibilityLabel("メニュー")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { editorConfig = EditorConfig(mode: .create) } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await permissionViewModel.refreshStatuses()
                await permissionViewModel.requestLocationAuthorization()
                await viewModel.load()
                await environment.geofenceCoordinator.syncActiveGeofences()
            }
            .onReceive(NotificationCenter.default.publisher(for: .geofenceNeedsSync)) { _ in
                Task { await environment.geofenceCoordinator.syncActiveGeofences() }
            }
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
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showOssLicenses) {
                OssLicensesView()
            }
            .sheet(isPresented: $showSidebar) {
                SidebarMenuView(
                    showPlaceManagement: $showPlaceManagement,
                    showPrivacyPolicy: $showPrivacyPolicy,
                    showOssLicenses: $showOssLicenses,
                    isPresented: $showSidebar
                )
            }
        }
    }
}

/// サイドバーメニュービュー
private struct SidebarMenuView: View {
    @Binding var showPlaceManagement: Bool
    @Binding var showPrivacyPolicy: Bool
    @Binding var showOssLicenses: Bool
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                Button {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPlaceManagement = true
                    }
                } label: {
                    Label("地点管理", systemImage: "mappin.and.ellipse")
                        .foregroundStyle(Color.appOnSurface)
                }
                
                Button {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPrivacyPolicy = true
                    }
                } label: {
                    Label("プライバシーポリシー", systemImage: "lock.doc")
                        .foregroundStyle(Color.appOnSurface)
                }
                
                Button {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showOssLicenses = true
                    }
                } label: {
                    Label("OSSライセンス", systemImage: "doc.text")
                        .foregroundStyle(Color.appOnSurface)
                }
            }
            .navigationTitle("メニュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel("閉じる")
                    }
                }
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
