import SwiftUI

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    private let environment: AppEnvironment
    private let onPlaceCreated: (Place) -> Void
    @StateObject private var viewModel: PlaceSearchViewModel
    @State private var showManualSelection = false

    init(environment: AppEnvironment, onPlaceCreated: @escaping (Place) -> Void) {
        self.environment = environment
        self.onPlaceCreated = onPlaceCreated
        _viewModel = StateObject(wrappedValue: PlaceSearchViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                searchField
                predictionsSection
                selectionSection
                Spacer()
            }
            .padding()
            .navigationTitle("地点を検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("店名や施設名を入力", text: $viewModel.query, onCommit: {
                Task { await viewModel.performSearch() }
            })
            .textFieldStyle(.roundedBorder)
            .submitLabel(.search)
            HStack {
                Button {
                    Task { await viewModel.performSearch() }
                } label: {
                    Label("検索", systemImage: "magnifyingglass")
                }
                .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            Button {
                showManualSelection = true
            } label: {
                Label("地図から地点を追加", systemImage: "mappin.circle")
            }
            .buttonStyle(.borderless)
        }
    }

    private var predictionsSection: some View {
        Group {
            if viewModel.predictions.isEmpty {
                if !viewModel.query.isEmpty && viewModel.isSearching == false {
                    Text("候補が見つかりませんでした")
                        .foregroundStyle(.secondary)
                }
            } else {
                List(viewModel.predictions, id: \.id) { prediction in
                    Button {
                        Task { await viewModel.selectPrediction(prediction) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prediction.primaryText)
                                .font(.headline)
                            if let secondary = prediction.secondaryText {
                                Text(secondary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .listStyle(.plain)
                .frame(maxHeight: 200)
            }
        }
    }

    private var selectionSection: some View {
        Group {
            if let details = viewModel.selectedDetails {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.isLoadingDetails {
                        ProgressView()
                    }
                    PlacePreviewMapView(latitude: details.latitude, longitude: details.longitude)
                        .frame(height: 200)
                        .cornerRadius(12)

                    TextField("名称", text: $viewModel.customName)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("メモ (任意)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $viewModel.note)
                            .frame(minHeight: 80)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }

                    Button {
                        Task {
                            if let place = await viewModel.saveSelectedPlace() {
                                onPlaceCreated(place)
                                dismiss()
                            }
                        }
                    } label: {
                        Label("この地点を登録", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving)
                }
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(isPresented: $showManualSelection) {
            ManualPlaceSelectionView(environment: environment) { place in
                viewModel.handlePlaceCreated(place)
                onPlaceCreated(place)
            }
        }
    }
}
