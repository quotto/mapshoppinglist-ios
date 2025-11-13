import Testing
@testable import MapShoppingList

@Suite("ContentViewTests", .disabled("S1/S2のUIはE2Eテストで検証"))
@MainActor
struct ContentViewTests {
    @Test("placeholder")
    func placeholder() {}
}
