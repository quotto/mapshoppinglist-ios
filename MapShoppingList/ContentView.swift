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
            ZStack {
                NavigationView {

                    ZStack(alignment: .bottomTrailing) {
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
                            if viewModel.pendingItems.isEmpty,
                               viewModel.purchasedItems.isEmpty,
                               viewModel.isLoading == false {
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
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityIdentifier(UITestIdentifiers.Home.emptyState)
                                }
                            }
                        }
                    .overlay { ProgressView().opacity(viewModel.isLoading ? 1 : 0) }
                    .task {
                        let shouldHandlePermissions = LaunchArguments.isUITesting == false
                            && LaunchArguments.isRunningTests == false
                        if shouldHandlePermissions {
                            await permissionViewModel.refreshStatuses()
                            await permissionViewModel.requestLocationAuthorization()
                            await environment.geofenceCoordinator.syncActiveGeofences()
                        }
                        await viewModel.load()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .geofenceNeedsSync)) { _ in
                        guard LaunchArguments.isUITesting == false,
                              LaunchArguments.isRunningTests == false else { return }
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
                    .sheet(
                        item: $editorConfig,
                        onDismiss: { Task { await viewModel.load() } },
                        content: { config in
                            if #available(iOS 18.0, *) {
                                ItemEditorView(mode: config.mode, environment: environment)
                                    .presentationSizing(.page)
                            } else {
                                ItemEditorView(mode: config.mode, environment: environment)
                            }
                        }
                    )
                    .sheet(isPresented: $showPlaceManagement) {
                        if #available(iOS 18.0, *) {
                            PlaceManagementView(environment: environment)
                                .presentationSizing(.page)
                        } else {
                            PlaceManagementView(environment: environment)
                        }
                    }
                    .sheet(isPresented: $showPrivacyPolicy) {
                        if #available(iOS 18.0, *) {
                            PrivacyPolicyView()
                                .presentationSizing(.page)
                        } else {
                            PrivacyPolicyView()
                        }
                    }
                    .sheet(isPresented: $showOssLicenses) {
                        if #available(iOS 18.0, *) {
                            OssLicensesView()
                                .presentationSizing(.page)
                        } else {
                            OssLicensesView()
                        }
                    }

                    // フローティングアクションボタン
                    FloatingActionButton {
                        editorConfig = EditorConfig(mode: .create)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .accessibilityIdentifier(UITestIdentifiers.Home.fabAddItem)
                }
                    .navigationTitle("買い物リスト")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSidebar = true
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .accessibilityLabel("メニュー")
                                    .accessibilityIdentifier(UITestIdentifiers.Home.menuButton)
                            }
                        }
                    }
            }
                .navigationViewStyle(.stack)

            // 左側からスライドインするサイドバー
            SlidingSidebarMenuView(
                showPlaceManagement: $showPlaceManagement,
                showPrivacyPolicy: $showPrivacyPolicy,
                showOssLicenses: $showOssLicenses,
                isPresented: $showSidebar
            )
        }
    }
}

/// フローティングアクションボタン（Android版と同様に右下配置）
private struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundStyle(Color.appOnTertiary)
                .frame(width: 56, height: 56)
                .background(Color.appPrimaryContainer)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel("アイテムを追加")
        .accessibilityIdentifier(UITestIdentifiers.Home.fabAddItem)
    }
}

/// 左側からスライドインするサイドバーメニュー
private struct SlidingSidebarMenuView: View {
    @Binding var showPlaceManagement: Bool
    @Binding var showPrivacyPolicy: Bool
    @Binding var showOssLicenses: Bool
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // 背景のオーバーレイ（タップで閉じる）
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
            }

            // サイドバーメニュー
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // ヘッダー
                    HStack {
                        Text("メニュー")
                            .font(.headline)
                            .foregroundStyle(Color.appOnSurface)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(Color.appOnSurface)
                                .accessibilityLabel("閉じる")
                        }
                    }
                    .padding()
                    .background(Color.appSurface)

                    Divider()

                    // メニュー項目
                    VStack(alignment: .leading, spacing: 0) {
                MenuItemButton(
                    icon: "mappin.and.ellipse",
                    title: "地点管理",
                    identifier: UITestIdentifiers.Menu.placeManagement
                ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showPlaceManagement = true
                            }
                        }

                        Divider().padding(.leading, 56)

                MenuItemButton(
                    icon: "lock.doc",
                    title: "プライバシーポリシー",
                    identifier: UITestIdentifiers.Menu.privacyPolicy
                ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showPrivacyPolicy = true
                            }
                        }

                        Divider().padding(.leading, 56)

                MenuItemButton(
                    icon: "doc.text",
                    title: "OSSライセンス",
                    identifier: UITestIdentifiers.Menu.ossLicenses
                ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showOssLicenses = true
                            }
                        }

                        Spacer()
                    }
                    .background(Color.appSurface)
                }
                .frame(width: 280)
                .background(Color.appSurface)
                .offset(x: isPresented ? 0 : -280)

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
        .allowsHitTesting(isPresented)
    }
}

/// メニュー項目ボタン
private struct MenuItemButton: View {
    let icon: String
    let title: String
    let identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.appOnSurface)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(Color.appOnSurface)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "")
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
            .accessibilityIdentifier(UITestIdentifiers.Home.checkboxPrefix + item.title)

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
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(UITestIdentifiers.Home.itemRowPrefix + item.title)
    }
}
