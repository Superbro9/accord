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

public final class Markdown {
    
    private init () {}
    
    
    enum MarkdownErrors: Error {
        case unsupported // For the new Markdown Parser, which is unavailable on Big Sur
    }

    public typealias TextPublisher = AnyPublisher<Text, Error>
    public typealias TextArrayPublisher = AnyPublisher<[Text], Error>

    // Publisher that sends a SwiftUI Text view with a newline
    public static var newLinePublisher: TextArrayPublisher = Just<[Text]>.init([Text("\n")]).setFailureType(to: Error.self).eraseToAnyPublisher()
    fileprivate static let blankCharacter = "‎" // Not an empty string
    
    class func appleMarkdown(_ text: String) -> Text {
             do {
                 if #available(iOS 15, *) {
                     let markdown = try AttributedString(markdown: text)
                     return Text(markdown) + Text(" ")
                 } else { throw MarkdownErrors.unsupported }
             } catch {
                 return Text(text) + Text(" ")
             }
         }

    /***
     
     Overengineered processing for Markdown using Combine


                        +------------------------------+
                        |  Call the Markdown.markAll   |
        +---------------|  function and subscribe to   |
        |               |  the publisher               |
        |               +------------------------------+
        |                               |
     Combine the final                  |                     \*.+\*|~~.+~~|`{1,3}.+`{1,3}|([^*~\s]+)+
     result in AnyPublisher             |                                         |
        |                               |                                         |
        |                       Split text by `\n`                                |
        |                               |                        +----Split text with custom regex---+
        |                               |                        |                                   |
        |                               |                        |                                   |
     +-------------------------------+  |        +------------------------------+                    |
     |  Collect the markLine         |  |--------| Call the Markdown.markLine   |                    |
     |  publishers and combine them  |           | function for each split line |                    |
     |  with `\n`                    |           +------------------------------+                    |
     +-------------------------------+                                                               |
                         |                                                                           |
                         |                     +---------------------------------+      +-------------------------------+
                         |                     | Collect the markWord publishers |      |  Call the Markdown.markWord   |
                         +---------------------| and combine them using          |------|  function for each component  |
                                               | reduce(Text(""), +)             |      +-------------------------------+
                                               +---------------------------------+


     ***/
    
    /**
     markWord: Simple Publisher that sends a text view with the processed word
     - Parameter word: The String being processed
     - Parameter members: Dictionary of channel members from which we get the mentions
     - Returns AnyPublisher with SwiftUI Text view
     **/
    public class func markWord(_ word: String, _ members: [String: String] = [:], font: Bool) -> TextPublisher {
        let emoteIDs = word.matches(precomputed: RegexExpressions.emojiIDRegex)
        if let id = emoteIDs.first, let emoteURL = URL(string: cdnURL + "/emojis/\(id).png?size=24") {
            return RequestPublisher.image(url: emoteURL)
                .replaceError(with: UIImage(systemName: "wifi.slash") ?? UIImage())
                .map { image -> UIImage in
                    guard !font else { return image }
                    var size = CGSize(width: 18, height: 18)
                    image.size
                    return image
                }
                .map {
                    Text(Image(uiImage: $0)).font(.system(size: 14)) + Text(" ")
                }
                .eraseToAny()
        }
        return Future { promise -> Void in
            let mentions = word.matches(precomputed: RegexExpressions.mentionsRegex)
            let channels = word.matches(precomputed: RegexExpressions.channelsRegex)
            let songIDs = word.matches(precomputed: RegexExpressions.songIDsRegex)
            let platforms = word.matches(precomputed: RegexExpressions.platformsRegex)
                .replaceAllOccurences(of: "music.apple", with: "applemusic")
            let dict = Array(arrayLiteral: zip(songIDs, platforms))
                .reduce([], +)
            for (id, platform) in dict {
                SongLink.getSong(song: "\(platform):track:\(id)") { song in
                    guard let song = song else { return }
                    switch musicPlatform {
                    case .appleMusic:
                        return promise(.success(appleMarkdown(song.linksByPlatform.appleMusic.url)))
                    case .spotify:
                        return promise(.success(appleMarkdown(song.linksByPlatform.spotify.url)))
                    case .none:
                        return promise(.success(appleMarkdown(word)))
                    default: break
                    }
                }
            }
            guard dict.isEmpty else { return }
            for id in mentions {
                return promise(.success(
                    Text("@\(members[id] ?? "Unknown User")")
                        .foregroundColor(id == user_id ? Color.init(Color.RGBColorSpace.sRGB, red: 1, green: 0.843, blue: 0, opacity: 1) : Color(UIColor.gray))
                        .underline()
                    +
                    Text(" ")
                ))
            }
            for id in channels {
                let channel = Array(ServerListView.folders.map({ $0.guilds }).joined().map(\.channels).joined())[keyed: id]
                return promise(.success(Text("#\(channel?.name ?? "deleted-channel") ").foregroundColor(Color(UIColor.systemGray)) + Text(" ")))
            }
            if word.contains("+") || word.contains("<") || word.contains(">") { // the markdown parser removes these??
                return promise(.success(Text(word) + Text(" ")))
            }
            return promise(.success(appleMarkdown(word)))
        }
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
        let words = line.matchRange(precomputed: RegexExpressions.lineRegex).map { line[$0].trimmingCharacters(in: .whitespaces) }
        let pubs: [AnyPublisher<Text, Error>] = words.map { markWord($0, members, font: font) }
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
        let codeBlockMarkerRawOffsets = newlines
            .lazy
            .enumerated()
            .filter { $0.element.prefix(3) == "```" }
            .map(\.offset)
        
        let indexes = codeBlockMarkerRawOffsets
            .lazy
            .indices
            .filter { $0 % 2 == 0 }
            .map { number -> (Int, Int)? in
                if !codeBlockMarkerRawOffsets.indices.contains(number + 1) { return nil }
                return (codeBlockMarkerRawOffsets[number], codeBlockMarkerRawOffsets[number + 1])
            }
            .compactMap(\.self)
        
        let pubs = newlines.map { markLine(String($0), members, font: font) }
        var strippedPublishers = pubs
            .map { [$0] }
            .joined()
            .arrayLiteral
        
        indexes.forEach { lowerBound, upperBound in
            (lowerBound...upperBound).forEach { line in
                let textObject: Text = Text(newlines[line]).font(Font.system(size: 14, design: .monospaced))
                strippedPublishers[line] = Just([textObject]).eraseToAny()
            }
        }
        let deleteIndexes = indexes
            .map { [$0, $1] }
            .joined()
        
        strippedPublishers.remove(atOffsets: IndexSet(deleteIndexes))
        
        let arrayWithNewlines = strippedPublishers
            .map { Array([$0]) }
            .joined(separator: [
                newLinePublisher
            ])
        
        return Publishers.MergeMany(Array(arrayWithNewlines))
            .map { $0.reduce(Text(""), +) }
            .mapError { $0 as Error }
            .collect()
            .map { $0.reduce(Text(""), +) }
            .eraseToAnyPublisher()
    }
}

extension Array where Element == String {
    func replaceAllOccurences(of original: String, with string: String) -> [String] {
        map { $0.replacingOccurrences(of: original, with: string) }
    }
}
