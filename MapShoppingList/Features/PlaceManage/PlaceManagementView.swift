import SwiftUI

struct PlaceManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaceManagementViewModel
    @State private var showDeleteAlert: PlaceManagementViewModel.Row?
    @State private var showCreation = false
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: PlaceManagementViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            listContent
                .overlay { ProgressView().opacity(viewModel.isLoading ? 1 : 0) }
                .navigationTitle("地点管理")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { showCreation = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .task { await viewModel.load() }
                .alert("削除確認", isPresented: deleteAlertBinding) {
                    Button("削除",role: .destructive) {
                        if let place = showDeleteAlert {
                            Task { await viewModel.delete(place: place) }
                        }
                        showDeleteAlert = nil
                    }
                    .foregroundColor(.appTertiary)
                    Button("キャンセル", role: .cancel) { showDeleteAlert = nil }
                } message: {
                    Text("選択した地点を削除します。よろしいですか？")
                }
                .sheet(item: $viewModel.renamingPlace) { place in
                    if #available(iOS 18.0, *) {
                        RenamePlaceSheet(place: place, newName: $viewModel.newName) {
                            Task { await viewModel.commitRename() }
                        }
                        .presentationSizing(.page)
                    } else {
                        RenamePlaceSheet(place: place, newName: $viewModel.newName) {
                            Task { await viewModel.commitRename() }
                        }
                    }
                }
                .sheet(isPresented: $showCreation, onDismiss: { Task { await viewModel.load() } }) {
                    if #available(iOS 18.0, *) {
                        PlaceCreationView(environment: environment)
                            .presentationSizing(.page)
                    } else {
                        PlaceCreationView(environment: environment)
                    }
                }
        }
    }
    
    private var listContent: some View {
        List {
            ForEach(viewModel.places) { place in
                placeRow(for: place)
            }
            if viewModel.places.isEmpty && viewModel.isLoading == false {
                Text("登録されている地点がありません").foregroundStyle(.secondary)
            }
        }
    }
    
    private func placeRow(for place: PlaceManagementViewModel.Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(place.name)
                    .font(.headline)
                    .accessibilityIdentifier(UITestIdentifiers.PlaceManagement.rowPrefix + place.name)
                if place.isActive {
                    activeBadge
                }
                Spacer()
                Button {
                    showDeleteAlert = place
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.appTertiary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(place.name)を削除")
                .accessibilityIdentifier(UITestIdentifiers.PlaceManagement.deleteButtonPrefix + place.name)
            }

            if let address = place.address, address.isEmpty == false {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let lastUsedAt = place.lastUsedAt {
                Text("最終利用: \(formatted(date: lastUsedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.beginRenaming(place: place)
        }
        .accessibilityIdentifier(UITestIdentifiers.PlaceManagement.rowPrefix + place.name)
    }
    
    private var deleteAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { showDeleteAlert != nil },
            set: { if !$0 { showDeleteAlert = nil } }
        )
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var activeBadge: some View {
        Text("アクティブ")
            .font(.caption)
            .foregroundColor(.appSuccess)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appSuccess.opacity(0.15), in: Capsule())
    }
}

private struct RenamePlaceSheet: View {
    let place: PlaceManagementViewModel.Row
    @Binding var newName: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(place.name)) {
                    TextField("新しい名称", text: $newName)
                        .accessibilityIdentifier(UITestIdentifiers.PlaceManagement.renameTextField)
                }
            }
            .navigationTitle("名称変更")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
