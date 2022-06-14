//
//  AttachmentView.swift
//  Accord
//
//  Created by evelyn on 2021-07-01
//

import AVKit
import Combine
import SwiftUI

func frameSize(width: CGFloat, height: CGFloat, originalWidth: Int?, originalHeight: Int?) -> (CGFloat, CGFloat) {
    guard let widthInt = originalWidth,
          let heighthInt = originalHeight else { return (width, height) }
    let originalWidth = CGFloat(widthInt)
    let originalHeight = CGFloat(heighthInt)
    let max: CGFloat = max(width, height)
    if originalWidth > originalHeight {
        return (max, originalHeight / originalWidth * max)
    } else {
        return (originalWidth / originalHeight * max, max)
    }
}

public extension View {
    func maxFrame(width: CGFloat, height: CGFloat, originalWidth: Int?, originalHeight: Int?) -> some View {
        let (width, height) = frameSize(width: width, height: height, originalWidth: originalWidth, originalHeight: originalHeight)
                 return frame(width: width, height: height)
    }
}

struct AttachmentView: View {
    var media: [AttachedFiles]
    var body: some View {
        ForEach(media, id: \.url) { obj in
            if obj.content_type?.contains("image/") == true && obj.content_type?.contains("gif") == false {
                Attachment(obj.url, size: CGSize(width: 500, height: 500)).equatable()
                    .cornerRadius(5)
                    .maxFrame(width: 350, height: 350, originalWidth: obj.width, originalHeight: obj.height)
            } else if obj.content_type?.contains("gif") == true {
                             GifView(url: obj.url)
                                 .cornerRadius(5)
                                 .maxFrame(width: 350, height: 350, originalWidth: obj.width, originalHeight: obj.height)
                                 .accessibility(label: Text(obj.description ?? "Image"))
            } else if obj.content_type?.prefix(6).stringLiteral == "video/", let url = URL(string: obj.proxy_url) {
                VideoPlayer(player: AVPlayer.init(url: url))
                    .cornerRadius(5)
                    .maxFrame(width: 350, height: 350, originalWidth: obj.width, originalHeight: obj.height)
            }
        }
    }
}

struct VideoPlayerController: UIViewRepresentable {
    
    init(url: URL) {
        player = AVPlayer(url: url)
    }
    
    var player: AVPlayer?
    func makeUIView(context: Context) -> PlayerView {
        let playerView = PlayerView()
        playerView.player = player
        return playerView
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) { }
}

class PlayerView: UIView {

    // Override the property to make AVPlayerLayer the view's backing layer.
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    
    // The associated player object.
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
