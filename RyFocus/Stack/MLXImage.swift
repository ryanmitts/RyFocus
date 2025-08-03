//
//  MLXImage.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//


//
//  MlxImage.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//
import CoreGraphics
import Foundation
import ImageIO
import MLX
import UniformTypeIdentifiers

/// Conversion utilities for moving between `MLXArray`, `CGImage` and files.
@FocusStackActor
public struct MLXImage {
    public var data: MLXArray
    public var bitsPerComponent: Int

    /// Create an Image from a MLXArray with ndim == 3
    public init(_ data: MLXArray, bitsPerCompontent: Int) {
        precondition(data.ndim == 3)
        self.data = data
        self.bitsPerComponent = bitsPerCompontent
    }

    /// Create an Image by loading from a file
    public init(url: URL, maximumEdge: Int? = nil) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw FocusStackError.unableToOpen
        }

        self.init(image: image)
    }

    /// Create an image from a CGImage
    /// TODO this only loads in 8 bits
    public init(image: CGImage, maximumEdge: Int? = nil) {
        let width = image.width
        let height = image.height
        self.bitsPerComponent = image.bitsPerComponent

        var raster = Data(count: width * 4 * height)
        raster.withUnsafeMutableBytes { ptr in
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            let context = CGContext(
                data: ptr.baseAddress, width: width, height: height, bitsPerComponent: 8, // TODO FIX if needed
                bytesPerRow: width * 4, space: cs,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue)!

            context.draw(
                image, in: CGRect(origin: .zero, size: .init(width: width, height: height)))
            context.makeImage()
        }

        self.data = MLXArray(raster, [height, width, 4], type: UInt8.self)[0..., 0..., ..<3]
    }
    
    public mutating func convertToFloat() -> MLXImage {
        self.data = data.asType(.float32)
        return self
    }

    /// Convert the image data to a CGImage
    public func asCGImage() -> CGImage {
        var raster = data

        // we need 4 bytes per pixel
        if data.dim(-1) == 3 {
            raster = padded(raster, widths: [0, 0, [0, 1]])
        }

        @FocusStackActor
        class DataHolder {
            var data: Data
            init(_ data: Data) {
                self.data = data
            }
        }

        let holder = DataHolder(raster.asData(access: .copy).data)

        let payload = Unmanaged.passRetained(holder).toOpaque()
        
        nonisolated func release(payload: UnsafeMutableRawPointer?, data: UnsafeMutableRawPointer?) {
            Unmanaged<DataHolder>.fromOpaque(payload!).release()
        }

        return holder.data.withUnsafeMutableBytes { ptr in
            let (H, W, C) = raster.shape3
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            
            let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
                | (bitsPerComponent == 16 ? CGBitmapInfo.byteOrder16Little.rawValue : CGBitmapInfo.byteOrderDefault.rawValue)

            let context = CGContext(
                data: ptr.baseAddress, width: W, height: H, bitsPerComponent: bitsPerComponent, bytesPerRow: W * C * (bitsPerComponent == 16 ? 2 : 1),
                space: cs,
                bitmapInfo: bitmapInfo,
                releaseCallback: release,
                releaseInfo: payload)!
            return context.makeImage()!
        }
    }

    /// Save the image
    public func save(url: URL) throws {
        let uti = UTType(filenameExtension: url.pathExtension) ?? UTType.png

        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, uti.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, asCGImage(), nil)
        if !CGImageDestinationFinalize(destination) {
            throw FocusStackError.failedToSave
        }
    }
}
