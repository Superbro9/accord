//
//  ChatControlsViewModel.swift
//  Accord
//
//  Created by evelyn on 2022-01-23.
//

import UIKit
import Combine
import Foundation
import SwiftUI

final class ChatControlsViewModel: ObservableObject {
    @Published var matchedUsers: [String: String] = .init()
    @Published var matchedChannels: [Channel] = .init()
    @Published var matchedEmoji: [DiscordEmote] = .init()
    @Published var matchedCommands: [SlashCommandStorage.Command] = .init()
    @Published var textFieldContents: String = .init()
    @Published var percent: String? = nil
    var observation: NSKeyValueObservation?
    var command: SlashCommandStorage.Command?

    var currentValue: String?
    var currentRange: Int?

    @AppStorage("SilentTyping")
    var silentTyping: Bool = false
    
    var locked: Bool = false
    var runOnUnlock: (() -> Void)?

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.findView()
        })
    }
    
    func checkText(guildID: String, channelID: String) {
        let ogContents = self.textFieldContents
        let mentions = textFieldContents.matches(precomputed: RegexExpressions.chatTextMentions)
        let channels = textFieldContents.matches(precomputed: RegexExpressions.chatTextChannels)
        let slashes = textFieldContents.matches(precomputed: RegexExpressions.chatTextSlashCommand)
        let emoji = textFieldContents.matches(precomputed: RegexExpressions.chatTextEmoji)
        let emotes = textFieldContents.matches(precomputed: RegexExpressions.completedEmote)
        
        emotes.forEach { emoji in
            let emote = emoji.dropLast().dropFirst().stringLiteral
            guard let matched: DiscordEmote = Array(Storage.emotes.values.joined()).filter({ $0.name.lowercased() == emote.lowercased() }).first else { return }
            DispatchQueue.main.async {
                if self.textFieldContents != ogContents { return }
                self.textFieldContents = self.textFieldContents.replacingOccurrences(of: emoji, with: "<\((matched.animated ?? false) ? "a" : ""):\(matched.name):\(matched.id)> ")
            }
        }
        
        guard !self.textFieldContents.isEmpty else {
            DispatchQueue.main.async {
                self.matchedEmoji.removeAll()
                self.matchedCommands.removeAll()
                self.matchedUsers.removeAll()
                self.matchedChannels.removeAll()
            }
            return
        }
        
        if let search = mentions.last?.lowercased() {
            let matchedUsers: [String: String] = Storage.usernames
                .filterValues { $0.lowercased().contains(search) }
                .mapKeys { "!" + $0 }
            let matchedRoles = Storage.roleNames
                .filterValues { $0.lowercased().contains(search) }
                .mapKeys { "&" + $0 }
            let matched = matchedUsers.merging(matchedRoles, uniquingKeysWith: { (_, last) in last })
            DispatchQueue.main.async {
                self.matchedUsers = matched
            }
        } else if let search = channels.last {
            let matches = Storage.folders.map { $0.guilds.compactMap { $0.channels.filter { $0.name?.contains(search) ?? false } } }
            let joined: [Channel] = Array(Array(Array(matches).joined()).joined())
                .filter { $0.guild_id == guildID }
                .prefix(10)
                .literal()
            DispatchQueue.main.async {
                self.matchedChannels = joined
            }
        } else if let command = slashes.last?.trimmingCharacters(in: .letters.inverted),
                  textFieldContents.prefix(1) == "/", guildID != "@me"
        {
            guard !locked else {
                self.runOnUnlock = { [weak self] in
                    self?.checkText(guildID: guildID, channelID: channelID)
                }
                return
            }
            locked = true
            print("querying", command)
            let url = URL(string: rootURL)?
                .appendingPathComponent("channels")
                .appendingPathComponent(channelID)
                .appendingPathComponent("application-commands")
                .appendingPathComponent("search")
                .appendingQueryParameters([
                    "type":"1",
                    "query":command,
                    "limit":"7",
                    "include_applications":"true"
                ])
            Request.fetch(
                SlashCommandStorage.GuildApplicationCommandsUpdateEvent.D.self,
                url: url,
                headers: standardHeaders
            ) {
                switch $0 {
                case .success(let commands):
                    DispatchQueue.main.async {
                        self.matchedCommands = commands.application_commands
                    }
                case .failure(let error):
                    print(error)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
                self.locked = false
                self.runOnUnlock?()
            })
        } else if let key = emoji.last {
            let matched = Array(Storage.emotes.values.joined())
                .filter { $0.name.lowercased().contains(key) }
                .prefix(10)
                .literal()
            DispatchQueue.main.async {
                self.matchedEmoji = matched
            }
        }
    }

    func findView() {
        UIKitLink<UITextField>.introspect { textField, _ in
            DispatchQueue.main.async {
                textField.allowsEditingTextAttributes = true
            }
        }
    }

    func clearMatches() {
        DispatchQueue.main.async {
            self.matchedEmoji.removeAll()
            self.matchedUsers.removeAll()
            self.matchedChannels.removeAll()
        }
    }

    func send(text: String, guildID: String, channelID: String) {
        Request.ping(url: URL(string: "\(rootURL)/channels/\(channelID)/messages"), headers: Headers(
            token: Globals.token,
            bodyObject: ["content": text, "tts": false, "nonce": generateFakeNonce()],
            type: .POST,
            discordHeaders: true,
            referer: "https://discord.com/channels/\(guildID)/\(channelID)",
            empty: true,
            json: true
        ))
    }

    func emptyTextField() {
        DispatchQueue.main.async {
            self.textFieldContents = ""
        }
    }

    func executeCommand(guildID: String, channelID: String) throws {
        guard let command = command else {
            if textFieldContents.prefix(6) == "/nick " {
                let nick = textFieldContents.dropFirst(6).stringLiteral
                Request.ping(url: URL(string: "\(rootURL)/guilds/\(guildID)/members/%40me/nick"), headers: Headers(
                    userAgent: discordUserAgent,
                    token: Globals.token,
                    bodyObject: ["nick": nick],
                    type: .PATCH,
                    discordHeaders: true,
                    json: true
                ))
                emptyTextField()
            } else if textFieldContents.prefix(6) == "/shrug" {
                send(text: #"¯\_(ツ)_/¯"#, guildID: guildID, channelID: channelID)
                self.emptyTextField()
            } else if textFieldContents.prefix(6) == "/debug" {
                sendDebugLog(guildID: guildID, channelID: channelID)
                self.emptyTextField()
            } else if textFieldContents.prefix(6) == "/reset" {
                wss.reset()
                self.emptyTextField()
            } else if textFieldContents.prefix(12) == "/reset force" {
                wss.hardReset()
                self.emptyTextField()
            } else if textFieldContents.prefix(5) == "/help" {
                let help = """
                **Slash commands**
                `/shrug`: shrug
                `/debug`: send debug log
                `/reset`: resume websocket connection
                `/reset force`: force reset websocket connection
                """
                let system = Globals.user
                system?.id = generateFakeNonce()
                system?.username = "Accord"
                system?.discriminator = "0000"
                system?.avatar = nil
                let message = Message (
                    author: system,
                    channel_id: channelID,
                    guild_id: guildID,
                    content: help,
                    id: generateFakeNonce(),
                    mentions: [],
                    timestamp: .init(),
                    type: .default,
                    attachments: .init(),
                    sticker_items: .init()
                )
                let gatewayMessage = GatewayEventCodable(d: message)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(gatewayMessage)
                wss.messageSubject.send((data, channelID, false))
            }
            return
        }
        var options: [[String: Any]] = []
        if command.options?.count != 0 {
            let args: [(key: String, value: Any)] = textFieldContents
                .matches(for: #"(\S+):((?:(?! \S+:).)+)"#)
                .compactMap { arg -> (key: String, value: Any)? in
                    let components = arg.components(separatedBy: ":")
                    if let key = components.first, let value = components.last {
                        return (key: key, value: value)
                    } else {
                        return nil
                    }
                }
            options = args.map { arg -> [String: Any] in
                ["name": arg.key, "type": 3, "value": arg.value]
            }
        }

        try SlashCommands.interact(
            applicationID: command.application_id,
            guildID: guildID,
            channelID: channelID,
            appVersion: command.version,
            id: command.id,
            dataType: 1,
            appName: command.name,
            appDescription: command.description,
            options: command.options ?? [],
            optionValues: options
        )

        DispatchQueue.main.async {
            self.command = nil
            self.matchedCommands.removeAll()
            self.emptyTextField()
        }
    }

    var debugLog: String {
        """
        **Accord Debug Log**
        Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        Gateway State: \(wss.connection?.state as Any)
        Compression: \(wss.compress ? "Enabled" : "Disabled")
        Message Subscriber: \(String(reflecting: wss.messageSubject))
        Compressor State: \(wss.decompressor.status)
        Connection State: \(reachability?.connection as Any)
        """
    }
    
    func sendDebugLog(guildID: String, channelID: String) {
        self.send(text: debugLog, guildID: guildID, channelID: channelID)
    }
    
    func send(text: String, replyingTo: Message, mention: Bool, guildID: String) {
        Request.ping(url: URL(string: "\(rootURL)/channels/\(replyingTo.channel_id)/messages"), headers: Headers(
            token: Globals.token,
            bodyObject: ["content": text, "allowed_mentions": ["parse": ["users", "roles", "everyone"], "replied_user": mention], "message_reference": ["channel_id": replyingTo.channel_id, "message_id": replyingTo.id], "tts": false, "nonce": generateFakeNonce()],
            type: .POST,
            discordHeaders: true,
            referer: "https://discord.com/channels/\(guildID)/\(replyingTo.channel_id)",
            empty: true,
            json: true
        ))
    }

    func send(text: String, file: [URL], data: [Data], channelID: String) {
        var request = URLRequest(url: URL(string: "\(rootURL)/channels/\(channelID)/messages")!)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue(Globals.token, forHTTPHeaderField: "Authorization")
        guard let string = try? ["content": text].jsonString() else { return }
        request.httpBody = try? Request.createMultipartBody(with: string, fileURLs: file.map(\.absoluteString), boundary: boundary, fileData: data)
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, res, _ in
            if let response = res as? HTTPURLResponse, response.statusCode == 200 {
                DispatchQueue.main.async {
                    self?.observation = nil
                    self?.percent = nil
                }
            }
        }
        observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.percent = "Uploading \(String(Int(progress.fractionCompleted * 100)))%"
            }
        }
        task.resume()
    }

    func type(channelID: String, guildID: String) {
        guard !silentTyping else { return }
        Request.ping(url: URL(string: rootURL + "/channels/\(channelID)/typing"), headers: Headers(
            token: Globals.token,
            type: .POST,
            discordHeaders: true,
            referer: "https://discord.com/channels/\(guildID)/\(channelID)"
        ))
    }
}

func generateFakeNonce() -> String {
    let date: Double = Date().timeIntervalSince1970
    let nonceNumber = (Int(date) * 1000 - 1_420_070_400_000) * 4_194_304
    return String(nonceNumber)
}
