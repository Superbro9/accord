//
//  ServerListView.swift
//  Accord
//
//  Created by evelyn on 2021-06-18.
//

import Combine
import SwiftUI

public var roleColors: [String: (Int, Int)] = [:]
public var roleNames: [String: String] = [:]

struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

enum Emotes {
    public static var emotes: [String: [DiscordEmote]] = [:] {
        didSet {
            print(#function)
        }
    }
}

struct GuildHoverAnimation: ViewModifier {
     var color: Color = Color.accentColor.opacity(0.5)
     var hasIcon: Bool
     var frame: CGFloat = 45
    var selected: Bool
     @State var hovered: Bool = false
     func body(content: Content) -> some View {
         content
             .onHover(perform: { res in withAnimation(Animation.linear(duration: 0.1)) { hovered = res } })
             .frame(width: frame, height: frame)
             .background(!hasIcon && hovered ? self.color : Color.clear)
             .cornerRadius(hovered || selected ? 13.5 : 23.5)
     }
 }

func pingCount(guild: Guild) -> Int {
    let intArray = guild.channels!.compactMap { $0.read_state?.mention_count }
    return intArray.reduce(0, +)
}

func unreadMessages(guild: Guild) -> Bool {
    let array = guild.channels?
        .compactMap { $0.last_message_id == $0.read_state?.last_message_id }
        .contains(false)
    return array ?? false
}


struct ServerListView: View {
    
    // i feel bad about this but i need some way to use static vars
    public class UpdateView: ObservableObject {
        @Published var updater: Bool = false
        func updateView() {
            DispatchQueue.main.async {
                self.updater.toggle()
                self.objectWillChange.send()
            }
        }
    }
    
    @State var selection: Int?
    @State var selectedGuild: Guild?
    @State var selectedServer: Int? = 0
    public static var folders: [GuildFolder] = .init()
    public static var privateChannels: [Channel] = .init()
    public static var mergedMembers: [String:Guild.MergedMember] = .init()
    internal static var readStates: [ReadStateEntry] = .init()
    var statusText: String?
    @State var status: String?
    @State var timedOut: Bool = false
    @State var mentions: Bool = false
    @State var bag = Set<AnyCancellable>()
    @StateObject var viewUpdater = UpdateView()
    @State var iconHovered: Bool = false
    
    var dmButton: some View {
        Button(action: {
            selection = nil
            DispatchQueue.global().async {
                             wss?.cachedMemberRequest.removeAll()
                             ServerListView.privateChannels = ServerListView.privateChannels.sorted(by: { $0.last_message_id ?? "" > $1.last_message_id ?? "" })
                         }
                         selectedServer = 201
        }) {
            Image(systemName: "bubble.right.fill")
                             .imageScale(.medium)
                .frame(width: 45, height: 45)
                .foregroundColor(.white)
                .background(selectedServer == 201 ? Color.accentColor.opacity(0.5) : Color(UIColor.systemBackground))
                .cornerRadius(iconHovered || selectedServer == 201 ? 13.5 : 23.5)
                                 .if(selectedServer == 201, transform: { $0.foregroundColor(Color.white) })
                                    .onHover(perform: { h in withAnimation(Animation.linear(duration: 0.1)) { self.iconHovered = h } })
        }
    }
    
    var onlineButton: some View {
        Button("Offline") {
            AccordApp.error("Offline" as! Error, additionalDescription: "Check your network connection")
        }
    }
    
    @ViewBuilder
    var statusIndicator: some View {
        Circle()
                     .foregroundColor({ () -> Color in
                         switch self.status {
                         case "online":
                             return Color.green
                         case "idle":
                             return Color.orange
                         case "dnd":
                             return Color.red
                         case "offline":
                             return Color.gray
                         default:
                             return Color.clear
                         }
                     }())
                     .frame(width: 7, height: 7)
    }
    
    var settingsLink: some View {
        NavigationLink(destination: SettingsView(), tag: 0, selection: self.$selection) {
                    HStack {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: UIImage(data: avatar) ?? UIImage()).resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            statusIndicator
                        }
                        VStack(alignment: .leading) {
                            if let user = AccordCoreVars.user {
                                Text(user.username) + Text("#" + user.discriminator).foregroundColor(.secondary)
                                if let statusText = statusText {
                                    Text(statusText)
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                            }
                        }
            }
        }
        .buttonStyle(BorderlessButtonStyle())
    }
    
