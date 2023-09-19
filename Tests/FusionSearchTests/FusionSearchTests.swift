import XCTest
@testable import FusionSearch

class Person {
    let name: String
    let address: String
    // Will test more properties soon...
    
    init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}

final class FusionSearchTests: XCTestCase {
    let people = [Person(name: "Alice", address: "123 Elm Street"), Person(name: "Bob", address: "432 Fake Street")]
    
    func testPersonSearch() throws {
        let fusion = Fusion(people)
        fusion.defaultKeyPaths = [\.name, \.address]
        var results: [Person] = []
        self.measure {
            results = fusion.search(for: "Street")
        }
        XCTAssertEqual(results.count, 2)
        results = fusion.search(for: "Bob")
        XCTAssertEqual(results.count, 1)
    }
    
    func testPersonEmptyDefaultKeyPaths() throws {
        // searcher.search(for: "Bob")
    }
}
