import Foundation

public class Fusion<T> {
    private let data: [T] // Fuzzy search space.
    private let queryByteLimit: Int = 64
    public var defaultKeyPaths: [KeyPath<T, String>] = []
        
    public private(set) var encoding: String.Encoding
    public var foldingOptions: String.CompareOptions
    // Maximum number of allowed bit flip errors (i.e., Hamming distance).
    public var bitErrorLimit: Int
    
    public init(
        _ data: [T],
        foldingOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive],
        asciiOnly: Bool = false,
        bitErrorLimit: Int = 2
    ) {
        self.data = data
        self.foldingOptions = foldingOptions
        self.encoding = asciiOnly ? .ascii : .unicode
        self.bitErrorLimit = bitErrorLimit
    }
    
    public func search(for term: String) -> [T] {
        assert(!defaultKeyPaths.isEmpty, "Value for 'defaultKeyPaths' in Fusion instance is an empty array")
        return defaultKeyPaths.reduce([], { $0 + self.search(for: term, through: $1) })
    }
    
    public func search(for term: String, through keyPaths: [KeyPath<T, String>]) -> [T] {
        return keyPaths.reduce([], { $0 + self.search(for: term, through: $1) })
    }
    
    public func search(for term: String, through keyPath: KeyPath<T, String>) -> [T] {
        assert(term.lengthOfBytes(using: encoding) <= queryByteLimit, "Search currently does not support terms with size greater than 64 bytes")
        return data.filter { self.fuzzyMatch(term, $0[keyPath: keyPath]) }
    }
    
    @available(macOS 13.0, *)
    public func match(pattern: Regex<AnyRegexOutput>, through keyPath: KeyPath<T, String>) -> [T] {
        return data.filter { (try? pattern.firstMatch(in: $0[keyPath: keyPath])) != nil }
    }
    
    internal func asciiFuzzyMatch(_ searchTerm: String, _ targetString: String) -> Bool {
        // Normalize the strings according to `foldingOptions`.
        let normalizedSearchTerm = normalizedString(searchTerm)
        let normalizedTargetString = normalizedString(targetString)
        
        // Initialize an array to store the bit representation of the current state.
        // Each element represents the state for a given error level.
        var currentState = Array<UInt64>(repeating: ~1, count: bitErrorLimit + 1)
        
        // Initialize an array to store the bitmask for each character in the ASCII table.
        // This will be used to quickly check if a character is in the search term.
        var characterBitmask = Array<UInt64>(repeating: ~0, count: Int(Int8.max) + 1)
        for i in 0..<normalizedSearchTerm.count {
            let char = normalizedSearchTerm[normalizedSearchTerm.index(normalizedSearchTerm.startIndex, offsetBy: i)]
            characterBitmask[Int(char.asciiValue!)] &= ~(1 << i)
        }
        
        // Iterate over each character in the target string.
        for i in 0..<normalizedTargetString.count {
            let currentChar = normalizedTargetString[normalizedTargetString.index(normalizedTargetString.startIndex, offsetBy: i)]
            var previousStateForErrorLevel = currentState[0]
            
            // Update the state for error level 0.
            currentState[0] |= characterBitmask[Int(currentChar.asciiValue!)]
            currentState[0] <<= 1
            
            // Update the state for each error level.
            for errorLevel in 1...bitErrorLimit {
                let temp = currentState[errorLevel]
                currentState[errorLevel] = (previousStateForErrorLevel & (currentState[errorLevel] | characterBitmask[Int(currentChar.asciiValue!)])) << 1
                previousStateForErrorLevel = temp
            }
            
            // Check if a match has been found with a number of errors less than or equal to the Hamming distance.
            if currentState[bitErrorLimit] & (1 << normalizedSearchTerm.count) == 0 {
                return true
            }
        }
        
        return false // No match was found.
    }
    
    internal func unicodeFuzzyMatch(_ searchTerm: String, _ targetString: String) -> Bool {
        // Normalize the strings according to `foldingOptions`.
        let normalizedSearchTerm = normalizedString(searchTerm)
        let normalizedTargetString = normalizedString(targetString)
        
        var currentState = Array<UInt>(repeating: ~1, count: bitErrorLimit + 1)
        
        // Initialize a dictionary to store the bitmask for each Unicode scalar.
        var characterBitmask: [UInt32: UInt] = [:]
        for i in 0..<normalizedSearchTerm.count {
            let char = normalizedSearchTerm[normalizedSearchTerm.index(normalizedSearchTerm.startIndex, offsetBy: i)]
            let unicodeValue = char.unicodeScalars.first!.value
            characterBitmask[unicodeValue, default: ~0] &= ~(1 << i)
        }
        
        // Iterate over each character in the target string.
        for i in 0..<normalizedTargetString.count {
            let currentChar = normalizedTargetString[normalizedTargetString.index(normalizedTargetString.startIndex, offsetBy: i)]
            let unicodeValue = currentChar.unicodeScalars.first!.value
            var previousStateForErrorLevel = currentState[0]
            
            currentState[0] |= characterBitmask[unicodeValue, default: ~0]
            currentState[0] <<= 1
            
            for errorLevel in 1...bitErrorLimit {
                let temp = currentState[errorLevel]
                currentState[errorLevel] = (previousStateForErrorLevel & (currentState[errorLevel] | characterBitmask[unicodeValue, default: ~0])) << 1
                previousStateForErrorLevel = temp
            }
            
            if currentState[bitErrorLimit] & (1 << normalizedSearchTerm.count) == 0 {
                return true
            }
        }
        
        return false // No match was found.
    }
}

private extension Fusion {
    func normalizedString(_ str: String) -> String {
        return str.folding(options: foldingOptions, locale: .current)
    }
    
    var fuzzyMatch: (String, String) -> Bool {
        return encoding == .ascii ? asciiFuzzyMatch(_:_:) : unicodeFuzzyMatch(_:_:)
    }
}
