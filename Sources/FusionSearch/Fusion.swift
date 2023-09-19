import Foundation

public class Fusion<T: AnyObject> {
    let data: [T] // Fuzzy search space.
    public var defaultKeyPaths: [KeyPath<T, String>] = []
    
    // TODO: Add support for Unicode strings and the like, and make Unicode default.
    
    public var encoding: String.Encoding = .ascii
    public var isCaseSensitive: Bool = false
    public var isDiacriticSensitive: Bool = false
    
    public init(_ data: [T]) {
        self.data = data
    }
    
    func search(for term: String) -> [T] {
        assert(!defaultKeyPaths.isEmpty, "Value for 'defaultKeyPaths' in Fusion instance is an empty array")
        return defaultKeyPaths.reduce([], { $0 + self.search(for: term, through: $1) })
    }
    
    func search(for term: String, through keyPaths: [KeyPath<T, String>]) -> [T] {
        return keyPaths.reduce([], { $0 + self.search(for: term, through: $1) })
    }
    
    func search(for term: String, through keyPath: KeyPath<T, String>) -> [T] {
        return data.filter { self.asciiFuzzyMatch(term, $0[keyPath: keyPath]) }
    }
    
    private func asciiFuzzyMatch(_ searchTerm: String, _ targetString: String) -> Bool {
        // Maximum number of allowed errors.
        let hammingDistance = 2
        
        // Initialize an array to store the bit representation of the current state.
        // Each element represents the state for a given error level.
        var currentState = Array<UInt64>(repeating: ~1, count: hammingDistance + 1)
        
        // Initialize an array to store the bitmask for each character in the ASCII table.
        // This will be used to quickly check if a character is in the search term.
        var characterBitmask = Array<UInt64>(repeating: ~0, count: Int(Int8.max) + 1)
        for i in 0..<searchTerm.count {
            let char = searchTerm[searchTerm.index(searchTerm.startIndex, offsetBy: i)]
            characterBitmask[Int(char.asciiValue!)] &= ~(1 << i)
        }
        
        // Iterate over each character in the target string.
        for i in 0..<targetString.count {
            let currentChar = targetString[targetString.index(targetString.startIndex, offsetBy: i)]
            var previousStateForErrorLevel = currentState[0]
            
            // Update the state for error level 0.
            currentState[0] |= characterBitmask[Int(currentChar.asciiValue!)]
            currentState[0] <<= 1
            
            // Update the state for each error level.
            for errorLevel in 1...hammingDistance {
                let temp = currentState[errorLevel]
                currentState[errorLevel] = (previousStateForErrorLevel & (currentState[errorLevel] | characterBitmask[Int(currentChar.asciiValue!)])) << 1
                previousStateForErrorLevel = temp
            }
            
            // Check if a match has been found with a number of errors less than or equal to the Hamming distance.
            if currentState[hammingDistance] & (1 << searchTerm.count) == 0 {
                return true
            }
        }
        
        return false // No match was found.
    }
}
