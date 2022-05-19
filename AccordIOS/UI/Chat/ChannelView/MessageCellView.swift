//
//  MessageCellView.swift
//  Accord
//
//  Created by evelyn on 2021-12-12.
//

import UIKit
import AVKit
import Combine
import Foundation
import SwiftUI

fileprivate var encoder: ISO8601DateFormatter = {
    let encoder = ISO8601DateFormatter()
    encoder.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return encoder
}()

struct MessageCellView: View, Equatable {
    static func == (lhs: MessageCellView, rhs: MessageCellView) -> Bool {
        lhs.message == rhs.message && lhs.nick == rhs.nick && lhs.avatar == rhs.avatar
    }

    var message: Message
    var nick: String?
    var replyNick: String?
    var pronouns: String?
    var avatar: String?
    var guildID: String?
    var permissions: Permissions
    @Binding var role: String?
    @Binding var replyRole: String?
    @Binding var replyingTo: Message?
    @State var editing: Bool = false
    @State var popup: Bool = false
    @State var textElement: Text?
    @State var bag = Set<AnyCancellable>()
    @State var editedText: String = ""

    @AppStorage("GifProfilePictures")
    var gifPfp: Bool = false

    var editingTextField: some View {
        TextField("Edit your message", text: self.$editedText, onEditingChanged: { _ in }) {
            message.edit(now: self.editedText)
            self.editing = false
            self.editedText = ""
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .onAppear {
            self.editedText = message.content
        }
    }

    func timeout(time: String) {
        let url = URL(string: "https://discord.com/api/v9/guilds/")?
            .appendingPathComponent(guildID!)
            .appendingPathComponent("members")
            .appendingPathComponent(message.author!.id)
        DispatchQueue.global().async {
            Request.ping(url: url, headers: Headers(
                userAgent: discordUserAgent,
                token: AccordCoreVars.token,
                bodyObject: ["communication_disabled_until":time],
                type: .PATCH,
                discordHeaders: true,
                referer: "https://discord.com/channels/\(guildID!)/\(self.message.channel_id)",
                json: true
            ))
        }
    }
    
    private var reactionsGrid: some View {
        LazyVGrid.init(columns: Array.init(repeating: GridItem(.flexible(minimum: 45, maximum: 55), spacing: 4), count: 4), alignment: .leading, spacing: 4, content: {
            ForEach(message.reactions ?? [], id: \.identifier) { reaction in
                HStack(spacing: 4) {
                    if let id = reaction.emoji.id {
                        Attachment(cdnURL + "/emojis/\(id).png?size=16")
                            .equatable()
                            .frame(width: 16, height: 16)
                    } else if let name = reaction.emoji.name {
                        Text(name)
                            .frame(width: 16, height: 16)
                    }
                    Text(String(reaction.count))
                        .fontWeight(Font.Weight.medium)
                }
                .padding(4)
                .frame(minWidth: 45, maxWidth: 55)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(4)
            }
        })
        .padding(.leading, 41)
    }
    
    private var stickerView: some View {
        ForEach(message.sticker_items ?? [], id: \.id) { sticker in
            Attachment("https://media.discordapp.net/stickers/\(sticker.id).png?size=160")
                .equatable()
                .frame(width: 160, height: 160)
                .cornerRadius(3)
                .padding(.leading, 41)
        }
    }
    
    private var authorText: some View {
        HStack(spacing: 1) {
            Text(nick ?? message.author?.username ?? "Unknown User")
                .foregroundColor({ () -> Color in
                    if let role = role, let color = roleColors[role]?.0, !message.isSameAuthor {
                        return Color(int: color)
                    }
                    return Color.primary
                }())
                .font(.chatTextFont)
                .fontWeight(.semibold)
                +
                Text("  \(message.processedTimestamp ?? "")")
                .foregroundColor(Color.secondary)
                .font(.subheadline)
                +
                Text(message.edited_timestamp != nil ? " (edited at \(message.edited_timestamp?.makeProperHour() ?? "unknown time"))" : "")
                .foregroundColor(Color.secondary)
                .font(.subheadline)
                +
                Text((pronouns != nil) ? " • \(pronouns ?? "Use my name")" : "")
                .foregroundColor(Color.secondary)
                .font(.subheadline)
            if message.author?.bot ?? false {
                Text("Bot")
                    .padding(.horizontal, 4)
                    .foregroundColor(Color.white)
                    .font(.subheadline)
                    .background(Capsule().fill().foregroundColor(Color.red))
                    .padding(.horizontal, 4)
            }
        }

    }
    
    private var copyMenu: some View {
        Menu("Copy") {
            Button("Copy message text") { [weak message] in
                guard let content = message?.content else { return }
                UIPasteboard.general.string = ""
                UIPasteboard.general.string = content
            }
            Button("Copy message link") { [weak message] in
                guard let channelID = message?.channel_id, let id = message?.id else { return }
                UIPasteboard.general.string = ""
                UIPasteboard.general.string = "https://discord.com/channels/\(message?.guild_id ?? guildID ?? "@me")/\(channelID)/\(id)"
            }
            Button("Copy user ID") { [weak message] in
                guard let id = message?.author?.id else { return }
                UIPasteboard.general.string = ""
                UIPasteboard.general.string = id
            }
            Button("Copy message ID") { [weak message] in
                guard let id = message?.id else { return }
                UIPasteboard.general.string = ""
                UIPasteboard.general.string = id
            }
            Button("Copy username and tag", action: { [weak message] in
                guard let author = message?.author else { return }
                UIPasteboard.general.string = ""
                UIPasteboard.general.string = "\(author.username)#\(author.discriminator)"
            })
        }

    }
    
    private var moderationMenu: some View {
        Menu("Moderation") {
            Button("Ban") {
                let url = URL(string: rootURL)?
                    .appendingPathComponent("guilds")
                    .appendingPathComponent(guildID!)
                    .appendingPathComponent("bans")
                    .appendingPathComponent(message.author!.id)
                DispatchQueue.global().async {
                    Request.ping(url: url, headers: Headers(
                        userAgent: discordUserAgent,
                        token: AccordCoreVars.token,
                        bodyObject: ["delete_message_days":1],
                        type: .PUT,
                        discordHeaders: true,
                        referer: "https://discord.com/channels/\(guildID!)/\(self.message.channel_id)"
                    ))
                }
            }
            .disabled(!permissions.contains(.banMembers))
            Button("Kick") {
                let url = URL(string: rootURL)?
                    .appendingPathComponent("guilds")
                    .appendingPathComponent(guildID!)
                    .appendingPathComponent("members")
                    .appendingPathComponent(message.author!.id)
                DispatchQueue.global().async {
                    Request.ping(url: url, headers: Headers(
                        userAgent: discordUserAgent,
                        token: AccordCoreVars.token,
                        type: .DELETE,
                        discordHeaders: true,
                        referer: "https://discord.com/channels/\(guildID!)/\(self.message.channel_id)"
                    ))
                }
            }
            .disabled(!permissions.contains(.kickMembers))
            Menu("Timeout") {
                Button("60 seconds") {
                    let date = Date() + 60
                    let encoded = encoder.string(from: date)
                    self.timeout(time: encoded)
                }
                Button("5 minutes") {
                    let date = Date() + 60 * 5
                    let encoded = encoder.string(from: date)
                    self.timeout(time: encoded)
                }
                Button("10 minutes") {
                    let date = Date() + 60 * 10
                    let encoded = encoder.string(from: date)
                    self.timeout(time: encoded)
                }
                Button("1 hour") {
                    let date = Date() + 60 * 60
                    let encoded = encoder.string(from: date)
                    self.timeout(time: encoded)
                }
                Button("1 day") {
                    let date = Date() + 60 * 60 * 24
                    let encoded = encoder.string(from: date)
                    self.timeout(time: encoded)
                }
                Button("1 week") {
                    let date = Date() + 60 * 60 * 24 * 7
                    let encoded = encoder.string(from: date)
                    self.timeout(time: encoded)
                }
            }
            .disabled(!permissions.contains(.moderateMembers))
        }
    }
    
    private var attachmentMenu: some View {
        ForEach(message.attachments, id: \.url) { attachment in
            Menu(attachment.filename) { [weak attachment] in
                if let stringURL = attachment?.url, let url = URL(string: stringURL) {
                    Button("Open URL in browser") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Copy image URL") {
                    UIPasteboard.general.string = ""
                    UIPasteboard.general.string = attachment?.url ?? ""
                }
            }
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Reply") { [weak message] in
            replyingTo = message
        }
        Button("Edit") {
            self.editing.toggle()
        }
        .if(message.author?.id != AccordCoreVars.user?.id, transform: { $0.hidden() })
        Button("Delete") { [weak message] in
            DispatchQueue.global().async {
                message?.delete()
            }
        }
        .if(message.author?.id != AccordCoreVars.user?.id && !self.permissions.contains(.manageMessages),
            transform: { $0.hidden() })
        Button(message.pinned == false ? "Pin" : "Unpin") {
            let url = URL(string: rootURL)?
                .appendingPathComponent("channels")
                .appendingPathComponent(message.channel_id)
                .appendingPathComponent("pins")
                .appendingPathComponent(message.id)
            DispatchQueue.global().async {
                Request.ping(url: url, headers: Headers(
                    userAgent: discordUserAgent,
                    token: AccordCoreVars.token,
                    type: message.pinned == false ? .PUT : .DELETE,
                    discordHeaders: true,
                    referer: "https://discord.com/channels/\(guildID ?? "@me")/\(self.message.channel_id)"
                ))
                DispatchQueue.main.async {
                    message.pinned?.toggle()
                }
            }
        }
        .if(!(self.permissions.contains(.manageMessages) || guildID == "@me" || guildID == nil), transform: { $0.hidden() })
        Divider()
        Button("Show profile") {
            popup.toggle()
        }
        Divider()
        copyMenu
        if message.author != nil &&
            guildID != nil &&
            guildID != "@me" &&
            (permissions.contains(.moderateMembers)
            || permissions.contains(.banMembers)
            || permissions.contains(.kickMembers)) {
            Divider()
            moderationMenu
        }
        if !message.attachments.isEmpty {
            Divider()
            attachmentMenu
        }
    }
    
    private var replyView: some View {
        HStack {
                    RoundedRectangle(cornerRadius: 5)
                        .trim(from: 0.5, to: 0.75)
                        .stroke(.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 53, height: 20)
                        .padding(.bottom, -15)
                        .padding(.trailing, -30)
            Attachment(pfpURL(message.referenced_message?.author?.id, message.referenced_message?.author?.avatar, discriminator: message.referenced_message?.author?.discriminator ?? "0005", "16"))
                .equatable()
                .frame(width: 15, height: 15)
                .clipShape(Circle())
            Text(replyNick ?? message.referenced_message?.author?.username ?? "")
                .font(.subheadline)
                .foregroundColor({ () -> Color in
                    if let replyRole = replyRole, let color = roleColors[replyRole]?.0, !message.isSameAuthor {
                        return Color(int: color)
                    }
                    return Color.primary
                }())
                .fontWeight(.semibold)
            Text(message.referenced_message?.content ?? "Error")
                .font(.subheadline)
                .lineLimit(0)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, -3)
                 .padding(.leading, 15)
    }
    
    private var interactionView: some View {
        HStack {
            Attachment(pfpURL(message.interaction?.user?.id, message.interaction?.user?.avatar, "16"))
                .equatable()
                .frame(width: 15, height: 15)
                .clipShape(Circle())
            Text(message.interaction?.user?.username ?? "")
                .font(.subheadline)
                .foregroundColor({ () -> Color in
                    if let replyRole = replyRole, let color = roleColors[replyRole]?.0, !message.isSameAuthor {
                        return Color(int: color)
                    }
                    return Color.primary
                }())
                .fontWeight(.semibold)
            Text("/" + (message.interaction?.name ?? ""))
                .font(.subheadline)
                .lineLimit(0)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 47)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if message.referenced_message != nil {
                replyView
            }
            if message.interaction != nil {
                interactionView
            }
            switch message.type {
            case .recipientAdd:
                Label(title: {
                    Text(message.author?.username ?? "Unknown User").fontWeight(.semibold)
                    + Text(" added ")
                    + Text(message.mentions.first??.username ?? "Unknown User").fontWeight(.semibold)
                    + Text(" to the group")
                }, icon: {
                    Image(systemName: "arrow.forward").foregroundColor(.green)
                })
                .padding(.leading, 41)
            case .recipientRemove:
                Label(title: {
                    Text(message.author?.username ?? "Unknown User").fontWeight(.semibold)
                    + Text(" left the group")
                }, icon: {
                    Image(systemName: "arrow.backward").foregroundColor(.red)
                })
                .padding(.leading, 41)
            case .channelNameChange:
                Label(title: {
                    Text(message.author?.username ?? "Unknown User").fontWeight(.semibold)
                    + Text(" changed the channel name")
                }, icon: {
                    Image(systemName: "pencil")
                })
                .padding(.leading, 41)
            case .guildMemberJoin:
                Label(title: {
                    (Text("Welcome, ")
                     + Text(message.author?.username ?? "Unknown User").fontWeight(.semibold)
                    + Text("!"))
                }, icon: {
                    Image(systemName: "arrow.forward").foregroundColor(.green)
                })
                .padding(.leading, 41)
            default:
                HStack(alignment: .top) { [unowned message] in
                    if !(message.isSameAuthor && message.referenced_message == nil) {
                        Attachment(avatar != nil ? cdnURL + "/guilds/\(guildID ?? "")/users/\(message.author?.id ?? "")/avatars/\(avatar!).png?size=48" : pfpURL(message.author?.id, message.author?.avatar, discriminator: message.author?.discriminator ?? "0005"))
                            .equatable()
                            .frame(width: 33, height: 33)
                            .clipShape(Circle())
                            .popover(isPresented: $popup, content: {
                                PopoverProfileView(user: message.author)
                            })
                    }
                    VStack(alignment: .leading) {
                        if message.isSameAuthor, message.referenced_message == nil {
                            if !message.content.isEmpty {
                                if self.editing {
                                    editingTextField
                                        .padding(.leading, 41)
                                } else {
                                    AsyncMarkdown(message.content)
                                        .equatable()
                                        .padding(.leading, 41)
                                }
                            } else {
                                Spacer().frame(height: 2)
                            }
                        } else {
                            authorText
                            if !message.content.isEmpty {
                                if self.editing {
                                    editingTextField
                                } else {
                                    AsyncMarkdown(message.content)
                                        .equatable()
                                }
                            }
                        }
                    }
                    Spacer()
                }

            }
            
            if message.reactions?.isEmpty == false {
                reactionsGrid
            }
            ForEach(message.embeds ?? [], id: \.id) { embed in
                EmbedView(embed: embed)
                    .equatable()
                    .padding(.leading, 41)
            }
            stickerView
            AttachmentView(media: message.attachments)
                .padding(.leading, 41)
                .padding(.top, 5)
        }
        .contextMenu { contextMenuContent }
        .id(message.id)
    }
}
