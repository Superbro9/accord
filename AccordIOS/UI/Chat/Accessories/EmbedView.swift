//
//  EmbedView.swift
//  Accord
//
//  Created by evelyn on 2021-10-24.
//

import SwiftUI
import AVKit

struct EmbedView: View, Equatable {
    weak var embed: Embed?

    static func == (_: EmbedView, _: EmbedView) -> Bool {
        true
    }

    var columns: [GridItem] = GridItem.multiple(count: 4)

    var body: some View {
        HStack(spacing: 0) {
            if let color = embed?.color {
                Color(int: color)
                    .frame(width: 3)
                    .padding(.trailing, 5)
            }
            VStack(alignment: .leading) {
                if let author = embed?.author {
                    HStack {
                        if let iconURL = author.proxy_icon_url {
                            Attachment(iconURL, size: CGSize(width: 24, height: 24))
                                .equatable()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else if let iconURL = author.icon_url {
                            Attachment(iconURL, size: CGSize(width: 24, height: 24))
                                .equatable()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        }
                        if let urlString = author.url, let url = URL(string: urlString) {
                            Link(author.name, destination: url)
                        } else {
                            Text(author.name)
                        }
                    }
                }
                if let title = embed?.title {
                    Text(title)
                        .fontWeight(.bold)
                        .font(.title3)
                }
                if let description = embed?.description {
                    if #available(iOS 15.0, *) {
                        Text((try? AttributedString(markdown: description)) ?? AttributedString(description))
                            .lineLimit(5)
                    } else {
                        Text(description)
                            .lineLimit(5)
                    }
                }
                if let image = embed?.image {
                    Attachment(image.url, size: CGSize(width: image.width ?? 300, height: image.width ?? 300))
                        .equatable()
                        .cornerRadius(5)
                        .maxFrame(width: 300, height: 300, originalWidth: image.width ?? 0, originalHeight: image.height ?? 0)
                        
                }
                if let video = embed?.video,
                   let urlString = video.proxy_url ?? video.url,
                    let url = URL(string: urlString) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .cornerRadius(5)
                        .frame(maxWidth: 250)
                }
                if let fields = embed?.fields {
                    LazyVGrid(columns: columns, alignment: .leading) {
                        ForEach(fields, id: \.name) { field in
                            VStack(alignment: .leading) {
                                Text(field.name)
                                    .lineLimit(0)
                                    .font(.subheadline)
                                AsyncMarkdown(field.value)
                                    .equatable()
                            }
                        }
                    }
                }
            }
            
        }
        .padding(.top, 5)
    }
}
