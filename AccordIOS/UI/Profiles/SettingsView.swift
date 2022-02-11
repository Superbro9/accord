//
//  SettingsViewRedesign.swift
//  Accord
//
//  Created by evewyn on 2021-07-14.
//

import Foundation
import SwiftUI

struct SettingsViewRedesign: View {
    
    @AppStorage("pfpShown")
    var profilePictures: Bool = pfpShown
    @AppStorage("sortByMostRecent")
    var recent: Bool = sortByMostRecent
    @AppStorage("darkMode")
    var dark: Bool = darkMode
    @AppStorage("proxyIP")
    var proxyIP: String = ""
    @AppStorage("proxyPort")
    var proxyPort: String = ""
    @AppStorage("proxyEnabled")
    var proxyEnable: Bool = proxyEnabled
    @AppStorage("pastelColors")
    var pastel: Bool = pastelColors
    @AppStorage("discordStockSettings")
    var discordSettings: Bool = pastelColors
    @AppStorage("enableSuffixRemover")
    var suffixes: Bool = false
    @AppStorage("pronounDB")
    var pronounDB: Bool = false
    @AppStorage("AppleMusicRPC")
    var appleMusicRPC: Bool = false
    @AppStorage("XcodeRPC")
    var xcodeRPC: Bool = false
    @AppStorage("DiscordDesktopRPCEnabled")
    var ddRPC: Bool = false
    @AppStorage("VSCodeRPCEnabled")
    var vsRPC: Bool = false
    @AppStorage("MentionsMenuBarItemEnabled")
    var menuBarItem: Bool = false
    @AppStorage("MetalRenderer")
    var metalRenderer: Bool = false
    @AppStorage("Nitroless")
    var nitrolessEnabled: Bool = false
    @AppStorage("SilentTyping")
    var silentTyping: Bool = false
    @AppStorage("GifProfilePictures")
         var gifPfp: Bool = false
    @AppStorage("MusicPlatform")
    var selectedPlatform: Platforms = Platforms.appleMusic
    
    @State var user: User? = AccordCoreVars.user
    @State var loading: Bool = false
    @State var bioText: String = " "
    @State var username: String = AccordCoreVars.user?.username ?? "Unknown User"
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        List {
            LazyVStack(alignment: .leading) {
                Text("Accord Settings")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.leading, 20)
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Text("Email")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(user?.email ?? "No email found")
                        }
                        .padding(.bottom, 10)
                        VStack(alignment: .leading) {
                            Text("Phone number")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("not done yet, placeholder")
                        }
                        .padding(.bottom, 10)
                        Spacer()
                    }
                    .padding()
                    Divider()
                    VStack(alignment: .leading) {
                        Text("Bio")
                            .font(.title3)
                            .fontWeight(.bold)
                        TextEditor(text: $bioText)
                            .frame(height: 75)
                        Text("Username")
                            .font(.title3)
                            .fontWeight(.bold)
                        TextField("username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Spacer()
                    }
                    .frame(idealWidth: 250, idealHeight: 200)
                    .padding()
                    Divider()
                    VStack(alignment: .leading) {
                        Attachment("https://cdn.discordapp.com/avatars/\(user?.id ?? "")/\(user?.avatar ?? "").png")
                            .clipShape(Circle())
                            .frame(width: 45, height: 45)
                            .shadow(radius: 5)
                        Text(user?.username ?? "Unknown User")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(user?.username ?? "Unknown User")#\(user?.discriminator ?? "0000")")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                        Divider()
                        Text(bioText)
                        Spacer()
                    }
                    .frame(idealWidth: 200, idealHeight: 200)
                    .padding()
                    Spacer()
                }
                .padding(5)
                .background(Color.black.opacity(colorScheme == .dark ? 0.25 : 0.10))
                .cornerRadius(15)
                .padding()
                .disabled(true)
                
                Text("Accord (red.evelyn.accord) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .padding(.leading, 20)
                    .foregroundColor(.secondary)
                Text("OS: macOS \(String(describing: ProcessInfo.processInfo.operatingSystemVersionString))")
                    .padding(.leading, 20)
                    .foregroundColor(.secondary)
                HStack(alignment: .center) {
                    Text("Open source at")
                        .padding(.leading, 20)
                        .foregroundColor(.secondary)
                    GithubIcon()
                        .foregroundColor(Color.accentColor)
                        .frame(width: 13, height: 13)
                        .onTapGesture {
                            UIApplication.shared.open(URL(string: "https://github.com/evelyneee/Accord")!)
                        }
                }
                .frame(height: 5)
                Text("Made with 🤍 by Evelyn")
                    .padding(.leading, 20)
                    .foregroundColor(.secondary)
            }
            .onDisappear {
                darkMode = dark
                sortByMostRecent = recent
                pfpShown = profilePictures
                pastelColors = pastel
                discordStockSettings = discordSettings
            }
        }
    }
}

extension FileManager {
    open func secureCopyItem(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return false
        }
        return true
    }
}

struct SettingsToggleView: View {
    @Binding var toggled: Bool
    var title: String
    var detail: String?
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                if let detail = detail {
                    Text(detail)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            Spacer()
            Toggle(isOn: $toggled) {}
                .padding()
        }
    }
}
