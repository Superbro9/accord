//
//  SettingsViewRedesign.swift
//  Accord
//
//  Created by evewyn on 2021-07-14.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    
    
    @AppStorage("MusicPlatform")
    var selectedPlatform: String = "appleMusic"
    
    
    @State var user: User? = AccordCoreVars.user
    @State var loading: Bool = false
    @State var bioText: String = " "
    @State var username: String = AccordCoreVars.user?.username ?? "Unknown User"
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        List {
            LazyVStack(alignment: .leading) {
                Section {
                    Group {
                        SettingsToggleView(key: "pfpShown", title: "Show profile pictures")
                        SettingsToggleView(key: "discordStockSettings", title: "Use stock discord settings")
                        SettingsToggleView(key: "sortByMostRecent", title: "Sort servers by recent messages")
                        SettingsToggleView(key: "enableSuffixRemover", title: "Enable useless suffix remover")
                    }
                    .disabled(true)
                    Group {
                        SettingsToggleView(key: "pronounDB", title: "Enable PronounDB integration")
                        SettingsToggleView(key: "darkMode", title: "Always dark mode")
                        SettingsToggleView(key: "MentionsMenuBarItemEnabled", title: "Enable the mentions menu bar popup")
                        SettingsToggleView(key: "Nitroless", title: "Enable Nitroless support")
                        SettingsToggleView(key: "SilentTyping", title: "Enable silent typing")
                        SettingsToggleView(key: "MetalRenderer", title: "Enable the Metal Renderer for the chat view", detail: "Experimental")
                        SettingsToggleView(key: "GifProfilePictures", title: "Enable Gif Profile Pictures", detail: "Experimental")
                        SettingsToggleView(key: "ShowHiddenChannels", title: "Show hidden channels", detail: "Please don't use this")
                        SettingsToggleView(key: "CompressGateway", title: "Enable Gateway Stream Compression", detail: "Recommended", defaultToggle: true)
                    }

                    
                    HStack(alignment: .top) {
                        Text("Music platform")
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding()
                        Spacer()
                        Menu("Select your platform") {
                            Button("Amazon Music", action: { self.selectedPlatform = Platforms.amazonMusic.rawValue })
                            Button("Apple Music", action: { self.selectedPlatform = Platforms.appleMusic.rawValue })
                            Button("Deezer", action: { self.selectedPlatform = Platforms.deezer.rawValue })
                            Button("iTunes", action: { self.selectedPlatform = Platforms.itunes.rawValue })
                            Button("Napster", action: { self.selectedPlatform = Platforms.napster.rawValue })
                            Button("Pandora", action: { self.selectedPlatform = Platforms.pandora.rawValue })
                            Button("Soundcloud", action: { self.selectedPlatform = Platforms.soundcloud.rawValue })
                            Button("Spotify", action: { self.selectedPlatform = Platforms.spotify.rawValue })
                            Button("Tidal", action: { self.selectedPlatform = Platforms.tidal.rawValue })
                            Button("Youtube Music", action: { self.selectedPlatform = Platforms.youtubeMusic.rawValue })
                        }
                        .padding()
                    }
                }
                .toggleStyle(SwitchToggleStyle())
                .padding(5)
                .background(Color.black.opacity(colorScheme == .dark ? 0.25 : 0.10))
                .cornerRadius(15)
                .padding()
                   Button {
                       logOut()
                   } label: {
                       Text("Log Out")
                   }
                   .padding(.leading, 20)
                   .foregroundColor(.secondary)
                Spacer()
                
                Text("AccordiOS (com.superbro.AccordIOS) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .padding(.leading, 20)
                    .foregroundColor(.secondary)
                Text("OS: iOS \(String(describing: ProcessInfo.processInfo.operatingSystemVersionString))")
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
                            UIApplication.shared.open(URL(string: "https://github.com/Superbro9/accord")!)
                        }
                }
                .frame(height: 5)
                Text("Made with 🤍 by Superbro")
                    .padding(.leading, 20)
                    .foregroundColor(.secondary)
            }
            .toolbar {
                ToolbarItemGroup {
                    Toggle(isOn: Binding.constant(false)) {
                        Image(systemName: "bell.badge.fill")
                    }
                    .hidden()
                }
            }
            
        }
    }
}

extension FileManager {
    public func secureCopyItem(at srcURL: URL, to dstURL: URL) -> Bool {
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
    var key: String
    var title: String
    var detail: String?
    var defaultToggle: Bool?
    @State var toggled: Bool = false
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
                .onChange(of: self.toggled, perform: { _ in
                    UserDefaults.standard.set(self.toggled, forKey: key)
                })
                .padding()
                .onAppear {
                    self.toggled = UserDefaults.standard.object(forKey: self.key) as? Bool ?? defaultToggle ?? false
                }
        }
    }
}
