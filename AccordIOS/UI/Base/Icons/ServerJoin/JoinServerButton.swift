//
//  JoinServerButton.swift
//  Accord
//
//  Created by evelyn on 2022-05-30.
//

import SwiftUI

struct JoinServerButton: View {
    
    @State var isShowingJoinServerSheet: Bool = false
    @State var iconHovered: Bool = false
    @StateObject var viewUpdater: ServerListView.UpdateView
    
    private var iconView: some View {
        Image(systemName: "plus")
            .imageScale(.large)
            .frame(width: 45, height: 45)
            .background(self.isShowingJoinServerSheet ? Color.accentColor.opacity(0.5) : Color(UIColor.systemBackground))
            .cornerRadius(iconHovered || self.isShowingJoinServerSheet ? 13.5 : 23.5)
    }
    
    var body: some View {
        Button(action: {
            isShowingJoinServerSheet.toggle()
        }, label: {
            iconView
                .foregroundColor(self.isShowingJoinServerSheet ? .white : nil)
                .onHover(perform: { h in withAnimation(Animation.linear(duration: 0.1)) { self.iconHovered = h } })
        })
        .buttonStyle(.borderless)
        .sheet(isPresented: $isShowingJoinServerSheet) {
            JoinServerSheetView(isPresented: $isShowingJoinServerSheet, updater: viewUpdater)
                .frame(width: 300, height: 120)
                .padding()
        }
    }
}
