//
//  MessageCellMenu.swift
//  Accord
//
//  Created by evelyn on 2022-05-31.
//

import SwiftUI
import AVKit

fileprivate var encoder: ISO8601DateFormatter = {
    let encoder = ISO8601DateFormatter()
    encoder.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return encoder
}()

struct MessageCellMenu: View {
    
    var message: Message
    var guildID: String
    var permissions: Permissions
    @Binding var replyingTo: Message?
    @Binding var editing: Bool
    @Binding var popup: Bool
    @Binding var showEditNicknamePopover: Bool
    
    @ViewBuilder
    private var moderationSection: some View {
        if self.guildID == "@me" || (self.guildID != "@me" && permissions.moderator) {
            Divider()
        }
        if self.permissions.contains(.manageMessages) || guildID == "@me" {
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
                        referer: "https://discord.com/channels/\(guildID)/\(self.message.channel_id)"
                    ))
                    DispatchQueue.main.async {
                        message.pinned?.toggle()
                    }
                }
            }
        }
        if message.author != nil &&
            guildID != "@me" &&
            permissions.moderator {
                moderationMenu
        } else if self.guildID == "@me" && permissions.contains(.kickMembers) {
            Button("Remove member") {
                let url = URL(string: rootURL)?
                    .appendingPathComponent("channels")
                    .appendingPathComponent(self.message.channel_id)
                    .appendingPathComponent("recipients")
                    .appendingPathComponent(message.author!.id)
                DispatchQueue.global().async {
                    Request.ping(url: url, headers: Headers(
                        userAgent: discordUserAgent,
                        token: AccordCoreVars.token,
                        type: .DELETE,
                        discordHeaders: true,
                        referer: "https://discord.com/channels/@me/\(self.message.channel_id)"
                    ))
                }
            }
        }
    }
    
    func timeout(time: String) {
        let url = URL(string: "https://discord.com/api/v9/guilds/")?
            .appendingPathComponent(guildID)
            .appendingPathComponent("members")
            .appendingPathComponent(message.author!.id)
        DispatchQueue.global().async {
            Request.ping(url: url, headers: Headers(
                userAgent: discordUserAgent,
                token: AccordCoreVars.token,
                bodyObject: ["communication_disabled_until":time],
                type: .PATCH,
                discordHeaders: true,
                referer: "https://discord.com/channels/\(guildID)/\(self.message.channel_id)",
                json: true
            ))
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
                UIPasteboard.general.string = "https://discord.com/channels/\(message?.guild_id ?? guildID)/\(channelID)/\(id)"
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
            if permissions.contains(.banMembers) {
                Button("Ban") {
                    let url = URL(string: rootURL)?
                        .appendingPathComponent("guilds")
                        .appendingPathComponent(guildID)
                        .appendingPathComponent("bans")
                        .appendingPathComponent(message.author!.id)
                    DispatchQueue.global().async {
                        Request.ping(url: url, headers: Headers(
                            userAgent: discordUserAgent,
                            token: AccordCoreVars.token,
                            bodyObject: ["delete_message_days":1],
                            type: .PUT,
                            discordHeaders: true,
                            referer: "https://discord.com/channels/\(guildID)/\(self.message.channel_id)"
                        ))
                    }
                }
            }
            if permissions.contains(.kickMembers) {
                Button("Kick") {
                    let url = URL(string: rootURL)?
                        .appendingPathComponent("guilds")
                        .appendingPathComponent(guildID)
                        .appendingPathComponent("members")
                        .appendingPathComponent(message.author!.id)
                    DispatchQueue.global().async {
                        Request.ping(url: url, headers: Headers(
                            userAgent: discordUserAgent,
                            token: AccordCoreVars.token,
                            type: .DELETE,
                            discordHeaders: true,
                            referer: "https://discord.com/channels/\(guildID)/\(self.message.channel_id)"
                        ))
                    }
                }
            }
            if permissions.contains(.moderateMembers) {
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
            }
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
                Button("Copy media URL") {
                    UIPasteboard.general.string = ""
                    UIPasteboard.general.string = attachment?.url ?? ""
                }
            }
        }
    }
    
    var body: some View {
        Button("Reply") { [weak message] in
            replyingTo = message
        }
        if message.author?.id == AccordCoreVars.user?.id {
            Button("Edit") {
                self.editing.toggle()
            }
        }
        if message.author?.id == AccordCoreVars.user?.id || self.permissions.contains(.manageMessages) {
            Button("Delete") { [weak message] in
                DispatchQueue.global().async {
                    message?.delete()
                }
            }
        }
        Divider()
        Button("Show profile") {
            popup.toggle()
        }
        
        if ((message.author == AccordCoreVars.user) || self.permissions.contains(.manageNicknames)) && guildID != "@me" {
            Button("Set nickname") {
                showEditNicknamePopover.toggle()
            }
        }
        
        Divider()
        copyMenu
        if !message.attachments.isEmpty {
            Divider()
            attachmentMenu
        }
        moderationSection
    }
}