    var body: some View {
        return NavigationView {
            HStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    // MARK: - Messages button
                    LazyVStack {
                        if !NetworkCore.shared.connected {
                            onlineButton
                                .buttonStyle(BorderlessButtonStyle())
                        }
                        ZStack(alignment: .bottomTrailing) {
                            dmButton
                                .padding(.leading, 10)
                            if let count = Self.privateChannels.compactMap({ $0.read_state?.mention_count }).reduce(0, +), count != 0 {
                                ZStack {
                                    Circle()
                                        .foregroundColor(Color.red)
                                        .frame(width: 15, height: 15)
                                    Text(String(count))
                                        .foregroundColor(Color.white)
                                        .fontWeight(.semibold)
                                        .font(.caption)
                                }
                            }
                        }
                                        .buttonStyle(BorderlessButtonStyle())
                        Color.gray
                            .frame(height: 1)
                            .opacity(0.75)
                            .padding(.horizontal)
                        FolderListView(selectedServer: self.$selectedServer, selection: self.$selection, selectedGuild: self.$selectedGuild, updater: self.viewUpdater)
                            .padding(.trailing, 3.5)
                    }
                    .padding(.vertical)
                }
                .frame(width: 80)
                .padding(.top, 5)
                Divider()
                // MARK: - Loading UI
                if selectedServer == 201 {
                    List {
                        settingsLink
                        Divider()
                        ForEach(Self.privateChannels, id: \.id) { channel in
                            NavigationLink(destination: NavigationLazyView(ChannelView(channel).equatable()), tag: Int(channel.id) ?? 0, selection: self.$selection) {
                                ServerListViewCell(channel: channel, updater: self.viewUpdater)
                                    .onChange(of: self.selection, perform: { _ in
                                        if self.selection == Int(channel.id) {
                                            channel.read_state?.mention_count = 0
                                            channel.read_state?.last_message_id = channel.last_message_id
                                        }
                                    })
                                    .contextMenu {
                                        Button("Copy Channel ID") {
                                            UIPasteboard.general.items = []
                                            UIPasteboard.general.string = channel.id
                                        }
                                        Button("Close DM") {
                                            let headers = Headers(
                                                userAgent: discordUserAgent,
                                                contentType: nil,
                                                token: AccordCoreVars.token,
                                                type: .DELETE,
                                                discordHeaders: true,
                                                referer: "https://discord.com/channels/@me",
                                                empty: true
                                            )
                                            Request.ping(url: URL(string: "\(rootURL)/channels/\(channel.id)"), headers: headers)
                                            guard let index = ServerListView.privateChannels.generateKeyMap()[channel.id] else { return }
                                                                                 ServerListView.privateChannels.remove(at: index)
                                        }
                                        Button("Mark as read") {
                                            channel.read_state?.mention_count = 0
                                            channel.read_state?.last_message_id = channel.last_message_id
                                        
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.top, 5)
                    .listStyle(.sidebar)
                } else if let selectedGuild = selectedGuild {
                    GuildView(guild: selectedGuild, selection: self.$selection, updater: self.viewUpdater)
                        .animation(nil, value: UUID())
                }
            }
            .frame(minWidth: 300, maxWidth: 500, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.columns)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("Refresh")), perform: { pub in
            guard let uInfo = pub.userInfo as? [Int: Int],
                  let firstKey = uInfo.first else { return }
            self.selectedServer = firstKey.key
            self.selection = firstKey.value
            self.selectedGuild = Array(Self.folders.map(\.guilds).joined())[firstKey.key]
        })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DMSelect")), perform: { pub in
            guard let uInfo = pub.userInfo as? [String: String],
                  let index = uInfo["index"], let number = Int(index) else { return }
            self.selectedServer = 201
            self.selection = number
        })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("Updater")), perform: { pub in
            viewUpdater.updateView()
        })
        .onAppear {
            self.selectedGuild = ServerListView.folders.first?.guilds.first
                         DispatchQueue.global().async {
                if !Self.folders.isEmpty {
                    let val = UserDefaults.standard.integer(forKey: "AccordChannelIn\(Array(Self.folders.compactMap { $0.guilds }.joined())[0].id)")
                    DispatchQueue.main.async {
                        self.selection = (val != 0 ? val : nil)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if selection == nil {
                    Toggle(isOn: Binding.constant(false)) {
                        Image(systemName: "bell.badge.fill")
                    }
                    .hidden()
                }
            }
        }
    }
}
