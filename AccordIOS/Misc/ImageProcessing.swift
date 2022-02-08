//
//  NSImage+Processing.swift
//  NSImage+Processing
//
//  Created by evelyn on 2021-10-17.
//

import UIKit
import ImageIO
import Foundation

extension CGImage {
    var png: Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
extension UIImage {
    // Thanks Amy 🙂
        func downsample(image: UIImage, to pointSize: CGSize? = nil, scale: CGFloat? = nil) -> Data? {
            let size = pointSize ?? image.size
            let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let data = image.pngData() as CFData?,
            let imageSource = CGImageSourceCreateWithData(data, imageSourceOptions) else { return nil }
            let downsampled = downsample(source: imageSource, size: size, scale: scale)
            guard let downsampled = downsampled else { return nil }
            return downsampled
            //return downsample(source: imageSource, size: size, scale: scale)
        }
        
    private func downsample(source: CGImageSource, size: CGSize, scale: CGFloat?) -> Data? {
        let maxDimentionInPixels = max(size.width, size.height) * (scale ?? UIScreen.main.scale)
        let downsampledOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                  kCGImageSourceShouldCacheImmediately: true,
                                  kCGImageSourceCreateThumbnailWithTransform: true,
                                  kCGImageSourceThumbnailMaxPixelSize: maxDimentionInPixels] as CFDictionary
        guard let downScaledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampledOptions) else { return nil }
        return downScaledImage.png
    }
        
     //   func getSize(from source: CGImageSource) -> CGSize? {
     //       guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
     //             let height = (metadata as NSDictionary)["PixelHeight"] as? Double,
     //             let width = (metadata as NSDictionary)["PixelWidth"] as? Double else { return nil }
     //       return CGSize(width: width, height: height)
     //   }
}

extension Data {
    func downsample(to size: CGSize, scale: CGFloat? = nil) -> Data? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, imageSourceOptions) else { return nil }
        let downsampled = downsample(source: imageSource, size: size, scale: scale)
        guard let downsampled = downsampled else { return nil }
        return downsampled
    }

    private func downsample(source: CGImageSource, size: CGSize, scale: CGFloat?) -> Data? {
        let maxDimensionInPixels = Swift.max(size.width, size.height) * (scale ?? 1)
        let downsampledOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                  kCGImageSourceShouldCacheImmediately: true,
                                  kCGImageSourceCreateThumbnailWithTransform: true,
                                  kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels] as CFDictionary
        guard let downScaledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampledOptions) else { return nil }
        return downScaledImage.png
    }
}
