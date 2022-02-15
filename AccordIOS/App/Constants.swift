//
//  DiscordCoreVars.swift
//  Accord
//
//  Created by evelyn on 2020-11-27.
//

import Combine
import Foundation
import os
import SwiftUI

// Discord WebSocket
var wss: Gateway!

public let rootURL: String = "https://discord.com/api/v10"
public let cdnURL: String = "https://cdn.discordapp.com"
public var user_id: String = ""
public var avatar: Data = .init()
public var pfpShown: Bool = UserDefaults.standard.bool(forKey: "pfpShown")
public var sortByMostRecent: Bool = UserDefaults.standard.bool(forKey: "sortByMostRecent")
public var darkMode: Bool = UserDefaults.standard.bool(forKey: "darkMode")
public var username: String = ""
public var discriminator: String = ""
public var proxyIP: String? = UserDefaults.standard.string(forKey: "proxyIP")
public var proxyPort: String? = UserDefaults.standard.string(forKey: "proxyPort")
public var proxyEnabled: Bool = UserDefaults.standard.bool(forKey: "proxyEnabled")
public var pastelColors: Bool = UserDefaults.standard.bool(forKey: "pastelColors")
public var discordStockSettings: Bool = UserDefaults.standard.bool(forKey: "discordStockSettings")
public var musicPlatform: Platforms? = Platforms(rawValue: UserDefaults.standard.string(forKey: "musicPlatform") ?? "")
public let discordUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) discord/0.0.264 Chrome/91.0.4472.164 Electron/13.4.0 Safari/537.36"
public var dscVersion = 113_404
public var DiscordDesktopRPCEnabled = UserDefaults.standard.bool(forKey: "DiscordDesktopRPCEnabled")

public let xcodeRPCAppID = "926282502937641001"
public let musicRPCAppID = "925514277987704842"
public let discordDesktopRPCAppID = "928798784174051399"
public let vsCodeRPCAppID = "928861386140971078"

#if DEBUG
    public let keychainItemName = "com.superbro.AccordIOS"
#else
    public let keychainItemName = "com.superbro.AccordIOS"
#endif

enum Storage {
    static var usernames: [String: String] = [:]
}

final class AccordCoreVars {
    static var cancellable: Cancellable?

    static var suffixes: Bool = UserDefaults.standard.bool(forKey: "enableSuffixRemover")
    static var pronounDB: Bool = UserDefaults.standard.bool(forKey: "pronounDB")
    public static var token: String = .init(decoding: UserDefaults.standard.data(forKey: "tokenKeyUserDefault") ?? Data(), as: UTF8.self)
    
    //KeychainManager.load(key: keychainItemName) ?? Data(), as: UTF8.self)
        
    public static var user: User?

    class func loadVersion() {
        concurrentQueue.async {
            Self.cancellable = RequestPublisher.fetch(Res.self, url: URL(string: "https://api.discord.sale"))
                .sink(receiveCompletion: { _ in
                }) { res in
                    print(dscVersion)
                    dscVersion = res.statistics.newest_build.number
                    UserDefaults.standard.set(dscVersion, forKey: "clientVersion")
                    print(dscVersion)
                }
        }
    }
}

class Res: Decodable {
    var statistics: Response
    class Response: Decodable {
        class Build: Decodable {
            var number: Int
        }

        var newest_build: Build
    }
}

#if DEBUG
    let rw = (
        dso: { () -> UnsafeMutableRawPointer in
            var info = Dl_info()
            dladdr(dlsym(dlopen(nil, RTLD_LAZY), "LocalizedString"), &info)
            return info.dli_fbase
        }(),
        log: OSLog(subsystem: "com.apple.runtime-issues", category: "Accord")
    )
#endif
