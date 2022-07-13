//
//  RegexExpressions.swift
//  Accord
//
//  Created by evelyn on 2022-03-07.
//

import Foundation

enum RegexExpressions {
    static func precompute() {
        _ = (
            fullEmojiRegex,
            emojiIDRegex,
            songIDsRegex,
            mentionsRegex,
            platformsRegex,
            channelsRegex,
            lineRegex,
            chatTextMentionsRegex,
            chatTextChannelsRegex,
            chatTextSlashCommandRegex,
            chatTextEmojiRegex,
            completedEmoteRegex
        )
    }

    static var fullEmojiRegex = try? NSRegularExpression(pattern: RegexLiterals.fullEmojiRegex.rawValue)
    static var emojiIDRegex = try? NSRegularExpression(pattern: RegexLiterals.emojiIDRegex.rawValue)
    static var songIDsRegex = try? NSRegularExpression(pattern: RegexLiterals.songIDsRegex.rawValue)
    static var mentionsRegex = try? NSRegularExpression(pattern: RegexLiterals.mentionsRegex.rawValue)
    static var platformsRegex = try? NSRegularExpression(pattern: RegexLiterals.platformsRegex.rawValue)
    static var channelsRegex = try? NSRegularExpression(pattern: RegexLiterals.channelsRegex.rawValue)
    static var lineRegex = try? NSRegularExpression(pattern: RegexLiterals.lineRegex.rawValue)
    static var chatTextMentionsRegex = try? NSRegularExpression(pattern: RegexLiterals.chatTextMentionsRegex.rawValue)
    static var chatTextChannelsRegex = try? NSRegularExpression(pattern: RegexLiterals.chatTextChannelsRegex.rawValue)
    static var chatTextSlashCommandRegex = try? NSRegularExpression(pattern: RegexLiterals.chatTextSlashCommandRegex.rawValue)
    static var chatTextEmojiRegex = try? NSRegularExpression(pattern: RegexLiterals.chatTextEmojiRegex.rawValue)
    static var completedEmoteRegex = try? NSRegularExpression(pattern: RegexLiterals.completedEmoteRegex.rawValue)
}

enum RegexLiterals: String, RawRepresentable {
    case fullEmojiRegex = #"<:\w+:[0-9]+>"#
    case emojiIDRegex = #"(?<=\:)(\d+)(.*?)(?=\>)"#
    case songIDsRegex = #"(?<=https:\/\/open\.spotify\.com\/track\/|https:\/\/music\.apple\.com\/[a-z][a-z]\/album\/[a-zA-Z\d%\(\)-]{1,100}\/|https://tidal\.com/browse/track/)(?:(?!\?).)*"#
    case mentionsRegex = #"(?<=\@|@!)(\d+)(.*?)(?=\>)"#
    case platformsRegex = #"(spotify|music\.apple|tidal)"#
    case channelsRegex = ##"(?<=\#)(\d+)(.+?)(?=\>)"##
    case lineRegex = #"\*.+\*|~~.+~~|`{1,3}.+`{1,3}|([^*~\s]+)+"#
    case chatTextMentionsRegex = #"(?<=@)(?:(?!\ ).)*"#
    case chatTextChannelsRegex = #"(?<=#)(?:(?!\ ).)*"#
    case chatTextSlashCommandRegex = #"(?<=\/)(?:(?!\ ).)*"#
    case chatTextEmojiRegex = #"(?<=:).*"#
    case completedEmoteRegex = "(?<!<|<a):.+:"
}
