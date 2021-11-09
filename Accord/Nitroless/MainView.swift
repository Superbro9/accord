//
// Views.swift
// NitrolessMac
//
// Created by evelyn on 12.02.21
//

import SwiftUI

struct SpringyButton: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CGFloat(0.85) : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? 0.0 : 0))
            .blur(radius: configuration.isPressed ? CGFloat(0.0) : 0)
            .animation(Animation.spring(response: 0.35, dampingFraction: 1, blendDuration: 0))
            .padding(.bottom, 3)
    }
}

struct EmoteButton: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CGFloat(0.85) : 1.0)
            .animation(.spring())
            .padding(.bottom, 3)
    }
}

// actual view
struct NitrolessView: View, Equatable {
    static func == (lhs: NitrolessView, rhs: NitrolessView) -> Bool {
        return true
    }
    
    @State var searchenabled = true
    var columns: [GridItem] = [
        GridItem(spacing: 1),
        GridItem(spacing: 1),
        GridItem(spacing: 1),
        GridItem(spacing: 1),
        GridItem(spacing: 1),
        GridItem(spacing: 1),
        GridItem(spacing: 1),
        GridItem(spacing: 1)
    ]
    @Binding var chatText: String
    @State var SearchText: String = ""
    @State var minimumWidth = 275
    @State var recentMax = 8
    @Environment(\.openURL) var openURL
    @State var recentsenabled = true
    @State var allEmotes: [String:String] = [:]
    @State var search: String = ""
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    TextField("Search for emotes", text: $search)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if search != "" {
                        LazyVGrid(columns: columns) {
                            ForEach(Array(allEmotes.keys.filter { $0.contains(search) }), id: \.self) { key in
                                Button(action: {
                                    guard let emote = allEmotes[key] else { return }
                                    chatText.append(contentsOf: "https://assets.ebel.gay/nitrolessrepo/emotes/\(key)\(emote)")
                                }) {
                                    VStack {
                                        HoveredAttachment("https://assets.ebel.gay/nitrolessrepo/emotes/\(key)\(allEmotes[key] ?? "")").equatable()
                                            .frame(width: 20, height: 20)
                                    }
                                    .frame(width: 30, height: 30)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    } else {
                        LazyVGrid(columns: columns) {
                            ForEach(Array(allEmotes.keys), id: \.self) { key in
                                Button(action: {
                                    chatText.append(contentsOf: "https://assets.ebel.gay/nitrolessrepo/emotes/\(key)\(allEmotes[key] ?? "")")
                                }) {
                                    VStack {
                                        HoveredAttachment("https://assets.ebel.gay/nitrolessrepo/emotes/\(key)\(allEmotes[key] ?? "")").equatable()
                                            .frame(width: 20, height: 20)
                                    }
                                    .frame(width: 30, height: 30)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }

                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 250, maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Networking<Repo>().fetch(url: URL(string: "https://assets.ebel.gay/nitrolessrepo/index.json")) { repo in
                guard let repo = repo else { return }
                for emote in repo.emotes {
                    allEmotes[emote.name] = emote.type
                }
            }
        }
    }
}
