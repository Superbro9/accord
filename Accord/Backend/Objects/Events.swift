//
//  Events.swift
//  Events
//
//  Created by Evelyn on 2021-08-16.
//

import Foundation

final class GuildMemberChunkResponse: Decodable {
    var t: String
    var d: GuildMemberChunk?
}

final class GuildMemberChunk: Decodable {
    var guild_id: String?
    var members: [GuildMember?]
    var presences: [Presence]?
}

final class Presence: Decodable {
    var user: User?
    var guild_id: String
    var status: UserStatus?
    // var activities
    //    client_status
}

enum UserStatus: String, Decodable {
    case online = "online"
    case dnd = "dnd"
    case idle = "idle"
    case offline = "offline"
}

final class TypingEvent: Decodable {
    var channel_id: String
    var guild_id: String?
    var member: GuildMember?
}

final class GuildMember: Decodable {
    var user: User
    var nick: String?
    var roles: [String]?
}

final class GatewayMessage: Decodable {
    var d: Message?
}


final class GatewayDeletedMessage: Decodable {
    var d: DeletedMessage?
}

final class DeletedMessage: Decodable {
    var id: String
}