//
//  Extensions.swift
//  Accord
//
//  Created by evelyn on 2021-06-07.
//

import UIKit
import Combine
import Foundation
import SwiftUI

// thanks osy
 extension String: Error {
     var localizedString: String { self }
 }

public var doNothing: (Any) -> Void = { _ in }

@propertyWrapper
public final class IgnoreFailure<Value: Decodable>: Decodable {
    public var wrappedValue: [Value] = []

    private struct _None: Decodable {}

    public required init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            do {
                let decoded = try container.decode(Value.self)
                wrappedValue.append(decoded)
            } catch let error {
                print("failed to decode", error)
                _ = try container.decode(_None.self)
            }
        }
    }
}

@propertyWrapper
struct DefaultEmptyArray<T: Decodable & ExpressibleByArrayLiteral> {
    var wrappedValue: T = .init()
}

extension DefaultEmptyArray: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = try container.decode(T.self)
    }
}

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ type: DefaultEmptyArray<T>.Type, forKey key: Key) throws -> DefaultEmptyArray<T> {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(int: Int) {
        let int = UInt64(int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

struct FolderIcon: View {
     var guild: Guild

     var body: some View {
         if let icon = guild.icon {
             Attachment(cdnURL + "/icons/\(guild.id)/\(icon).png?size=24")
                 .equatable()
                 .clipShape(Circle())
                 .frame(width: 16, height: 16)
         } else {
             if let name = guild.name {
                 Text(name.components(separatedBy: " ").compactMap(\.first).map(String.init).joined())
                     .equatable()
                     .frame(width: 16, height: 16)
             } else {
                 Image(systemName: "questionmark")
                     .equatable()
                     .frame(width: 16, height: 16)
             }
         }
     }
 }


struct Folder<Content: View>: View {
    var icon: [Guild]
    var color: Color
    @Binding var read: Bool
    var mentionCount: Int?
    var content: () -> Content

    @State private var collapsed: Bool = true

    let gridLayout: [GridItem] = GridItem.multiple(count: 2, spacing: 0)

    var body: some View {
        VStack {
            Button(
                action: { withAnimation(Animation.easeInOut(duration: 0.2)) { self.collapsed.toggle() } },
                label: {
                    HStack {
                        Circle()
                            .fill()
                            .foregroundColor(Color.primary)
                            .frame(width: 5, height: 5)
                            .opacity(read && collapsed ? 1 : 0)
                        if self.collapsed {
                            ZStack(alignment: .bottomTrailing) {
                                VStack(spacing: 3) {
                                    HStack(spacing: 3) {
                                        FolderIcon(guild: icon.first!)
                                        FolderIcon(guild: icon[safe: 1]!)
                                    }
                                    HStack(spacing: 3) {
                                        FolderIcon(guild: icon[safe: 2]!)
                                        FolderIcon(guild: icon[safe: 3]!)
                                    }
                                }
                                .frame(width: 45, height: 45)
                                .background(color.opacity(0.75))
                                .cornerRadius(15)
                                .frame(width: 45, height: 45)
                                .redBadge(collapsed ? .constant(mentionCount) : .constant(nil))
                            }
                        } else {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundColor(color.lighter().opacity(0.75))
                                .padding()
                                .frame(width: 45, height: 45)
                                .background(color.opacity(0.65).gradient)
                                .cornerRadius(15)
                                .frame(width: 45, height: 45)
                        }
                    }
                }
            )
            .buttonStyle(.plain)
            VStack {
                if !collapsed {
                    self.content()
                }
            }
        }
        .frame(width: 45)
    }
}

extension Color {
     func colorInvert() -> Self {
         let color = self.cgColor ?? .none
         let comp = color?.components ?? []
         return Color(red: 1.0 - comp[0], green: 1.0 - comp[1], blue: 1.0 - comp[2])
     }
    
    func lighter() -> Self {
        let color = self.cgColor ?? .none
        let comp = color?.components ?? []
        if let red = comp.first, let green = comp[safe: 1], let blue = comp[safe: 2] {
            return Color(red: max(1.0, red + 0.1), green: max(1.0, green + 0.1), blue: max(1.0, blue + 0.1))
        }
        return self
    }
}

func pronounDBFormed(pronoun: String?) -> String {
    switch pronoun {
    case "hh":
        return "he/him"
    case "hi":
        return "he/it"
    case "hs":
        return "he/she"
    case "ht":
        return "he/they"
    case "ih":
        return "it/him"
    case "ii":
        return "it/its"
    case "is":
        return "it/she"
    case "it":
        return "it/they"
    case "shh":
        return "she/he"
    case "sh":
        return "she/her"
    case "si":
        return "she/it"
    case "st":
        return "she/they"
    case "th":
        return "they/he"
    case "ti":
        return "they/it"
    case "ts":
        return "they/she"
    case "tt":
        return "they/them"
    case "any":
        return "any/any"
    default:
        return ""
    }
}

func pfpURL(_ uid: String?, _ hash: String?, discriminator: String = "0005", _ size: String = "64") -> String {
    if let uid = uid, let avatar = hash {
         return cdnURL + "/avatars/\(uid)/\(avatar).png?size=\(size)"
     } else {
         let index = String((Int(discriminator) ?? 0) % 5)
         return cdnURL + "/embed/avatars/\(index).png"
     }
}

func iconURL(_ id: String?, _ icon: String?, _ size: String = "96") -> String {
    guard let id = id, let icon = icon else { return cdnURL + "/embed/avatars/1.png" }
    return cdnURL + "/icons/\(id)/\(icon).png?size=\(size)"
}

public extension Collection {
    subscript(exist index: Index) -> Iterator.Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// prevent index out of range
public extension Collection where Index: BinaryInteger {
    subscript(safe index: Index) -> Iterator.Element? {
        indices.count > index ? self[index] : nil
    }
}

extension DispatchQueue {
    func asyncIf(_ condition: @autoclosure () -> Bool, _ perform: @escaping () -> Void) {
        if condition() {
            async {
                perform()
            }
        }
    }
}

extension UIApplication {
    var kernelVersion: String {
        var size = 0
        sysctlbyname("kern.osrelease", nil, &size, nil, 0)
        var vers = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osrelease", &vers, &size, nil, 0)
        return String(cString: vers)
    }
}


extension Data {
     mutating func append(_ string: String) {
         if let data = string.data(using: .utf8) {
             append(data)
         }
     }
 }

extension Date {
    func makeProperDate() -> String {
        return DateFormatter.localizedString(from: self, dateStyle: .medium, timeStyle: .short)
    }
    func makeProperHour() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm"
        return dateFormatter.string(from: self)
    }
}

func parseSnowflake(_ snowflake: String) -> Int64 {
     return ((Int64(snowflake) ?? 0) >> 22) + 1420070400000
 }
