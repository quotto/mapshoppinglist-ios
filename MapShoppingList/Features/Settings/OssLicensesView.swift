import SwiftUI

struct OssLicensesView: View {
    private let licenses: [OSSItem] = [
        .init(name: "Google Maps SDK for iOS", repository: "https://developers.google.com/maps/documentation/ios-sdk", license: "Apache License 2.0"),
        .init(name: "Google Places SDK for iOS", repository: "https://developers.google.com/places/ios-sdk", license: "Apache License 2.0"),
        .init(name: "Swift Collections", repository: "https://github.com/apple/swift-collections", license: "Apache License 2.0")
    ]

    var body: some View {
        NavigationView {
            List(licenses) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.repository)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(item.license)
                        .font(.footnote)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("OSSライセンス")
        }
    }

    private struct OSSItem: Identifiable {
        let id = UUID()
        let name: String
        let repository: String
        let license: String
    }
}
