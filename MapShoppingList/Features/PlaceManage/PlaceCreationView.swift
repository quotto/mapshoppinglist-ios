import SwiftUI

struct PlaceCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaceCreationViewModel

    init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: PlaceCreationViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("地点情報")) {
                    TextField("名称", text: $viewModel.name)
                    TextField("緯度 (例: 35.681236)", text: $viewModel.latitudeText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("経度 (例: 139.767125)", text: $viewModel.longitudeText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("メモ", text: $viewModel.note)
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Text(message)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("新しい地点")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task {
                            if await viewModel.createPlace() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .overlay { ProgressView().opacity(viewModel.isSaving ? 1 : 0) }
        }
    }
}
