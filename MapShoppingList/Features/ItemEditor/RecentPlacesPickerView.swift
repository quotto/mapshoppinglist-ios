import SwiftUI

struct RecentPlacesPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RecentPlacesPickerViewModel
    private let onApply: (Set<UUID>) -> Void

    init(environment: AppEnvironment, initialSelection: Set<UUID>, onApply: @escaping (Set<UUID>) -> Void) {
        self.onApply = onApply
        _viewModel = StateObject(wrappedValue: RecentPlacesPickerViewModel(environment: environment, initialSelection: initialSelection))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let message = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(message)
                            .foregroundStyle(.secondary)
                        Button("再試行") {
                            Task { await viewModel.load() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.places.isEmpty {
                    Text("最近の地点がありません")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.places, id: \.id) { place in
                        Button {
                            viewModel.toggle(place: place)
                        } label: {
                            HStack {
                                Image(systemName: viewModel.selectedIds.contains(place.id) ? "checkmark.circle.fill" : "circle")
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
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("最近使った地点")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        onApply(viewModel.selectedIds)
                        dismiss()
                    }
                    .disabled(viewModel.selectedIds.isEmpty)
                }
            }
            .task { await viewModel.load() }
        }
    }
}
