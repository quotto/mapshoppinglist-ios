import SwiftUI
import CoreLocation

struct PermissionPromptSection: View {
    @ObservedObject var viewModel: PermissionStatusViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            if viewModel.needsLocationPrompt {
                PermissionPromptCard(
                    identifier: UITestIdentifiers.PermissionPrompt.locationCard,
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
                    identifier: UITestIdentifiers.PermissionPrompt.notificationCard,
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
        .frame(maxWidth: .infinity, alignment: .center)
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
    let identifier: String?
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
                    .foregroundStyle(Color.appPrimary)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.appSecondaryContainer.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .modifier(AccessibilityIdentifierModifier(identifier: identifier))
    }
}

private struct AccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
