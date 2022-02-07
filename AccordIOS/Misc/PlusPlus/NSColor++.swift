//
//  NSColor+Hex.swift
//  NSColor+Hex
//
//  Created by evelyn on 2021-10-17.
//

import UIKit
import Foundation

extension String {
    func conformsTo(_ pattern: String) -> Bool {
        NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }
}
