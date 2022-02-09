//
//  AttachmentView.swift
//  Accord
//
//  Created by evelyn on 2021-07-01
//

import AVKit
import Combine
import SwiftUI

struct AttachmentView: View {
    var media: [AttachedFiles]
    var body: some View {
        ForEach(media, id: \.url) { obj in
            HStack(alignment: .top) {
                VStack { [unowned obj] in
                    if obj.content_type?.prefix(6).stringLiteral == "image/" {
                        Attachment(obj.url, size: CGSize(width: 350, height: 350)).equatable()
                            .cornerRadius(5)
                            .frame(maxWidth: 350, maxHeight: 350)
                    } else if obj.content_type?.prefix(6).stringLiteral == "video/", let url = URL(string: obj.url) {
                        VideoPlayer(player: AVPlayer.init(url: url))
                            .cornerRadius(5)
                            .frame(minWidth: 300, minHeight: 300)
                            .onDisappear {
                                print("goodbye")
                            }
                    }
                }
                Button(action: { [weak obj] in
                    if obj?.content_type?.prefix(6).stringLiteral == "video/" {
                        UIApplication.shared.open(URL(string: obj?.url ?? "")!)
                        
                    } else if obj?.content_type?.prefix(6).stringLiteral == "image/" {
                        UIApplication.shared.open(URL(string: obj?.url ?? "")!)
            
                    } else {
                        UIApplication.shared.open(URL(string: obj?.url ?? "")!)
                    }
                }) {
                    Image(systemName: "arrow.up.forward.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}
