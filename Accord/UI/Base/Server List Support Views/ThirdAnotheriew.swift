//
//  ThirdAnotheriew.swift
//  AccordIOS
//
//  Created by Hugo Mason on 08/02/2022.
//

import Combine
import SwiftUI

struct ThirdAnotheriew: View {
    
    @State var selection: Int?
    @State var selectedServer: Int? = 0
    @State var online: Bool = true
    @State var alert: Bool = true
    public static var folders: [GuildFolder] = []
    public static var privateChannels: [Channel] = []
    internal static var readStates: [ReadStateEntry] = []
    @State var status: String?
    @State var timedOut: Bool = false
    @State var mentions: Bool = false
    @State var bag = Set<AnyCancellable>()
    @State var updater: Bool = false
    
    
    var body: some View {
        ForEach(Self.folders, id: \.hashValue) { folder in
            if folder.guilds.count != 1 {
                Folder(icon: Array(folder.guilds.prefix(4)), color: Color.color(from: folder.color ?? 0) ?? Color.gray.blur(radius: 0.75)) {
                    ForEach(folder.guilds, id: \.hashValue) { guild in
                        ZStack(alignment: .bottomTrailing) {
                            Button(action: { [weak wss] in
                                wss?.cachedMemberRequest.removeAll()
                                if selectedServer == 201 {
                                    selectedServer = guild.index
                                } else {
                                    withAnimation {
                                        selectedServer = guild.index
                                    }
                                }
                            }) {
                                Attachment(iconURL(guild.id, guild.icon ?? "")).equatable()
                                    .frame(width: 45, height: 45)
                                    .cornerRadius(selectedServer == guild.index ? 15.0 : 23.5)
                            }
                            if pingCount(guild: guild) != 0 {
                                ZStack {
                                    Circle()
                                        .foregroundColor(Color.red)
                                        .frame(width: 15, height: 15)
                                    Text(String(pingCount(guild: guild)))
                                        .foregroundColor(Color.white)
                                        .fontWeight(.semibold)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 1)
            }
        }
    }
