//
//  PopoverProfileView.swift
//  Accord
//
//  Created by evelyn on 2021-07-13.
//

import SwiftUI

struct PopoverProfileView: View {
    var user: User?
    @State var hovered: Int?
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                if let banner = user?.banner, let id = user?.id {
                    Attachment("https://cdn.discordapp.com/banners/\(id)/\(banner).png")
                        .frame(height: 100)
                } else {
                    Color(UIColor.black).frame(height: 100).opacity(0.75)
                }
                Spacer()
            }
            VStack {
                Spacer().frame(height: 100)
                VStack(alignment: .leading) {
                    if user?.avatar?.prefix(2) == "a_" {
                        GifView(url: "https://cdn.discordapp.com/avatars/\(user?.id ?? "")/\(user?.avatar ?? "").gif?size=64")
                            .clipShape(Circle())
                            .frame(width: 45, height: 45)
                            .shadow(radius: 5)
                    } else {
                        Attachment(pfpURL(user?.id, user?.avatar))
                            .clipShape(Circle())
                            .frame(width: 45, height: 45)
                            .shadow(radius: 5)
                    }
                    Text(user?.username ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(user?.username ?? "")#\(user?.discriminator ?? "")")
                        .font(.subheadline)
                        .foregroundColor(Color.secondary)
                    HStack(alignment: .bottom) {
                        Button(action: {}, label: {
                            VStack {
                                Image(systemName: "bubble.right.fill")
                                    .imageScale(.medium)
                                Text("Message")
                                    .font(.subheadline)
                            }
                            .padding(4)
                            .frame(width: 60, height: 45)
                            .background(hovered == 1 ? Color.gray.opacity(0.25).cornerRadius(5) : Color.clear.cornerRadius(5))
                        })
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture {
                            withAnimation {
                                hovered = 4
                            }
                        }
                        Button(action: {}, label: {
                            VStack {
                                Image(systemName: "phone.fill")
                                    .imageScale(.large)
                                Text("Call")
                                    .font(.subheadline)
                            }
                            .padding(4)
                            .frame(width: 60, height: 45)
                            .background(hovered == 2 ? Color.gray.opacity(0.25).cornerRadius(5) : Color.clear.cornerRadius(5))
                        })
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture {
                            withAnimation {
                                hovered = 4
                            }
                        }
                        Button(action: {}, label: {
                            VStack {
                                Image(systemName: "camera.circle.fill")
                                    .imageScale(.large)
                                Text("Video call")
                                    .font(.subheadline)
                            }
                            .padding(4)
                            .frame(width: 60, height: 45)
                            .background(hovered == 3 ? Color.gray.opacity(0.25).cornerRadius(5) : Color.clear.cornerRadius(5))
                        })
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture {
                            withAnimation {
                                hovered = 4
                            }
                        }
                        Button(action: {}, label: {
                            VStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .imageScale(.large)
                                Text("Add Friend")
                                    .font(.subheadline)
                            }
                            .padding(4)
                            .frame(width: 60, height: 45)
                            .background(hovered == 4 ? Color.gray.opacity(0.25).cornerRadius(5) : Color.clear.cornerRadius(5))
                        })
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture {
                            withAnimation {
                                hovered = 4
                            }
                        }
                    }
                    .transition(AnyTransition.opacity)
                }
                .padding()
                .background(Color(UIColor.black))
            }
        }
        .frame(width: 290, height: 250)
    }
}
