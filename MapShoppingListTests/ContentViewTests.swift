import XCTest
@testable import MapShoppingList

@MainActor
final class ContentViewTests: XCTestCase {
    func testListShowsSections() throws {
        let environment = AppEnvironment(stack: .makeInMemory())
        let view = ContentView(environment: environment)
        XCTAssertNotNil(view)
    }
}
