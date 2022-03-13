//
//  Markdown2.swift
//  AccordIOS
//
//  Created by Hugo Mason on 08/02/2022.
//

import UIKit
import Combine
import Foundation
import SwiftUI

extension String {
    func matches(for regex: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: regex)
        let results = regex?.matches(in: self, range: NSRange(startIndex..., in: self))
        guard let mapped = results?.compactMap({ result -> String? in
            if let range = Range(result.range, in: self) {
                return String(self[range])
            } else {
                return nil
            }
        }) else {
            return []
        }
        return mapped
    }

    func matchRange(for regex: String) -> [Range<String.Index>] {
        let regex = try? NSRegularExpression(pattern: regex)
        let results = regex?.matches(in: self, range: NSRange(startIndex..., in: self))
        guard let mapped = results?.compactMap({ Range($0.range, in: self) }) else {
            return []
        }
        return mapped
    }

    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = startIndex
        while startIndex < endIndex,
              let range = self[startIndex...].range(of: string, options: options)
        {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

extension Array where Element == String {
    @inlinable func replaceAllOccurences(of original: String, with string: String) -> [String] {
        map { $0.replacingOccurrences(of: original, with: string) }
    }
}

public final class Markdown {
    enum MarkdownErrors: Error {
        case unsupported // For the new Markdown Parser, which is unavailable on Big Sur
    }

    public typealias TextPublisher = AnyPublisher<Text, Error>
    public typealias TextArrayPublisher = AnyPublisher<[Text], Error>

    // Publisher that sends a SwiftUI Text view with a newline
    public static var newLinePublisher: TextArrayPublisher = Just<[Text]>.init([Text("\n")]).setFailureType(to: Error.self).eraseToAnyPublisher()
    fileprivate static let blankCharacter = "‎" // Not an empty string

    /**
     markWord: Simple Publisher that sends a text view with the processed word
     - Parameter word: The String being processed
     - Parameter members: Dictionary of channel members from which we get the mentions
     - Returns AnyPublisher with SwiftUI Text view
     **/
    public class func markWord(_ word: String, _ members: [String: String] = [:]) -> TextPublisher {
        let emoteIDs = word.matches(for: #"(?<=\:)(\d+)(.*?)(?=\>)"#)
        if let id = emoteIDs.first, let emoteURL = URL(string: cdnURL + "/emojis/\(id).png?size=16") {
            return RequestPublisher.image(url: emoteURL)
                .replaceError(with: UIImage(systemName: "wifi.slash") ?? UIImage())
                .map { Text("\(Image(uiImage: $0))") + Text(" ") }
                .eraseToAny()
        }
        let inlineImages = word.matches(for: #"(?:([^:\/?#]+):)?(?:\/\/([^\/?#]*))?([^?#]*\.(?:jpg|gif|png))(?:\?([^#]*))?(?:#(.*))?"#).filter { $0.contains("nitroless") || $0.contains("emote") || $0.contains("emoji") } // nitroless emoji
        if let url = inlineImages.first, let emoteURL = URL(string: url) {
            return RequestPublisher.image(url: emoteURL)
                .replaceError(with: UIImage(systemName: "wifi.slash") ?? UIImage())
                .map { Text("\(Image(uiImage: $0))") + Text(" ") }
                .eraseToAny()
        }
        return Future { promise in
            let mentions = word.matches(for: #"(?<=\@|@!)(\d+)(.*?)(?=\>)"#)
            let channels = word.matches(for: ##"(?<=\#)(\d+)(.+?)(?=\>)"##)
            let songIDs = word.matches(for: #"(?<=https:\/\/open\.spotify\.com\/track\/|https:\/\/music\.apple\.com\/[a-z][a-z]\/album\/[a-zA-Z\d%\(\)-]{1,100}\/|https://tidal\.com/browse/track/)(?:(?!\?).)*"#)
            let platforms = word.matches(for: #"(spotify|music\.apple|tidal)"#)
                .replaceAllOccurences(of: "music.apple", with: "applemusic")
            let dict = Array(arrayLiteral: zip(songIDs, platforms))
                .reduce([], +)
            for (id, platform) in dict {
                SongLink.getSong(song: "\(platform):track:\(id)") { song in
                    guard let song = song else { return }
                    switch musicPlatform {
                    case .appleMusic:
                        return promise(.success(Text(song.linksByPlatform.appleMusic.url).foregroundColor(Color.blue).underline() + Text(" ")))
                    case .spotify:
                        return promise(.success(Text(song.linksByPlatform.spotify?.url ?? word).foregroundColor(Color.blue).underline() + Text(" ")))
                    case .none:
                        return promise(.success(Text(word) + Text(" ")))
                    default: break
                    }
                }
            }
            for id in mentions {
                return promise(.success(Text("@\(members[id] ?? "Unknown User")").foregroundColor(id == user_id ? Color.yellow : Color(UIColor.gray)).underline() + Text(" ")))
            }
            for id in channels {
                let matches = ServerListView.folders.map { $0.guilds.compactMap { $0.channels?.filter { $0.id == id } } }
                let joined: Channel? = Array(Array(Array(matches).joined()).joined()).first
                return promise(.success(Text("#\(joined?.name ?? "deleted-channel") ").foregroundColor(Color(UIColor.gray)).underline() + Text(" ")))
            }
            if word.contains("+") || word.contains("<") || word.contains(">") { // the markdown parser removes these??
                return promise(.success(Text(word) + Text(" ")))
            }
            do {
                if #available(iOS 15.0, *) {
                    let markdown = try AttributedString(markdown: word)
                    return promise(.success(Text(markdown) + Text(" ")))
                } else { throw MarkdownErrors.unsupported }
            } catch {
                return promise(.success(Text(word) + Text(" ")))
            }
        }
        .debugWarnNoMainThread()
        .eraseToAnyPublisher()
    }

    /**
     markLine: Simple Publisher that combines an array of word publishers for a split line
     - Parameter line: The line being processed
     - Parameter members: Dictionary of channel members from which we get the mentions
     - Returns AnyPublisher with array of SwiftUI Text views
     **/
    public class func markLine(_ line: String, _ members: [String: String] = [:]) -> TextArrayPublisher {
        let line = line.replacingOccurrences(of: "](", with: "]\(blankCharacter)(") // disable link shortening forcefully
        let regex = #"\*.+\*|~~.+~~|`{1,3}.+`{1,3}|([^*~\s]+)+"#
        let words = line.ranges(of: regex, options: .regularExpression).map { line[$0].trimmingCharacters(in: .whitespaces) }
        let pubs: [AnyPublisher<Text, Error>] = words.map { markWord($0, members) }
        return Publishers.MergeMany(pubs)
            .collect()
            .eraseToAnyPublisher()
    }

    /**
     markLine: Simple Publisher that combines an array of word and line publishers for a text section
     - Parameter text: The text being processed
     - Parameter members: Dictionary of channel members from which we get the mentions
     - Returns AnyPublisher with SwiftUI Text view
     **/
    public class func markAll(text: String, _ members: [String: String] = [:]) -> TextPublisher {
        let newlines = text.split(whereSeparator: \.isNewline)
        let pubs = newlines.map { markLine(String($0), members) }
        let withNewlines: [TextArrayPublisher] = Array(pubs.map { [$0] }.joined(separator: [newLinePublisher]))
        return Publishers.MergeMany(withNewlines)
            .map { $0.reduce(Text(""), +) }
            .mapError { $0 as Error }
            .collect()
            .map { $0.reduce(Text(""), +) }
            .eraseToAnyPublisher()
            .debugWarnNoMainThread()
    }
}

