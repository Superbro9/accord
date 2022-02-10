//
//  ChannelView.swift
//  Accord
//
//  Created by evelyn on 2020-11-27.
//

import UIKit
import AVKit
import SwiftUI

struct ChannelView: View, Equatable {
    // MARK: - Equatable protocol

    static func == (lhs: ChannelView, rhs: ChannelView) -> Bool {
        lhs.viewModel.messages == rhs.viewModel.messages
    }

    @ObservedObject var viewModel: ChannelViewViewModel

    var guildID: String
    var channelID: String
    var channelName: String
    var guildName: String

    // Whether or not there is a message send in progress
    @State var sending: Bool = false

    // Nicknames/Usernames of users typing
    @State var typing: [String] = []

    // WebSocket error
    @State var error: String?

    // Mention users in replies
    @State var mention: Bool = true
    @State var replyingTo: Message?

    @State var pins: Bool = false
    @State var mentions: Bool = false

    @State var memberListShown: Bool = false
    @State var memberList = [OPSItems]()
    @State var fileUpload: Data?
    @State var fileUploadURL: URL?

    @AppStorage("MetalRenderer") var metalRenderer: Bool = false

    // MARK: - init

    init(_ channel: Channel, _ guildName: String? = nil) {
        guildID = channel.guild_id ?? "@me"
        channelID = channel.id
        channelName = channel.name ?? channel.recipients?.first?.username ?? "Unknown channel"
        self.guildName = guildName ?? "Direct Messages"
        viewModel = ChannelViewViewModel(channelID: channelID, guildID: guildID)
    }

    var body: some View {
        HStack {
            ZStack(alignment: .bottom) { [weak viewModel] in
                List {
                    Spacer().frame(height: typing.isEmpty && replyingTo == nil ? 65 : 75)
                    ForEach(viewModel?.messages ?? [], id: \.identifier) { message in
                        if let author = message.author {
                            MessageCellView(
                                message: message,
                                nick: viewModel?.nicks[author.id],
                                replyNick: viewModel?.nicks[message.referenced_message?.author?.id ?? ""],
                                pronouns: viewModel?.pronouns[author.id],
                                avatar: viewModel?.avatars[author.id],
                                guildID: guildID,
                                role: $viewModel.roles[author.id],
                                replyRole: $viewModel.roles[message.referenced_message?.author?.id ?? ""],
                                replyingTo: $replyingTo
                            )
                            .onAppear {
                                if (viewModel?.messages.count ?? 0) >= 50 {
                                    if message == viewModel?.messages[viewModel!.messages.count - 2] {
                                        viewModel?.loadMoreMessages()
                                    }
                                }
                            }
                            .contextMenu {
                                Button("Reply") { [weak message] in
                                    replyingTo = message
                                }
                                Button("Delete") { [weak message] in
                                    message?.delete()
                                }
                                Button("Copy") { [weak message] in
                                    guard let content = message?.content else { return }
                                    UIPasteboard.general.items = []
                                    UIPasteboard.general.string = "\(content)"
                                }
                                Button("Copy Message Link") { [weak message] in
                                    guard let channelID = message?.channel_id, let id = message?.id else { return }
                                    UIPasteboard.general.items = []
                                    UIPasteboard.general.string = "https://discord.com/channels/\(message?.guild_id ?? "@me")/\(channelID)/\(id)"
                                }
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                    .rotationEffect(.init(degrees: 180))
                    .if(metalRenderer, transform: { $0.drawingGroup() })
                }
                .listStyle(PlainListStyle())
                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                .rotationEffect(.init(degrees: 180))
                blurredTextField
            }
            if memberListShown {
                MemberListView(list: $memberList)
                    .frame(width: 250)
                    .onAppear {
                        if memberList.isEmpty {
                            try? wss.memberList(for: guildID, in: channelID)
                        }
                    }
            }
        }
        .navigationTitle(Text("\(guildID == "@me" ? "" : "#")\(channelName)"))
        .onAppear {
            guard wss != nil else { return MentionSender.shared.deselect() }
            wss.typingSubject
                .sink { [weak viewModel] msg, channelID in
                    guard channelID == self.channelID else { return }
                    webSocketQueue.async {
                        guard let memberDecodable = try? JSONDecoder().decode(TypingEvent.self, from: msg).d,
                              memberDecodable.user_id != AccordCoreVars.user?.id else { return }
                        let isKnownAs = viewModel?.nicks[memberDecodable.user_id] ?? memberDecodable.member?.nick ?? memberDecodable.member?.user.username ?? "Unknown User"
                        if !(typing.contains(isKnownAs)) {
                            typing.append(isKnownAs)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            guard !(typing.isEmpty) else { return }
                            typing.removeLast()
                        }
                    }
                }
                .store(in: &viewModel.cancellable)
            wss.memberListSubject
                .sink { list in
                    if self.memberListShown, memberList.isEmpty {
                        self.memberList = Array(list.d.ops.compactMap(\.items).joined())
                    }
                }
                .store(in: &viewModel.cancellable)
        }
        .onDisappear { [weak viewModel] in
            viewModel?.cancellable.invalidateAll()
        }
        .onDrop(of: ["public.file-url"], isTargeted: Binding.constant(false)) { providers -> Bool in
            providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { data, _ in
                if let data = data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                    fileUpload = try! Data(contentsOf: url)
                    fileUploadURL = url
                }
            })
            return true
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Toggle(isOn: $pins) {
                    Image(systemName: "pin.fill")
                        .rotationEffect(.degrees(45))
                }
                .sheet(isPresented: $pins) {
                    PinsView(guildID: guildID, channelID: channelID, replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 600)
                }
                Toggle(isOn: $mentions) {
                    Image(systemName: "bell.badge.fill")
                }
                .popover(isPresented: $mentions) {
                    MentionsView(replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 600)
                }
                if guildID != "@me" {
                    Toggle(isOn: $memberListShown.animation()) {
                        Image(systemName: "person.2.fill")
                    }
                }
            }
        }
        Spacer()
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

struct MemberListView: View {
    @Binding var list: [OPSItems]
    var body: some View {
        List(list.compactMap(\.member), id: \.user.id) { ops in
            HStack {
                Attachment(pfpURL(ops.user.id, ops.user.avatar, "24"))
                    .frame(width: 33, height: 33)
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text(ops.nick ?? ops.user.username)
                        .fontWeight(.medium)
                        .lineLimit(0)
                    if let presence = ops.presence?.activities.first?.state {
                        Text(presence).foregroundColor(.secondary)
                            .lineLimit(0)
                    }
                }
            }
        }
    }
}
