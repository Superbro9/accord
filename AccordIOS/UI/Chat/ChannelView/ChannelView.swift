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


extension UIScrollView {
   func scrollToBottom(animated: Bool) {
     if self.contentSize.height < self.bounds.size.height { return }
     let bottomOffset = CGPoint(x: 0, y: self.contentSize.height - self.bounds.size.height)
     self.setContentOffset(bottomOffset, animated: animated)
  }
}

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
    
    // WebSocket error
    @State var error: String?
    
    // Mention users in replies
    @State var mention: Bool = true
    @State var replyingTo: Message?
    @State var mentionUser: Bool = true
    
    @State var pins: Bool = false
    @State var mentions: Bool = false
    
    @State var memberListShown: Bool = false
    @State var fileUpload: Data?
    @State var fileUploadURL: URL?
    
    @State private var cancellable = Set<AnyCancellable>()
    
    @Environment(\.user)
    var user: User
    
    @Environment(\.colorScheme)
    var colorScheme: ColorScheme
    
    static var scrollTo = PassthroughSubject<(String, String), Never>()
    
    @State var scrolledOutOfBounds: Bool = false
    
    
    // MARK: - init
    init(_ channel: Channel, _ guildName: String? = nil, model: StateObject<ChannelViewViewModel>? = nil) {
        guildID = channel.guild_id ?? "@me"
        channelID = channel.id
        channelName = channel.name ?? channel.recipients?.first?.username ?? "Unknown channel"
        self.guildName = guildName ?? "Direct Messages"
        if let model {
            self._viewModel = model
        } else {
            _viewModel = StateObject(wrappedValue: ChannelViewViewModel(channel: channel))
        }
        viewModel.memberList = channel.recipients?.map(OPSItems.init) ?? []
        if wss.connection?.state == .cancelled {
            concurrentQueue.async {
                wss?.reset()
            }
        }
        UITableView.appearance().showsVerticalScrollIndicator = false
    }
    
    @inline(__always)
         func cell(for message: Message) -> some View {
             MessageCellView(
                 message: message,
                 nick: viewModel.nicks[message.author?.id ?? ""],
                 replyNick: viewModel.nicks[message.referenced_message?.author?.id ?? ""],
                 pronouns: viewModel.pronouns[message.author?.id ?? ""],
                 avatar: viewModel.avatars[message.author?.id ?? ""],
                 guildID: viewModel.guildID,
                 permissions: $viewModel.permissions,
                 role: $viewModel.roles[message.author?.id ?? ""],
                 replyRole: $viewModel.roles[message.referenced_message?.author?.id ?? ""],
                 replyingTo: $replyingTo
             )
             .equatable()
             .id(message.id)
             .listRowInsets(EdgeInsets(
                 top: 3.5,
                 leading: 0,
                 bottom: message.bottomInset,
                 trailing: 0
             ))
             .padding(.horizontal, 5.0)
             .padding(.vertical, message.userMentioned ? 3.0 : 0.0)
             .background(message.userMentioned ? Color.yellow.opacity(0.1).cornerRadius(7) : nil)
             .onAppear { [unowned viewModel] in
                 if viewModel.messages.count >= 50,
                    message == viewModel.messages[viewModel.messages.count - 2]
                 {
                     messageFetchQueue.async {
                         viewModel.loadMoreMessages()
                     }
                 }
             }
         }
    
    var messagesView: some View {
        ForEach(viewModel.messages, id: \.identifier) { message in
            if let author = message.author {
                if message.inSameDay {
                    cell(for: message)
                } else {
                    VStack {
                        HStack {
                            Color.secondary
                                .frame(height: 0.75)
                                .opacity(0.4)
                            Text(message.processedTimestamp?.components(separatedBy: " at ").first ?? "Today")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                            Color.secondary
                                .frame(height: 0.75)
                                .opacity(0.4)
                        }
                        .padding(.top)
                        cell(for: message)
                    }
                }
            }
        }
        .offset(x: 0, y: -1)
        .rotationEffect(.radians(.pi))
        .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
    }
    
    var messagePlaceholderView : some View {
        ForEach(1..<20) { _ in
            VStack {
                HStack(alignment: .bottom) {
                    Circle()
                        .foregroundColor(.gray)
                        .frame(width: 35, height: 35)
                        .padding(.trailing, 1.5)
                        .fixedSize()
                    
                    VStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: 30 * CGFloat(Int.random(in: 3...20)), height: 13 * CGFloat(Int.random(in: 1...5)))
                            .cornerRadius(6)
                        Rectangle()
                            .frame(width: 20 * CGFloat(Int.random(in: 3...10)), height: 13)
                            .cornerRadius(6)
                        Spacer().frame(height: 1.3)
                    }
                }
                .foregroundColor(.secondary.opacity(0.85))
                .opacity(0.5)
                Spacer()
            }
        }
    }
    
    @ViewBuilder
         private var channelHeaderView: some View {
             Divider()
             Text("This is the start of the channel")
                 .font(.system(size: 15))
                 .fontWeight(.semibold)
             Text("Welcome to #\(channelName)!")
                 .bold()
                 .dynamicTypeSize(.xxxLarge)
                 .font(.largeTitle)
         }
    
    var body: some View {
        HStack(content: {
            VStack(spacing: 0) {
                List {
                    Spacer().frame(height: 15)
                    messagesView
                        .listRowSeparator(.hidden)
                    if viewModel.noMoreMessages {
                        channelHeaderView
                            .rotationEffect(.degrees(180))
                            .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                            .listRowSeparator(.hidden)
                    } else {
                        messagePlaceholderView
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .rotationEffect(.radians(.pi))
                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                .padding()
                .scrollIndicators(.hidden)
                blurredTextField
            }
            if memberListShown {
                MemberListView(guildID: viewModel.guildID, list: $viewModel.memberList)
                    .frame(width: 250)
                    .onAppear { [unowned viewModel] in
                        if viewModel.memberList.isEmpty && viewModel.guildID != "@me" {
                            try? wss.memberList(for: viewModel.guildID, in: viewModel.channelID)
                        }
                    }
            }
        })
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(Text("\(viewModel.guildID == "@me" ? "" : "#")\(channelName)".replacingOccurrences(of: "#", with: "")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Toggle(isOn: $pins) {
                    Image(systemName: "pin.fill")
                        .rotationEffect(.degrees(45))
                }
                .popover(isPresented: $pins) { [unowned viewModel] in
                    PinsView(guildID: viewModel.guildID, channelID: viewModel.channelID, replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 600)
                }
                Toggle(isOn: $mentions) {
                    Image(systemName: "bell.badge.fill")
                }
                .popover(isPresented: $mentions) {
                    MentionsView(replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 600)
                }
                Toggle(isOn: $memberListShown.animation()) {
                    Image(systemName: "person.2.fill")
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

struct MemberListView: View {
    var guildID: String
    @Binding var list: [OPSItems]
    var body: some View {
        List(self.$list, id: \.id) { $ops in
            if let group = ops.group {
                Text(
                    "\(group.id == "offline" ? "Offline" : group.id == "online" ? "Online" : Storage.roleNames[group.id ?? ""] ?? "") - \(group.count ?? 0)"
                )
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding([.top])
            } else {
                MemberListViewCell(guildID: self.guildID, ops: $ops)
            }
        }
    }
}

struct MemberListViewCell: View {
    var guildID: String
    @Binding var ops: OPSItems
    @State var popup: Bool = false
    var body: some View {
        Button(action: {
            self.popup.toggle()
        }) { [unowned ops] in
            HStack {
                Attachment(pfpURL(ops.member?.user.id ?? "", ops.member?.user.avatar ?? "", discriminator: ops.member?.user.discriminator ?? "", "24"))
                    .equatable()
                    .frame(width: 33, height: 33)
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text(ops.member?.nick ?? ops.member?.user.username ?? "")
                        .fontWeight(.medium)
                        .foregroundColor({ () -> Color in
                            if let role = ops.member?.roles?.first, let color = Storage.roleColors[role]?.0 {
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
        .buttonStyle(.borderless)
        .sheet(isPresented: self.$popup, content: {
            PopoverProfileView(user: ops.member?.user, guildID: guildID)
                .presentationDetents([.medium])
        })
    }
}
