//
//  DMButton.swift
//  Accord
//
//  Created by evelyn on 2022-05-17.
//

import SwiftUI

struct DMButton: View {
    @Binding var selection: Int?
    @Binding var selectedServer: String?
    @Binding var selectedGuild: Guild?
    @StateObject var updater: ServerListView.UpdateView
    @State var mentionCount: Int?
    @State var iconHovered: Bool = false
    var body: some View {
        Button(action: {
            DispatchQueue.global().async {
                Storage.privateChannels = Storage.privateChannels.sorted(by: { $0.last_message_id ?? "" > $1.last_message_id ?? "" })
            }
            if let selection = selection, let id = self.selectedGuild?.id {
                UserDefaults.standard.set(selection, forKey: "AccordChannelIn\(id)")
            }
            selectedServer = "@me"
            selection = nil
            self.selectedGuild = nil
            if let selectionPrevious = UserDefaults.standard.object(forKey: "AccordChannelDMs") as? Int {
                self.selection = selectionPrevious
            }
        }) {
            Image(systemName: "bubble.right.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
                .padding()
                .frame(width: 45, height: 45)
                .background(selectedServer == "@me" || iconHovered ? Color.accentColor.opacity(0.5) : Color(UIColor.systemBackground))
                .cornerRadius(iconHovered || selectedServer == "@me" ? 13.5 : 23.5)
                .foregroundColor(selectedServer == "@me" || iconHovered ? Color.white : nil)
                .if(selectedServer == "@me", transform: { $0.foregroundColor(Color.white) })
                    .onHover(perform: { h in withAnimation(Animation.easeInOut(duration: 0.2)) { self.iconHovered = h } })
        }
        .redBadge($mentionCount)
        .buttonStyle(BorderlessButtonStyle())
        .onReceive(self.updater.$updater, perform: { _ in
            DispatchQueue.global().async {
                self.mentionCount = Storage.privateChannels.compactMap({ $0.read_state?.mention_count }).reduce(0, +)
            }
        })
    }
}
