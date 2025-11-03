import SwiftPackageList

@main
struct Tool {
    static func main() async throws {
        var command = SwiftPackageList.main
        try await command()
    }
}
