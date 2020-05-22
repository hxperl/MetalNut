import XCTest
@testable import MetalNut

final class MetalNutTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MetalNut().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
