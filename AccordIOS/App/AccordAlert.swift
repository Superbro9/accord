//
//  AccordAlert.swift
//  Accord
//
//  Created by evelyn on 2022-01-01.
//

import UIKit
import Foundation

extension AccordApp {
    static func error(_ error: Error, additionalDescription: String? = nil) {
        let alert = UIAlertController()
        alert.message = error.localizedDescription
        if let additionalDescription = additionalDescription {
            alert.message = additionalDescription
        }
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
    }
}
