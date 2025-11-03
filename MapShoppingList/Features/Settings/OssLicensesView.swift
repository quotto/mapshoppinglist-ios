import SwiftUI

struct OssLicensesView: View {
    private let acknowledgements = AcknowledgementsLoader.load()

    var body: some View {
        NavigationView {
            List(acknowledgements) { ack in
                VStack(alignment: .leading, spacing: 6) {
                    Text(ack.title)
                        .font(.headline)
                    if let source = ack.source {
                        Text(source)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let license = ack.licenseText {
                        Text(license)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("OSSライセンス")
            .overlay {
                if acknowledgements.isEmpty {
                    Text("OSSライセンス情報がありません")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private enum AcknowledgementsLoader {
    private static let fileName = "S8Acknowledgements"

    static func load() -> [Acknowledgement] {
        guard
            let url = Bundle.main.url(forResource: fileName, withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let array = plist as? [[String: Any]]
        else {
            return []
        }

        return array.compactMap { dict in
            guard let title = dict["identity"] as? String else { return nil }
            let source = dict["source"] as? String
            let license = dict["license"] as? String
            return Acknowledgement(title: title, source: source, licenseText: license)
        }
    }
}

private struct Acknowledgement: Identifiable {
    let id = UUID()
    let title: String
    let source: String?
    let licenseText: String?
}
