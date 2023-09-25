import XCTest
import MediaPlayer
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
#if os(iOS)
    func testMediaPlayer() {
        let playlists = MPMediaQuery.playlists().collections
        if let baroqueEssentials: [MPMediaItem] = playlists?.first(where: { $0.value(forProperty: MPMediaPlaylistPropertyName) == "Baroque Essentials" }) {
            let fusion = Fusion(baroqueEssentials, foldingOptions: .caseInsensitive)
            // Can it handle optionals yet?
            fusion.defaultKeyPaths = [\.albumArtist, \.artist, \.composer] // [\.albumTitle, \.albumArtist, \.artist, \.comments, \.composer, \.lyrics, \.genre]
            // Granular
            let compositionsByHandel = fusion.search(for: "Handel")
        }
    }
#endif
    
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
            let computedAnswer = fusion.fuzzyMatch(query, targetString)
            
            if answer {
                XCTAssert(computedAnswer)
            } else {
                XCTAssertFalse(computedAnswer)
            }
        }
    }
    
    func testSearchWithMultipleKeyPaths() {
        struct Book: Equatable {
            let id: UUID = UUID()
            let title: String
            let author: String
        }
        
        let books = [
            Book(title: "Chaos", author: "James Gleick"),
            Book(title: "Why Zebras Don't Have Ulcers", author: "Robert M. Sapolsky")
        ]
        
        let fusion = Fusion(books, bitErrorLimit: 6)
        fusion.defaultKeyPaths = [\Book.title, \Book.author]
        
        let matches = fusion.search(for: "Robert Sapolsky")
        
        XCTAssertEqual(matches.first, books[1])
    }
    
    func testCaseInsensitivity() {
        let fusion = Fusion(["Peanut butter"])
        fusion.defaultKeyPaths = [\.self]
        let results = fusion.search(for: "peanut butter")
        XCTAssertEqual(results.count, 1)
    }
    // contains
    // for searching collections within objects
    func testDiacriticInsensitivity() {
        let inlineQuotations: [(String, String)] = [("Anxiety is the dizziness of freedom", "Søren Kierkegaard")]
        let fusion = Fusion(inlineQuotations)
        let results = fusion.search(for: "Soren Kierkegaard", through: [\.1])
        XCTAssertEqual(results.count, 1)
    }
    
    func testASCIIViolation() throws {
        let fusion = Fusion(people, asciiOnly: true)
        
        // This string contains a non-ASCII character.
        let nonASCIIString = "café"
        
        /*XCTAssertThrowsError(try fusion.search(for: nonASCIIString)) { error in
         print(error.localizedDescription)
         
         // XCTAssertEqual(error as? FusionError, FusionError.asciiViolation)
         }*/
    }
    
    func testAVSearch() {
        let fusion = Fusion([AVAudioFile()])
        fusion.defaultKeyPaths = [\.url.absoluteString, \.attributeKeys.description, \.description, \.processingFormat.formatDescription.identifiers.description]
    }
}
