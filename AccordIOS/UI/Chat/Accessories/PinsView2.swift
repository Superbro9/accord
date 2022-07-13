//
//  PinsView.swift
//  Accord
//
//  Created by evelyn on 2021-12-21.
//

import Combine
import Foundation
import SwiftUI

struct PinsView: View {
    var guildID: String
    var channelID: String
    @Binding var replyingTo: Message?
    @State var pins: [Message] = []
    @State var bag = Set<AnyCancellable>()
    
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        VStack(alignment: .leading) {
            List($pins, id: \.id) { $message in
                ZStack(alignment: .topTrailing) {
                    MessageCellView(
                        message: message,
                        nick: nil,
                        replyNick: nil,
                        pronouns: nil,
                        avatar: nil,
                        guildID: "",
                        permissions: .constant(.init()),
                        role: Binding.constant(nil),
                        replyRole: Binding.constant(nil),
                        replyingTo: $replyingTo
                    )
                    Button("Jump") {
                        ChannelView.scrollTo.send((message.channel_id, message.id))
                    }
                    .buttonStyle(.borderless)
                }
                .offset(x: 0, y: -1)
                .rotationEffect(.radians(.pi))
                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                .listRowSeparator(.hidden)
            }
            .padding(.leading, 55)
        }
        .navigationTitle("Pinned Messages")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .rotationEffect(.radians(.pi))
        .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
        .onAppear(perform: {
            messageFetchQueue.async {
                // https://discord.com/api/v9/channels/831692717397770272/pins
                RequestPublisher.fetch([Message].self, url: URL(string: "\(rootURL)/channels/\(channelID)/pins"), headers: Headers(
                    token: Globals.token,
                    type: .GET,
                    discordHeaders: true,
                    referer: "https://discord.com/channels/\(guildID)/\(channelID)"
                ))
                .replaceError(with: [])
                .sink { messages in
                    DispatchQueue.main.async {
                        self.pins = messages
                    }
                }
                .store(in: &bag)
            }
            print(channelID)
            print(guildID)
        })
    }
}
