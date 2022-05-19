//
//  GifManager.swift
//  NitrolessiOS
//
//  Created by Amy While on 16/02/2021.
//

import UIKit

final class Gif: UIImage {
    var calculatedDuration: Double?
    var animatedImages: [UIImage]?

    convenience override init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
              let delayTime = ((metadata as NSDictionary)["{GIF}"] as? NSDictionary)?["DelayTime"] as? Double else { return nil }
        var images: [UIImage] = .init()
        let imageCount = CGImageSourceGetCount(source)
     //   let width = (metadata as NSDictionary)["PixelWidth"] as? Double
     //   let height = (metadata as NSDictionary)["PixelHeight"] as? Double
        for i in 0 ..< imageCount {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let tmpImage = UIImage(cgImage: image)
                images.append(tmpImage)
            }
        }
        let calculatedDuration = Double(images.count) * delayTime
        self.init()
        animatedImages = images
        self.calculatedDuration = calculatedDuration
    }
}
