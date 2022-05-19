//
//  ChannelView.swift
//  Accord
//
//  Created by evelyn on 2020-11-27.
//

import UIKit
import AVKit
import SwiftUI
import Combine

struct ChannelView: View, Equatable {
    static func == (lhs: ChannelView, rhs: ChannelView) -> Bool {
        return lhs.viewModel == rhs.viewModel
    }
    
    @StateObject var viewModel: ChannelViewViewModel
    
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
    @State var mentionUser: Bool = true
    
    @State var pins: Bool = false
    @State var mentions: Bool = false
    
    @State var memberListShown: Bool = false
    @State var memberList: [OPSItems] = .init()
    @State var fileUpload: Data?
    @State var fileUploadURL: URL?
    
    @AppStorage("MetalRenderer")
    var metalRenderer: Bool = false
    
    @State private var cancellable = Set<AnyCancellable>()
    
    private var permissions: Permissions
    
    // MARK: - init
    init(_ channel: Channel, _ guildName: String? = nil) {
        guildID = channel.guild_id ?? "@me"
        channelID = channel.id
        channelName = channel.name ?? channel.recipients?.first?.username ?? "Unknown channel"
        self.guildName = guildName ?? "Direct Messages"
        _viewModel = StateObject(wrappedValue: ChannelViewViewModel(channelID: channel.id, guildID: channel.guild_id ?? "@me"))
        self.permissions = channel.permission_overwrites?.allAllowed(guildID: guildID) ?? .init()
        UITableView.appearance().showsVerticalScrollIndicator = false
    }
    
    var messagesView: some View {
        ForEach(viewModel.messages, id: \.identifier) { message in
            if let author = message.author {
                MessageCellView(
                    message: message,
                    nick: viewModel.nicks[author.id],
                    replyNick: viewModel.nicks[message.referenced_message?.author?.id ?? ""],
                    pronouns: viewModel.pronouns[author.id],
                    avatar: viewModel.avatars[author.id],
                    guildID: guildID,
                    permissions: permissions,
                    role: $viewModel.roles[author.id],
                    replyRole: $viewModel.roles[message.referenced_message?.author?.id ?? ""],
                    replyingTo: $replyingTo
                )
                .equatable()
                .id(message.identifier)
                .listRowInsets(.init(top: 0, leading: 0, bottom: (message.isSameAuthor && message.referenced_message == nil) ? 0.5 : 10, trailing: 0))
                .if(message.mentions.compactMap { $0?.id }.contains(user_id), transform: { view in
                    view
                        .padding(5)
                        .frame (
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                        .background(Color.yellow.opacity(0.05))
                        .cornerRadius(7)
                })
                    .onAppear {
                    if viewModel.messages.count >= 50 &&
                        message == viewModel.messages[viewModel.messages.count - 2] {
                        messageFetchQueue.async {
                            viewModel.loadMoreMessages()
                        }
                        }
                    }
            }
        }
        .rotationEffect(.degrees(180))
        .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
    }
    
    var body: some View {
        HStack {
            ZStack(alignment: .bottom) {
                List {
                    Spacer().frame(height: typing.isEmpty && replyingTo == nil ? 65 : 75)
                    if metalRenderer {
                        messagesView.drawingGroup()
                            .listRowSeparator(.hidden)
                    } else {
                        messagesView
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .rotationEffect(.init(degrees: 180))
                .padding()
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
        .gesture(DragGesture().onChanged({ _ in
            self.endTextEditing()
        }))
        .onAppear {
            guard wss != nil else { return MentionSender.shared.deselect() }
            wss.typingSubject
                .receive(on: webSocketQueue)
                .sink { [weak viewModel] msg, channelID in
                    
                    guard channelID == self.channelID,
                          let memberDecodable = try? JSONDecoder().decode(TypingEvent.self, from: msg).d,
                          memberDecodable.user_id != AccordCoreVars.user?.id else { return }
                    
                    let isKnownAs =
                    viewModel?.nicks[memberDecodable.user_id] ??
                    memberDecodable.member?.nick ??
                    memberDecodable.member?.user.username ??
                    "Unknown User"
                    
                    if !typing.contains(isKnownAs) {
                        typing.append(isKnownAs)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        guard !typing.isEmpty else { return }
                        typing.removeLast()
                    }
                }
                .store(in: &cancellable)
            wss.memberListSubject
                .sink { list in
                    if self.memberListShown, memberList.isEmpty {
                        self.memberList = Array(list.d.ops.compactMap(\.items).joined())
                            .map { item -> OPSItems in
                                let new = item
                                new.member?.roles = new.member?.roles?
                                    .filter { roleColors[$0] != nil }
                                    .sorted(by: { roleColors[$0]!.1 > roleColors[$1]!.1 })
                                return new
                            }
                    }
                }
                .store(in: &cancellable)
        }
        .toolbar(content: {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    self.pins.toggle()
                }) {
                    Image(systemName: "pin.fill")
                        .rotationEffect(.degrees(45))
                }
                .popover(isPresented: $pins) {
                    PinsView(guildID: guildID, channelID: channelID, replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 700)
                }
                
                Button(action: {
                    self.mentions.toggle()
                }) {
                    Image(systemName: "bell.badge.fill")
                }
                .popover(isPresented: $mentions) {
                    MentionsView(replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 700)
                }
                
                if guildID != "@me" {
                    Toggle(isOn: $memberListShown.animation()) {
                        Image(systemName: "person.2.fill")
                      }
                  }
              }
           }
        )
        .onDisappear {
            self.cancellable.forEach { $0.cancel() }
            self.cancellable.removeAll()
        }
    }
}

struct MemberListView: View {
    @Binding var list: [OPSItems]
    var body: some View {
        List(list, id: \.id) { ops in
            if let group = ops.group {
                Text (
                    "\(group.id == "offline" ? "Offline" : group.id == "online" ? "Online" : roleNames[group.id ?? ""] ?? "") - \(group.count ?? 0)"
                )
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                    .padding([.top])
            } else {
                HStack {
                    Attachment(pfpURL(ops.member?.user.id ?? "", ops.member?.user.avatar ?? "", discriminator: ops.member?.user.discriminator ?? "", "24"))
                        .equatable()
                        .frame(width: 33, height: 33)
                        .clipShape(Circle())
                    VStack(alignment: .leading) {
                        Text(ops.member?.nick ?? ops.member?.user.username ?? "")
                            .fontWeight(.medium)
                            .foregroundColor({ () -> Color in
                                if let role = ops.member?.roles?.first, let color = roleColors[role]?.0 {
                                    return Color(int: color)
                                }
                                return Color.primary
                            }())
                            .lineLimit(0)
                        if let presence = ops.member?.presence?.activities.first?.state {
                            Text(presence).foregroundColor(.secondary)
                                .lineLimit(0)
                        }
                    }
                }
            }
        }
    }
}


struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

extension View {
  func endTextEditing() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
  }
}
