import Testing
@testable import MapShoppingList

@Suite("CoreDataStackTests", .disabled("CoreDataの永続化はUIテストで担保"))
struct CoreDataStackTests {
    @Test("placeholder")
    func placeholder() {}
}
