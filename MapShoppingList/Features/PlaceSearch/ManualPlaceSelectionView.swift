import SwiftUI
import CoreLocation

struct ManualPlaceSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    private let environment: AppEnvironment
    private let onPlaceCreated: (Place) -> Void
    @StateObject private var viewModel: ManualPlaceSelectionViewModel
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    init(environment: AppEnvironment, onPlaceCreated: @escaping (Place) -> Void) {
        self.environment = environment
        self.onPlaceCreated = onPlaceCreated
        _viewModel = StateObject(wrappedValue: ManualPlaceSelectionViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("地図を長押しして地点を選択してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ManualPlacePickerMapView(
                        initialCoordinate: selectedCoordinate ?? CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                        selectedCoordinate: selectedCoordinate,
                        onCoordinateSelected: { coordinate in
                            selectedCoordinate = coordinate
                            viewModel.updateCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        }
                    )
                    .frame(height: 280)
                    .cornerRadius(12)

                    coordinateFields
                    nameField
                    noteField

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            if let place = await viewModel.savePlace() {
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
                .padding()
            }
            .navigationTitle("地図から追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .overlay {
                if viewModel.isGeocoding {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        }
    }

    private var coordinateFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("緯度", text: $viewModel.latitudeText)
                .textFieldStyle(.roundedBorder)
            TextField("経度", text: $viewModel.longitudeText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var nameField: some View {
        TextField("名称", text: $viewModel.name)
            .textFieldStyle(.roundedBorder)
    }

    private var noteField: some View {
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
    }
}
