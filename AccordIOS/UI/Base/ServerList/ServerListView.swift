//
//  ServerListView.swift
//  Accord
//
//  Created by evelyn on 2021-06-18.
//

import Combine
import SwiftUI
import UserNotifications

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
    public static var emotes: [String: [DiscordEmote]] = [:]
}

struct GuildHoverAnimation: ViewModifier {
    var color: Color = Color.accentColor.opacity(0.5)
    var hasIcon: Bool
    var frame: CGFloat = 45
    var selected: Bool
    @State var hovered: Bool = false
    
    func body(content: Content) -> some View {
        content
            .onHover(perform: { res in
                withAnimation(Animation.easeInOut(duration: 0.1)) {
                    hovered = res
                }
            })
            .frame(width: frame, height: frame)
            .background(!hasIcon && hovered ? self.color : Color.clear)
            .cornerRadius(hovered || selected ? 15 : frame / 2)
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
    var upcomingGuild: Guild?
    var upcomingSelection: Int?
    @AppStorage("SelectedServer")
    var selectedServer: Int?
    public static var folders: [GuildFolder] = .init()
    public static var privateChannels: [Channel] = .init()
    public static var mergedMembers: [String:Guild.MergedMember] = .init()
    internal static var readStates: [ReadStateEntry] = .init()
    var statusText: String?
    @State var status: String?
    @State var bag = Set<AnyCancellable>()
    @StateObject var viewUpdater = UpdateView()
    @State var iconHovered: Bool = false
    @State var isShowingJoinServerSheet: Bool = false
    
    var onlineButton: some View {
        Button("Offline") {
            AccordApp.error("Offline" as Error, additionalDescription: "Check your network connection")
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
                        .clipShape(Circle())
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
                        DMButton(
                            selection: self.$selection,
                            selectedServer: self.$selectedServer,
                            selectedGuild: self.$selectedGuild,
                            updater: self.viewUpdater
                        )
                        Color.gray
                            .frame(width: 30, height: 1)
                            .opacity(0.75)
                        FolderListView(selectedServer: self.$selectedServer, selection: self.$selection, selectedGuild: self.$selectedGuild, updater: self.viewUpdater)
                            .padding(.trailing, 3.5)
                        Color.gray
                            .frame(width: 30, height: 1)
                            .opacity(0.75)
                        JoinServerButton(viewUpdater: self.viewUpdater)
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
                        PrivateChannelsView (
                            privateChannels: Self.privateChannels,
                            selection: self.$selection,
                            viewUpdater: self.viewUpdater
                        )
                        .animation(nil, value: UUID())
                    }
                    .padding(.top, 5)
                    .listStyle(.sidebar)
                    .animation(nil, value: UUID())
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
            if let upcomingGuild = upcomingGuild {
                self.selectedGuild = upcomingGuild
                self.selection = self.upcomingSelection
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if selection == nil {
                    Toggle(isOn: Binding.constant(false)) {
                        Image(systemName: "bell.badge.fill")
                    }
                }
            }
        }
    }
}
