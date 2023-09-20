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
        let searcher = Fusion(people)
        // searcher.search(for: "Bob")
    }
    
    func testUnicodeFuzzyMatch() {
        let fusion = Fusion(people, foldingOptions: [.caseInsensitive, .diacriticInsensitive])
        let parameters: [String: [String: Bool]] = [
            "👁️👄👁️": ["👁️🫦👁️": true],
            "Nearest café": ["According to this map, the nearest café is 1.2 miles away.": true],
            "Nearest cafe": ["According to this map, the nearest café is 1.2 miles away.": true],
            "öçpé": ["ocpe": true],
            "ocpe": ["öçpé": true],
            "café": ["D\u{2019}après cette carte, le café le plus proche se trouve à 2 km.": true],
            "coffee": ["D\u{2019}après cette carte, le café le plus proche se trouve à 2 km.": false],
            "wheat": ["D\u{2019}après cette carte, le café le plus proche se trouve à 2 km.": false]

        ]
        
        for (query, target) in parameters {
            // Maybe a tuple or something else will do instead.
            let answer = target.values.first!
            let targetString = target.keys.first!
            let computedAnswer = fusion.unicodeFuzzyMatch(query, targetString)
            
            if answer {
                XCTAssert(computedAnswer)
            } else {
                XCTAssertFalse(computedAnswer)
            }
        }
    }
    
    func testASCIIViolation() {
        
    }
}
