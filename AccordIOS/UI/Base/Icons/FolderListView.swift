//
//  FolderListView.swift
//  Accord
//
//  Created by evelyn on 2022-02-14.
//

import Foundation
import SwiftUI

extension ServerListView {
    
    struct FolderListView: View {
        @Binding var selectedServer: String?
        @Binding var selection: Int?
        @Binding var selectedGuild: Guild?
        
        @State var isShowingJoinServerSheet: Bool = false
        @StateObject var updater: ServerListView.UpdateView
        
        func color(_ folder: GuildFolder) -> Color {
                     if let color = folder.color {
                         return Color(int: color)
                     }
                     return Color("AccentColor")
                 }
        
        var body: some View {
            ForEach(Storage.folders, id: \.hashValue) { folder in
                if folder.guilds.count != 1 {
                    Folder (
                        icon: Array(folder.guilds.prefix(4)),
                        color: self.color(folder),
                        read: Binding.constant(folder.guilds.map { unreadMessages(guild: $0) }.contains(true)),
                        mentionCount: folder.guilds.map({ pingCount(guild: $0) }).reduce(0, +)
                    ) {
                        ForEach(folder.guilds, id: \.id) { guild in
                            ServerIconCell (
                                guild: guild,
                                selectedServer: self.$selectedServer,
                                selection: self.$selection,
                                selectedGuild: self.$selectedGuild,
                                updater: self.$updater.updater
                            )
                        }
                    }
                    .padding(.bottom, 1)
                } else if let guild = folder.guilds.first {
                    ServerIconCell (
                        guild: guild,
                        selectedServer: self.$selectedServer,
                        selection: self.$selection,
                        selectedGuild: self.$selectedGuild,
                        updater: self.$updater.updater
                    )
                }
            }
            .padding(.trailing, 6)
        }
    }
}

struct ServerIconCell: View {
    var guild: Guild
    @Binding var selectedServer: String?
    @Binding var selection: Int?
    @Binding var selectedGuild: Guild?
    @State var hovering: Bool = false
    @Binding var updater: Bool
    
    @State var mentionCount: Int?
    
    func updateSelection(old: String?, new: String?) {
        DispatchQueue.global().async {
            if let selection = selection, old == "@me" {
                UserDefaults.standard.set(selection, forKey: "AccordChannelDMs")
            }
            guard let new = new else {
                return DispatchQueue.main.async {
                    self.selectedServer = new
                    self.selectedGuild = guild
                }
            }
            if let selection = selection, let id = selectedGuild?.id {
                UserDefaults.standard.set(selection, forKey: "AccordChannelIn\(id)")
            }
            DispatchQueue.main.async {
                self.selection = nil
                if let value = UserDefaults.standard.object(forKey: "AccordChannelIn\(guild.id)") as? Int {
                    self.selectedGuild = guild
                    self.selectedServer = new
                    self.selection = value
                } else {
                    self.selectedGuild = guild
                    self.selectedServer = new
                }
            }
        }
    }
    
    var body: some View {
        Button(action: {
            self.updateSelection(old: selectedServer, new: guild.id)
        }) {
            HStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill()
                    .foregroundColor(Color.primary)
                    .frame(width: 5, height: selectedServer == guild.id || hovering ? 30 : 5)
                    .animation(Animation.easeInOut(duration: 0.1), value: UUID())
                    .opacity(unreadMessages(guild: guild) || selectedServer == guild.id ? 1 : 0)
                GuildListPreview(guild: guild, selectedServer: $selectedServer.animation(), updater: self.$updater)
            }
        }
        .accessibility(
            label: Text(guild.name ?? "Unknown Guild") + Text(String(pingCount(guild: guild)) + " mentions") + Text(unreadMessages(guild: guild) ? "Unread messages" : "No unread messages")
        )
        .onHover(perform: { h in withAnimation(Animation.easeInOut(duration: 0.1)) { self.hovering = h } })
        .onChange(of: self.updater, perform: { _ in
            self.mentionCount = pingCount(guild: guild)
        })
        .buttonStyle(BorderlessButtonStyle())
        .redBadge($mentionCount)
    }
}
