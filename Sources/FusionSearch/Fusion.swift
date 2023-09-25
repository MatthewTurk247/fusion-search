import Foundation
import OSLog

/// # Fuzzy String Matching
///
/// The `Fusion` class provides functionality for fuzzy matching strings allowing for a certain number of errors. It supports both ASCII and full Unicode strings.
///
/// ## Overview
///
/// - `Fusion` is a generic class that operates on a collection of data `T`
/// - It performs fuzzy matching on strings obtained through key paths on `T`
/// - Matching allows up to a specified number of "errors" given by the `bitErrorLimit` property
/// - ASCII or Unicode strings are supported via the `encoding` property
/// - Matching can be case and diacritic insensitive through the `foldingOptions` property
///
/// ## Usage
///
/// Initialize a `Fusion` instance with your data:
/// ```swift
/// let data = [MyData(name: "John"), MyData(name: "Jon")]
/// let fusion = Fusion(data)
/// ```
/// Set key paths to search:
/// ```swift
/// fusion.defaultKeyPaths = [\MyData.name]
/// ```
/// Search for matches:
/// ```swift
/// let matches = fusion.search(for: "Jhn") // Allows 2 errors
/// ```
/// Matches will contain strings from `data` that fuzzily match the search term within the allowed errors.
/// `Fusion` provides configurable fuzzy string matching using Bitap for efficiency. See the method documentation for more details.
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
        // Case and Diacritic Sensitivity: If you want to treat characters with accents as their base characters (e.g., "é" as "e"), you can use Swift's String methods to normalize the string to a form that strips diacritics.
        self.foldingOptions = foldingOptions
        self.encoding = asciiOnly ? .ascii : .unicode
        self.bitErrorLimit = bitErrorLimit
    }
    
    
    /// Search through a collection of items.
    /// If the value for `defaultKeyPaths` in `Fusion` instance is an empty array, this function has no effect.
    /// - Parameter term: The search query.
    /// - Returns: A subarray containing members input collection `data` that have a fuzzy match with `term`.
    public func search(for term: String) -> [T] {
        guard !defaultKeyPaths.isEmpty else { return data }
        return defaultKeyPaths.reduce([], { $0 + self.search(for: term, through: $1) })
    }
    
    /// Searches the data collection for matches through the given key paths.
    ///
    /// - Parameters:
    ///   - term: The search term to fuzzy match against.
    ///   - keyPaths: Key paths specifying string properties through which to search.
    /// - Returns: Matches within allowed errors from the data collection.
    public func search(for term: String, through keyPaths: [KeyPath<T, String>]) -> [T] {
        return keyPaths.reduce([], { $0 + self.search(for: term, through: $1) })
    }
    
    /// Searches the data collection for matches through the given key path.
    ///
    /// - Parameters:
    ///   - term: The search term to fuzzy match against.
    ///   - keyPath: A key path specifying the string property through which to search.
    /// - Returns: Matches within allowed errors from the data collection.
    public func search(for term: String, through keyPath: KeyPath<T, String>) -> [T] {
        assert(term.lengthOfBytes(using: encoding) <= queryByteLimit, "Search currently does not support terms with size greater than 64 bytes")
        return data.filter { self.fuzzyMatch(term, $0[keyPath: keyPath]) }
    }
    
    /// Matches a regular expression pattern against string values from the data collection.
    ///
    /// - Parameters:
    ///   - pattern: The regular expression pattern to match.
    ///   - keyPath: The string property to match against.
    /// - Returns: Items from the data collection containing a match.
    @available(macOS 13.0, *)
    public func match(pattern: Regex<AnyRegexOutput>, through keyPath: KeyPath<T, String>) -> [T] {
        return data.filter { (try? pattern.firstMatch(in: $0[keyPath: keyPath])) != nil }
    }
    
    internal func fuzzyMatch(_ searchTerm: String, _ targetString: String) -> Bool {
        // Normalize the strings according to `foldingOptions`.
        let normalizedSearchTerm = normalize(searchTerm)
        let normalizedTargetString = normalize(targetString)
        
        if encoding == .ascii {
            return asciiFuzzyMatch(normalizedSearchTerm, normalizedTargetString)
        }
        
        return unicodeFuzzyMatch(normalizedSearchTerm, normalizedTargetString)
    }
    
    internal func asciiFuzzyMatch(_ searchTerm: String, _ targetString: String) -> Bool {
        // Initialize an array to store the bit representation of the current state.
        // Each element represents the state for a given error level.
        var currentState = Array<UInt64>(repeating: ~1, count: bitErrorLimit + 1)
        
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
            for errorLevel in 1...bitErrorLimit {
                let temp = currentState[errorLevel]
                currentState[errorLevel] = (previousStateForErrorLevel & (currentState[errorLevel] | characterBitmask[Int(currentChar.asciiValue!)])) << 1
                previousStateForErrorLevel = temp
            }
            
            // Check if a match has been found with a number of errors less than or equal to the Hamming distance.
            if currentState[bitErrorLimit] & (1 << searchTerm.count) == 0 {
                return true
            }
        }
        
        return false // No match was found.
    }
    
    internal func unicodeFuzzyMatch(_ searchTerm: String, _ targetString: String) -> Bool {
        var currentState = Array<UInt>(repeating: ~1, count: bitErrorLimit + 1)
        
        // Initialize a dictionary to store the bitmask for each Unicode scalar.
        var characterBitmask: [UInt32: UInt] = [:]
        for i in 0..<searchTerm.count {
            let char = searchTerm[searchTerm.index(searchTerm.startIndex, offsetBy: i)]
            let unicodeValue = char.unicodeScalars.first!.value
            characterBitmask[unicodeValue, default: ~0] &= ~(1 << i)
        }
        
        // Iterate over each character in the target string.
        for i in 0..<targetString.count {
            let currentChar = targetString[targetString.index(targetString.startIndex, offsetBy: i)]
            let unicodeValue = currentChar.unicodeScalars.first!.value
            var previousStateForErrorLevel = currentState[0]
            
            currentState[0] |= characterBitmask[unicodeValue, default: ~0]
            currentState[0] <<= 1
            
            for errorLevel in 1...bitErrorLimit {
                let temp = currentState[errorLevel]
                currentState[errorLevel] = (previousStateForErrorLevel & (currentState[errorLevel] | characterBitmask[unicodeValue, default: ~0])) << 1
                previousStateForErrorLevel = temp
            }
            
            if currentState[bitErrorLimit] & (1 << searchTerm.count) == 0 {
                return true
            }
        }
        
        return false // No match was found.
    }
}

private extension Fusion {
    func normalize(_ str: String) -> String {
        return str.folding(options: foldingOptions, locale: .current)
    }
}
