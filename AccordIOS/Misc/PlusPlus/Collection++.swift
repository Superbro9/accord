//
//  Collection++.swift
//  Accord
//
//  Created by evelyn on 2022-02-18.
//

import Foundation
import Combine

extension Collection where Element: Identifiable {
    func generateKeyMap() -> [Element.ID: Int] {
        return self
            .enumerated().lazy
            .compactMap { [$1.id: $0] }
            .reduce(into: [:]) { result, next in
                result.merge(next) { _, rhs in rhs }
            }
    }
}

extension Dictionary {
    func filterValues(isIncluded: (Self.Value) throws -> Bool) rethrows -> Self {
        return try self.filter { try isIncluded($0.value) }
    }
}

extension Collection {
    func jsonString() throws -> String? {
        let data = try JSONSerialization.data(withJSONObject: self, options: [])
        let jsonString = String(data: data, encoding: .utf8)
        return jsonString
    }
    
    var arrayLiteral: Array<Self.Element> {
             Array(self)
         }
}

extension ArraySlice {
    typealias LiteralType = Array<Self.Element>
    func literal() -> LiteralType {
        return LiteralType(self)
    }
}

extension Slice {
    func literal() -> Base {
        return self.base
    }
}
extension Array where Element: Identifiable {
    subscript(keyed id: Self.Element.ID, keyMap: [Self.Element.ID:Int]? = nil) -> Self.Element? {
         get {
             let keys = keyMap ?? self.generateKeyMap()
             guard let element = keys[id] else { return nil }
             return self[element]
         }
         set {
             let keys = keyMap ?? self.generateKeyMap()
             guard let element = keys[id], let newValue = newValue else { return }
             self[element] = newValue
         }
     }

     subscript(indexOf id: Self.Element.ID, keyMap: [Self.Element.ID:Int]? = nil) -> Int? {
         let keys = keyMap ?? self.generateKeyMap()
         return keys[id]
     }
 }

public extension Dictionary {
   /// Same values, corresponding to `map`ped keys.
   ///
   /// - Parameter transform: Accepts each key of the dictionary as its parameter
   ///   and returns a key for the new dictionary.
   /// - Postcondition: The collection of transformed keys must not contain duplicates.
   func mapKeys<Transformed>(
     _ transform: (Key) throws -> Transformed
   ) rethrows -> [Transformed: Value] {
     .init(
       uniqueKeysWithValues: try map { (try transform($0.key), $0.value) }
     )
   }

   /// Same values, corresponding to `map`ped keys.
   ///
   /// - Parameters:
   ///   - transform: Accepts each key of the dictionary as its parameter
   ///     and returns a key for the new dictionary.
   ///   - combine: A closure that is called with the values for any duplicate
   ///     keys that are encountered. The closure returns the desired value for
   ///     the final dictionary.
   func mapKeys<Transformed>(
     _ transform: (Key) throws -> Transformed,
     uniquingKeysWith combine: (Value, Value) throws -> Value
   ) rethrows -> [Transformed: Value] {
     try .init(
       map { (try transform($0.key), $0.value) },
       uniquingKeysWith: combine
     )
   }

   /// `compactMap`ped keys, with their values.
   ///
   /// - Parameter transform: Accepts each key of the dictionary as its parameter
   ///   and returns a potential key for the new dictionary.
   /// - Postcondition: The collection of transformed keys must not contain duplicates.
   func compactMapKeys<Transformed>(
     _ transform: (Key) throws -> Transformed?
   ) rethrows -> [Transformed: Value] {
     .init(
       uniqueKeysWithValues: try compactMap { key, value in
         try transform(key).map { ($0, value) }
       }
     )
   }
 }
