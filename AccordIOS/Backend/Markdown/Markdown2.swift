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
        let emoteIDs = word.matches(precomputed: Regex.emojiIDRegex)
        if let id = emoteIDs.first, let emoteURL = URL(string: cdnURL + "/emojis/\(id).png?size=16") {
            return RequestPublisher.image(url: emoteURL)
                .replaceError(with: UIImage(systemName: "wifi.slash") ?? UIImage())
                .map { Text("\(Image(uiImage: $0))") + Text(" ") }
                .eraseToAny()
        }
        let inlineImages = word.matches(precomputed: Regex.inlineImageRegex).filter { $0.contains("nitroless") || $0.contains("emote") || $0.contains("emoji") } // nitroless emoji
        if let url = inlineImages.first, let emoteURL = URL(string: url) {
            return RequestPublisher.image(url: emoteURL)
                .replaceError(with: UIImage(systemName: "wifi.slash") ?? UIImage())
                .map { Text("\(Image(uiImage: $0))") + Text(" ") }
                .eraseToAny()
        }
        return Future { promise in
            let mentions = word.matches(precomputed: Regex.mentionsRegex)
            let channels = word.matches(precomputed: Regex.channelsRegex)
            let songIDs = word.matches(precomputed: Regex.songIDsRegex)
            let platforms = word.matches(precomputed: Regex.platformsRegex)
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
                return promise(.success(
                    Text("@\(members[id] ?? "Unknown User")")
                        .foregroundColor(id == user_id ? Color.init(Color.RGBColorSpace.sRGB, red: 1, green: 0.843, blue: 0, opacity: 1) : Color(UIColor.white))
                        .underline()
                    +
                    Text(" ")
                ))
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
    public class func markLine(_ line: String, _ members: [String: String] = [:], font: Bool) -> TextArrayPublisher {
        let line = line.replacingOccurrences(of: "](", with: "]\(blankCharacter)(") // disable link shortening forcefully
        let words = line.matchRange(precomputed: Regex.lineRegex).map { line[$0].trimmingCharacters(in: .whitespaces) }
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
    public class func markAll(text: String, _ members: [String: String] = [:], font: Bool = false) -> TextPublisher {
        let newlines = text.split(whereSeparator: \.isNewline)
        let pubs = newlines.map { markLine(String($0), members, font: font) }
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

private extension UIFont {
    var bold: UIFont {
        let font = UIFont.boldSystemFont(ofSize: 12)
        return font
    }

    var italic: UIFont {
        let font = UIFont.systemFont(ofSize: 12)
        let descriptor = font.fontDescriptor.withSymbolicTraits([.traitItalic])
        return UIFont(descriptor: descriptor!, size: UIFont.systemFontSize)
    }

    var boldItalic: UIFont {
        let font = UIFont.boldSystemFont(ofSize: 12)
        return font
    }
}

