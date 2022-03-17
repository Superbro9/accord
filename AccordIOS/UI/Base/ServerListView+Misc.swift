//
//  ServerListView+Misc.swift
//  ServerListView+Misc
//
//  Created by evelyn on 2021-09-12.
//

import Foundation

extension ServerListView {
    static func fastIndexGuild(_ guild: String, array: [Guild]) -> Int? {
        let messageDict = array.generateKeyMap()
        return messageDict[guild]
    }

    func fastIndexChannels(_ channel: String, array: [Channel]) -> Int? {
        let messageDict = array.generateKeyMap()
        return messageDict[channel]
    }

    func fastIndexEntries(_ entry: String, array: [ReadStateEntry]) -> Int? {
        let messageDict = array.generateKeyMap()
        return messageDict[entry]
    }

    func assignPrivateReadStates() {
        let privateReadStateDict = Self.readStates.generateKeyMap()
        for (i, channel) in Self.privateChannels.enumerated() {
            if let index = privateReadStateDict[channel.id] {
                Self.privateChannels[i].read_state = Self.readStates[index]
            }
        }
        print("Binded to private channels")
        Self.readStates.removeAll()
    }
}

extension GatewayD {
    func order() {
        let showHiddenChannels = UserDefaults.standard.bool(forKey: "ShowHiddenChannels")
        self.guilds.enumerated().forEach { index, _guild in
            var guild = _guild
            guild.channels = guild.channels?.sorted { ($0.type.rawValue, $0.position ?? 0, $0.id) < ($1.type.rawValue, $1.position ?? 0, $1.id) }
            guard let rejects = guild.channels?
                .filter({ $0.parent_id == nil && $0.type != .section }),
                  let parents: [Channel] = guild.channels?.filter({ $0.type == .section }),
                  let sections = Array(NSOrderedSet(array: parents)) as? [Channel] else { return }
            var sectionFormatted: [Channel] = .init()
            sections.forEach { channel in
                guard let matching = guild.channels?
                    .filter({ $0.parent_id == channel.id })
                    .filter({ showHiddenChannels ? true : ($0.shown ?? true) }),
                      !matching.isEmpty else { return }
                sectionFormatted.append(channel)
                sectionFormatted.append(contentsOf: matching)
            }
            var threadFormatted: [Channel] = .init()
            sectionFormatted.forEach { channel in
                guard let matching = guild.threads?.filter({ $0.parent_id == channel.id }) else { return }
                threadFormatted.append(channel)
                threadFormatted.append(contentsOf: matching)
            }
            threadFormatted.insert(contentsOf: rejects, at: 0)
            guild.channels = threadFormatted
            self.guilds[index] = guild
        }
    }
    
    func assignReadStates() {
        guard let readState = self.read_state else { return }
        let stateDict = readState.entries.generateKeyMap()
        self.guilds.enumerated().forEach { index, guild in
            var guild = guild
            guard var channels = guild.channels else { return }
            channels = channels.map { (channel) -> Channel in
                var channel = channel
                var allowed: Bool = true
                for overwrite in channel.permission_overwrites ?? [] {
                    if let allowString = overwrite.allow,
                       let allow = Int(allowString),
                       (overwrite.id == user_id) ||
                        (guild.mergedMember?.roles.contains(overwrite.id ?? .init()) ?? false) {
                        let perms = Permissions.getValues(for: allow)
                        if perms.contains(.readMessages) {
                            channel.shown = true
                            return channel
                        }
                    }
                    if let denyString = overwrite.deny,
                       let deny = Int(denyString),
                       (overwrite.id == user_id) ||
                        (guild.mergedMember?.roles.contains(overwrite.id ?? .init()) ?? false) ||
                        overwrite.id == guild.id {
                        let perms = Permissions.getValues(for: deny)
                        if perms.contains(.readMessages) {
                            allowed = false
                        }
                    }
                }
                channel.shown = allowed
                return channel
            }
            for (index, channel) in channels.enumerated() {
                guard channel.type == .normal ||
                        channel.type == .dm ||
                        channel.type == .group_dm ||
                        channel.type == .guild_news ||
                        channel.type == .guild_private_thread ||
                        channel.type == .guild_private_thread else {
                            continue
                }
                guard let at = stateDict[channel.id] else {
                    continue
                }
                channels[index].read_state = readState.entries[at]
            }
            guild.channels = channels
            self.guilds[index] = guild
        }
        print("Binded to guild channels")
    }
}

