//
//  GifView.swift
//  Accord
//
//  Created by evelyn on 2021-12-24.
//

import UIKit
import Combine
import Foundation
import SwiftUI

struct GifView: View {
    var url: String
    @State var currentImage: UIImage = .init()
    @State var animatedImages: [UIImage] = []
    @State var counterValue: Int = 0
    @State var duration: Double = 0
    @State var value: Int = 0
    @State var timer: Cancellable?
    @State private var can: AnyCancellable?
    var body: some View {
        ZStack {
            if animatedImages.isEmpty {
                Image(uiImage: UIImage())
            } else {
                Image(uiImage: animatedImages[value])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
            }
        }
        .onAppear { prep() }
        .onDisappear { timer?.cancel(); timer = nil }
    }
    
    func prep() {
        if url.suffix(4) == "json" {
            gifQueue.async {
                print(self.url)
                Request.fetch(url: URL(string: self.url)) {
                    switch $0 {
                    case .success(let data):
                        var req = URLRequest.init(url: URL(string: "https://api.evelyn.red/v1/lottie")!)
                        req.addValue("discord_sticker" + UUID().uuidString.toBase64(), forHTTPHeaderField: "filename")
                        req.httpBody = data
                        Request.fetch(request: req, headers: Headers(
                            contentType: "application/json",
                            type: .POST
                        )) {
                            switch $0 {
                            case .success(let data):
                                let gif = Gif(data: data)
                                guard let animatedImages = gif?.animatedImages, let calculatedDuration = gif?.calculatedDuration else { return }
                                self.animatedImages = animatedImages
                                self.duration = Double(CFTimeInterval(calculatedDuration))
                                DispatchQueue.main.async {
                                    self.timer = Timer.publish(
                                        every: Double(duration / Double(animatedImages.count)),
                                        tolerance: nil,
                                        on: .main,
                                        in: .default
                                    )
                                    .autoconnect()
                                    .sink { _ in
                                        if value + 1 == animatedImages.count {
                                            self.value = 0
                                            return
                                        }
                                        (self.value) += 1 % (animatedImages.count)
                                    }
                                }
                            case .failure(let error): print(error)
                            }
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        } else {
            gifQueue.async {
                can = URLSession.shared.dataTaskPublisher(for: URL(string: url)!)
                    .map(\.data)
                    .replaceError(with: Data())
                    .sink { data in
                        let gif = Gif(data: data)
                        animatedImages = gif?.animatedImages ?? []
                        duration = Double(CFTimeInterval(gif?.calculatedDuration ?? 0))
                        DispatchQueue.main.async {
                            self.timer = Timer.publish(
                                every: Double(duration / Double(animatedImages.count)),
                                tolerance: nil,
                                on: .main,
                                in: .default
                            )
                            .autoconnect()
                            .sink { _ in
                                if value + 1 == animatedImages.count {
                                    self.value = 0
                                    return
                                }
                                (self.value) += 1 % (animatedImages.count)
                            }
                        }
                    }
            }

        }
    }
}

struct HoverGifView: View {
    var url: String
    @State var animatedImages: [UIImage] = []
    @State var counterValue: Int = 0
    @State var duration: Double = 0
    @State var value: Int = 0
    @State var timer: Cancellable?
    @State private var can: AnyCancellable?
    @State var animated: Bool = false
    var body: some View {
        HStack {
            if !animatedImages.isEmpty {
                Image(uiImage: animated ? animatedImages[value] : animatedImages[0])
                    .resizable()
                    .scaledToFit()
                    .onHover { _ in animated.toggle() }
                    .onDisappear { timer?.cancel(); timer = nil; animatedImages.removeAll() }
            } else {
                Text("...")
                    .onAppear {
                        guard animatedImages.isEmpty else { return }
                        prep()
                    }
            }
        }
    }

    func prep() {
        gifQueue.async {
            guard let url = URL(string: url) else { return }
            can = URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .replaceError(with: Data())
                .sink { data in
                    let gif = Gif(data: data)
                    animatedImages = gif?.animatedImages ?? []
                    duration = Double(CFTimeInterval(gif?.calculatedDuration ?? 0))
                    DispatchQueue.main.async {
                        self.timer = Timer.publish(
                            every: Double(duration / Double(animatedImages.count)),
                            tolerance: nil,
                            on: .main,
                            in: .default
                        )
                        .autoconnect()
                        .sink { _ in
                            if value + 1 == animatedImages.count {
                                self.value = 0
                                return
                            }
                            (self.value) += 1 % (animatedImages.count)
                        }
                    }
                }
        }
    }
}
