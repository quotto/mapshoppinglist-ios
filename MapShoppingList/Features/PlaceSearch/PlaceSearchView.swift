import SwiftUI
import CoreLocation

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    private let environment: AppEnvironment
    private let onPlaceCreated: (Place) -> Void
    @StateObject private var viewModel: PlaceSearchViewModel

    init(environment: AppEnvironment, onPlaceCreated: @escaping (Place) -> Void) {
        self.environment = environment
        self.onPlaceCreated = onPlaceCreated
        _viewModel = StateObject(wrappedValue: PlaceSearchViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                mapContainer
                infoSection
                saveButton
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

    private var mapContainer: some View {
        ZStack(alignment: .topLeading) {
            PlaceSearchMapView(
                coordinate: viewModel.selectedCoordinate,
                onCoordinateSelected: { coordinate in
                    viewModel.updateCoordinateFromMap(coordinate)
                },
                onPOITapped: { placeID, _, _ in
                    Task { await viewModel.selectPlace(by: placeID) }
                }
            )
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                searchControls
                if viewModel.isPredictionListVisible {
                    predictionsOverlay
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
        .frame(maxHeight: .infinity)
        .overlay {
            if viewModel.isLoadingDetails || viewModel.isGeocoding {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }

    private var searchControls: some View {
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
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var predictionsOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.predictions) { prediction in
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if prediction.id != viewModel.predictions.last?.id {
                    Divider()
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let text = viewModel.displayText {
                Text(text)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var saveButton: some View {
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
        .disabled(viewModel.isSaving || viewModel.selectedCoordinate == nil)
    }
}
