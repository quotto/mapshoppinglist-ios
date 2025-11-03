import SwiftUI
import CoreLocation

struct PermissionPromptSection: View {
    @ObservedObject var viewModel: PermissionStatusViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            if viewModel.needsLocationPrompt {
                PermissionPromptCard(
                    icon: "location.circle",
                    title: "位置情報の許可設定",
                    message: viewModel.locationMessage,
                    primaryTitle: "設定を開く",
                    isPrimaryLoading: viewModel.isRequestingLocation,
                    primaryAction: {
                        handleLocationPrimaryAction()
                    },
                    secondaryTitle: nil,
                    secondaryAction: nil
                )
            }

            if viewModel.needsNotificationPrompt {
                PermissionPromptCard(
                    icon: "bell.circle",
                    title: "通知の許可設定",
                    message: viewModel.notificationMessage,
                    primaryTitle: viewModel.notificationPrimaryButtonTitle,
                    isPrimaryLoading: viewModel.isRequestingNotification,
                    primaryAction: {
                        handleNotificationPrimaryAction()
                    },
                    secondaryTitle: nil,
                    secondaryAction: nil
                )
            }
        }
        .padding(.horizontal, 16)
        .background(Color(uiColor: .systemGroupedBackground))
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private func handleLocationPrimaryAction() {
        switch viewModel.locationStatus {
        case .authorizedAlways:
            break
        default:
            viewModel.openSettings()
        }
    }

    private func handleNotificationPrimaryAction() {
        switch viewModel.notificationStatus {
        case .notDetermined:
            Task { await viewModel.requestNotificationAuthorization() }
        case .denied, .provisional, .ephemeral:
            viewModel.openSettings()
        case .authorized:
            break
        @unknown default:
            viewModel.openSettings()
        }
    }
}

private struct PermissionPromptCard: View {
    let icon: String
    let title: String
    let message: String
    let primaryTitle: String
    let isPrimaryLoading: Bool
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(action: primaryAction) {
                    if isPrimaryLoading {
                        ProgressView()
                    } else {
                        Text(primaryTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPrimaryLoading || primaryTitle.isEmpty)

                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle) {
                        secondaryAction()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}
