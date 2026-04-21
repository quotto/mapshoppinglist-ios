import SwiftUI

/// 左側からスライドインするサイドバーメニュー
struct SlidingSidebarMenuView: View {
    @Binding var showPlaceManagement: Bool
    @Binding var showPrivacyPolicy: Bool
    @Binding var showOssLicenses: Bool
    @Binding var showNearbyDebugLogs: Bool
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
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

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
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

                    VStack(alignment: .leading, spacing: 0) {
                        SidebarMenuItem(
                            icon: "mappin.and.ellipse",
                            title: "地点管理",
                            identifier: UITestIdentifiers.Menu.placeManagement
                        ) {
                            presentMenuDestination { showPlaceManagement = true }
                        }

                        Divider().padding(.leading, 56)

                        SidebarMenuItem(
                            icon: "lock.doc",
                            title: "プライバシーポリシー",
                            identifier: UITestIdentifiers.Menu.privacyPolicy
                        ) {
                            presentMenuDestination { showPrivacyPolicy = true }
                        }

                        Divider().padding(.leading, 56)

                        SidebarMenuItem(
                            icon: "doc.text",
                            title: "OSSライセンス",
                            identifier: UITestIdentifiers.Menu.ossLicenses
                        ) {
                            presentMenuDestination { showOssLicenses = true }
                        }

                        if AppBuildFlags.isNearbyDebugLoggingEnabled {
                            Divider().padding(.leading, 56)

                            SidebarMenuItem(
                                icon: "text.document",
                                title: "デバッグログ",
                                identifier: UITestIdentifiers.Menu.debugLogs
                            ) {
                                presentMenuDestination { showNearbyDebugLogs = true }
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

private extension SlidingSidebarMenuView {
    func presentMenuDestination(_ action: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            action()
        }
    }
}

private struct SidebarMenuItem: View {
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
