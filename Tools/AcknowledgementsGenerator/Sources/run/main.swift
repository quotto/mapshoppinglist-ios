import SwiftPackageList

@main
struct Tool {
    static func main() async {
        var command = SwiftPackageList.main
        do {
            try await command()
        } catch {
            fputs("swift-package-list failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
