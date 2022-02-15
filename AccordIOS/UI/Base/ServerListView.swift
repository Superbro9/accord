//
//  ServerListView.swift
//  Accord
//
//  Created by evelyn on 2021-06-18.
//

import Combine
import SwiftUI

public var roleColors: [String: (Int, Int)] = [:]

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

    @State var selection: Int?
    @State var selectedServer: Int? = 0
    @State var online: Bool = true
    @State var alert: Bool = true
    public static var folders: [GuildFolder] = []
    public static var privateChannels: [Channel] = []
    internal static var readStates: [ReadStateEntry] = []
    @State var status: String?
    @State var timedOut: Bool = false
    @State var mentions: Bool = false
    @State var bag = Set<AnyCancellable>()
    @State var updater: Bool = false

    var body: some View {
        lazy var dmButton = Button(action: {
            wss?.cachedMemberRequest.removeAll()
            selectedServer = 201
            selection = nil
        }) {
            Image(systemName: "bubble.left.fill")
                .frame(width: 45, height: 45)
                .background(VisualEffectView(effect: UIBlurEffect(style: .regular)))
                .cornerRadius(selectedServer == 201 ? 15.0 : 23.5)
        }
        lazy var onlineButton: some View = Button("Offline") {
            alert.toggle()
        }
        .alert(isPresented: $alert) {
            Alert(
                title: Text("Could not connect"),
                message: Text("There was an error connecting to Discord"),
                primaryButton: .default(
                    Text("Ok"),
                    action: {
                        alert.toggle()
                    }
                ),
                secondaryButton: .destructive(
                    Text("Reconnect"),
                    action: {
                        if let wss = wss {
                            wss.reset()
                        } else {
                            concurrentQueue.async {
                                guard let new = try? Gateway(url: Gateway.gatewayURL) else { return }
                                new.ready().sink(receiveCompletion: doNothing, receiveValue: doNothing).store(in: &new.bag)
                                wss = new
                            }
                        }
                    }
                )
            )
        }
        
        lazy var statusIndicator: some View = Group {
            switch self.status {
            case "online":
                Circle()
                    .foregroundColor(Color.green)
                    .frame(width: 12, height: 12)
            case "invisible":
                Image("invisible")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            case "dnd":
                Image("dnd")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            case "idle":
                Circle()
                    .foregroundColor(Color(UIColor.systemOrange))
                    .frame(width: 12, height: 12)
            default:
                Circle()
                    .foregroundColor(Color.clear)
                    .frame(width: 12, height: 12)
            }
        }
        
        lazy var settingsLink: some View = NavigationLink(destination: NavigationLazyView(SettingsViewRedesign()), tag: 0, selection: self.$selection) {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: UIImage(data: avatar) ?? UIImage()).resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .cornerRadius((self.selection == 0) ? 15.0 : 23.5)
                statusIndicator
            }
        }
        
        return NavigationView {
            HStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    // MARK: - Messages button
                    LazyVStack {
                        if !online || !NetworkCore.shared.connected {
                            onlineButton
                        }
                        dmButton
                        Color.gray
                            .frame(height: 1)
                            .opacity(0.75)
                            .padding(.horizontal)
                        FolderListView(selectedServer: self.$selectedServer, selection: self.$selection)
                        Color.gray
                            .frame(height: 1)
                            .opacity(0.75)
                            .padding(.horizontal)
                        settingsLink
                    }
                    .padding(.vertical)
                }
                .buttonStyle(BorderlessButtonStyle())
                .frame(width: 80)
                .padding(.top, 5)
                Divider()
                // MARK: - Loading UI
                if selectedServer == 201 {
                    List {
                        Text("Messages")
                            .fontWeight(.bold)
                            .font(.title2)
                        Divider()
                        ForEach(Self.privateChannels, id: \.id) { channel in
                            NavigationLink(destination: NavigationLazyView(ChannelView(channel).equatable()), tag: Int(channel.id) ?? 0, selection: self.$selection) {
                                ServerListViewCell(channel: channel)
                                    .onChange(of: self.selection, perform: { _ in
                                        if self.selection == Int(channel.id) {
                                            channel.read_state?.mention_count = 0
                                            channel.read_state?.last_message_id = channel.last_message_id
                                        }
                                    })
                            }
                        }
                    }
                    .padding(.top, 5)
                    .listStyle(.sidebar)
                } else if let selected = selectedServer {
                    GuildView(guild: Array(Self.folders.compactMap { $0.guilds }.joined())[selected], selection: self.$selection)
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
        })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DMSelect")), perform: { pub in
            guard let uInfo = pub.userInfo as? [String: String],
                  let index = uInfo["index"], let number = Int(index) else { return }
            self.selectedServer = 201
            self.selection = number
        })
        .onAppear {
            concurrentQueue.async {
                if !Self.folders.isEmpty {
                    let val = UserDefaults.standard.integer(forKey: "AccordChannelIn\(Array(Self.folders.compactMap { $0.guilds }.joined())[0].id)")
                    DispatchQueue.main.async {
                        self.selection = (val != 0 ? val : nil)
                    }
                }
                Request.fetch([Channel].self, url: URL(string: "\(rootURL)/users/@me/channels"), headers: standardHeaders) { completion in
                    switch completion {
                    case .success(let channels):
                        let channels = channels.sorted { $0.last_message_id ?? "" > $1.last_message_id ?? "" }
                        DispatchQueue.main.async {
                            Self.privateChannels = channels
                            concurrentQueue.async {
                                assignPrivateReadStates()
                            }
                        }
                        Notifications.privateChannels = Self.privateChannels.map(\.id)
                    case .failure(let error):
                        print(error)
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
