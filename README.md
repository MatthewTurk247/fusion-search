# Fusion

The `Fusion` class provides functionality for fuzzy matching strings allowing for a certain number of errors. It supports ASCII, Unicode, and a wide range of other configuration options.

## Overview: Fuzzy String Matching

- `Fusion` is a generic class that operates on a collection of data `T`
- It performs fuzzy matching on strings obtained through key paths on `T`
- Matching allows up to a specified number of "errors" given by the `bitErrorLimit` property
- ASCII or Unicode strings are supported via the `encoding` property
- Matching can be case and diacritic insensitive through the `foldingOptions` property

## Implementation Details

`Fusion` is greatly inspired by [Fuse.js](https://github.com/krisk/fuse) and uses a modified Bitap algorithm to efficiently search for fuzzy matches. See the class documentation for more details.
