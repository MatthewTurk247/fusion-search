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
    
    func testEncodings() {
        let fusion = Fusion(people, foldingOptions: [.caseInsensitive, .diacriticInsensitive])
        print("öçpé".folding(options: .diacriticInsensitive, locale: .current))
        print(fusion.unicodeFuzzyMatch("👁️👄👁️", "👁️🫦👁️"))
        print(fusion.unicodeFuzzyMatch("Nearest café", "According to this map, the nearest café is 1.2 miles away."))
        print(fusion.unicodeFuzzyMatch("Nearest cafe", "According to this map, the nearest café is 1.2 miles away."))
        print(fusion.unicodeFuzzyMatch("café", "D\u{2019}après cette carte, le café le plus proche se trouve à 2 km."))
        print(fusion.unicodeFuzzyMatch("öçpé", "ocpe"))
        print(fusion.unicodeFuzzyMatch("ocpe", "öçpé"))
    }
}
