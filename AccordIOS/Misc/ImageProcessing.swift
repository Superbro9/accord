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
