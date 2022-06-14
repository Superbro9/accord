//
//  NSColor+Hex.swift
//  NSColor+Hex
//
//  Created by evelyn on 2021-10-17.
//

import UIKit
import Foundation
import SwiftUI

extension String {
    func conformsTo(_ pattern: String) -> Bool {
        NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }
}

public extension Color {
    static func color(from int: Int) -> Color? {
        let hex = String(format: "%06X", int)
        let r, g, b: CGFloat
        if hex.count == 6 {
            let scanner = Scanner(string: hex)
            var hexNumber: UInt64 = 0
            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
                g = CGFloat((hexNumber & 0xFF00) >> 8) / 255
                b = CGFloat(hexNumber & 0xFF) / 255
                if pastelColors {
                    return Color.init(.displayP3, red: r + 0.1, green: g + 0.1, blue: b + 0.1, opacity: 1)
                    //return NSColor(calibratedRed: r + 0.1, green: g + 0.1, blue: b + 0.1, alpha: 1)
                } else {
                    return Color.init(.displayP3, red: r, green: g, blue: b, opacity: 1)
                    //return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
                }
            }
        }
        return nil
    }
}
