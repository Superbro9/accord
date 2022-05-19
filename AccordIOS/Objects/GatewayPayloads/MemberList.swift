//
//  MemberList.swift
//  Accord
//
//  Created by evelyn on 2021-11-28.
//

import Foundation

final class MemberListUpdate: Decodable {
    var d: MemberList
}

final class MemberList: Decodable {
    var ops: [ListOPS]
}

final class ListOPS: Decodable {
    var items: [OPSItems]?
}

final class OPSGroup: Codable {
     var count: Int?
     var id: String?
 }

final class OPSItems: Codable {
    var member: GuildMember?
    var group: OPSGroup?
    
    public var id: String {
        if let member = member {
            return member.user.id
        } else {
            return group!.id ?? ""
        }
    }
}
