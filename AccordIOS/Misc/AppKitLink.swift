//
//  AppKitLink.swift
//  Accord
//
//  Created by evelyn on 2021-12-18.
//

import UIKit
import Foundation

final class UIKitLink<V: UIView> {
    class func introspectView(_ root: UIView, _ completion: @escaping ((_ uiView: V, _ subviewCount: Int) -> Void)) {
        for child in root.subviews {
            if let view = child as? V {
                completion(view, child.subviews.count)
            } else {
                introspectView(child, completion)
            }
        }
    }

    class func introspect(_ completion: @escaping ((_ uiView: V, _ subviewCount: Int) -> Void)) {
        guard let view = UIApplication.shared.keyWindow else { return }
        for child in view.subviews {
            if let child = child as? V {
                completion(child, child.subviews.count)
            } else {
                introspectView(child, completion)
            }
        }
    }
}
