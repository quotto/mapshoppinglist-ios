import SwiftUI

struct NearbyDebugLogsView: View {
    @State private var files: [NearbyDebugLogFile] = NearbyDebugLogFiles.list()
    @State private var selectedFile: NearbyDebugLogFile?

    var body: some View {
        NavigationView {
            List(files) { file in
                Button {
                    selectedFile = file
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.headline)
                            .foregroundStyle(Color.appOnSurface)
                        Text(fileMetadataText(file))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("デバッグログ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("更新") {
                        files = NearbyDebugLogFiles.list()
                    }
                }
            }
            .overlay {
                if files.isEmpty {
                    Text("ログファイルがありません")
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(item: $selectedFile) { file in
                NearbyDebugLogDetailView(file: file)
            }
        }
    }

    private func fileMetadataText(_ file: NearbyDebugLogFile) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return "\(file.modifiedAt.formatted(date: .abbreviated, time: .shortened)) " +
            "• \(formatter.string(fromByteCount: file.size))"
    }
}

private struct NearbyDebugLogDetailView: View {
    let file: NearbyDebugLogFile

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(NearbyDebugLogFiles.read(file))
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    Color.clear
                        .frame(height: 1)
                        .id(LogDetailScrollTarget.bottom)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(LogDetailScrollTarget.bottom, anchor: .bottom)
                    }
                } label: {
                    Label("最下部へ", systemImage: "arrow.down.to.line")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding()
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum LogDetailScrollTarget {
    static let bottom = "bottom"
}
