import Foundation

enum LaunchArguments {
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("UITests")
}
