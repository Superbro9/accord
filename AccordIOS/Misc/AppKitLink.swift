//
//  AppKitLink.swift
//  Accord
//
//  Created by evelyn on 2021-12-18.
//

import UIKit
import Foundation
import SwiftUI

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

struct FetchScrollView: UIViewRepresentable {

     let view = UITextField()
     @State var tableView: UITableView? = nil

     func makeUIView(context: Context) -> UIView {
         return view
     }

     func getTableView() -> UITableView? {
         guard let cell = view.superview?.superview?.superview else { return nil }
         let tableView = Mirror(reflecting: cell)
             .children
             .filter { $0.label == "enclosingTableView"}
             .first?.value as? UITableView
         print(tableView)
         return tableView
     }

     func setTableView() {
         self.tableView = self.getTableView()
     }

     func updateUIView(_ uiView: UIView, context: Context) {
     }
 }

 class ListTableCellView: UIView {
     //(label: Optional("host"), value: Optional(<_TtGC7SwiftUI15CellHostingViewGVS_15ModifiedContentVS_14_ViewList_ViewVS_19CellContentModifier__: 0x7f8f049a5800>)),
     //var enclosingTableView: Any?
     // (label: Optional("delegate"), value: Optional(<_TtGC7SwiftUI26NSTableViewListCoordinatorGVS_19ListStyleDataSourceOs5Never_GOS_19SelectionManagerBoxS2___: 0x7f8f05192940>))
 }
