//
//  CVImage.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//


//
//  CVImage.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//
import CoreGraphics
import Foundation
import ImageIO
import MLX
import opencv2

public struct CVImage: @unchecked Sendable {
    let mat: Mat

    public init(image: CGImage) {
        // https://github.com/opencv/opencv/blob/4.x/modules/imgcodecs/src/apple_conversions.mm
        let initial = Mat(
            rows: Int32(image.height),
            cols: Int32(image.width),
            type: image.bitsPerComponent == 16
                ? CvType.CV_16UC4 : CvType.CV_8UC4
        )
        let colorSpace = image.colorSpace!
        let context = CGContext(
            data: initial.dataPointer(),
            width: Int(initial.cols()),
            height: Int(initial.rows()),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: initial.elemSize() * Int(initial.cols()),
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        )!
        context.draw(
            image,
            in: CGRect(
                origin: .init(x: 0, y: 0),
                size: .init(
                    width: Int(initial.cols()),
                    height: Int(initial.rows())
                )
            )
        )
        self.mat = Mat()
        Imgproc.cvtColor(src: initial, dst: self.mat, code: .COLOR_RGBA2RGB)
        print(
            "Mat on load, \(mat.rows()), \(mat.cols()), \(mat.elemSize()), \(mat.elemSize1())"
        )
    }

    public init(mat: Mat) {
        self.mat = mat
    }

    public func crop(to: Rect) -> CVImage {
        let cropped = Mat.init(mat: mat, rect: to)
        return CVImage(mat: cropped)
    }

    public func toCgImage() -> CGImage {
        class DataHolder {
            var data: Data
            init(_ data: Data) {
                self.data = data
            }
        }

        let bitsPerComponent = 8 * mat.elemSize1()

        let output = Mat()

        print(
            "Mat before, \(mat.rows()), \(mat.cols()), \(mat.elemSize()), \(mat.elemSize1())"
        )

        Imgproc.cvtColor(src: mat, dst: output, code: .COLOR_RGB2RGBA)

        print(
            "Mat after, \(mat.rows()), \(mat.cols()), \(mat.elemSize()), \(mat.elemSize1())"
        )

        print("Element size \(output.elemSize())")
        let bytesPerRow = output.elemSize() * Int(output.cols())
        let holder = DataHolder(
            Data(
                bytes: output.dataPointer(),
                count: bytesPerRow * Int(output.rows())
            )
        )

        let payload = Unmanaged.passRetained(holder).toOpaque()
        func release(
            payload: UnsafeMutableRawPointer?,
            data: UnsafeMutableRawPointer?
        ) {
            Unmanaged<DataHolder>.fromOpaque(payload!).release()
        }

        let bitmapInfo =
            CGImageAlphaInfo.noneSkipLast.rawValue
            | (bitsPerComponent == 16
                ? CGBitmapInfo.byteOrder16Little.rawValue
                : CGBitmapInfo.byteOrderDefault.rawValue)

        return holder.data.withUnsafeMutableBytes { ptr in
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!

            let context = CGContext(
                data: ptr.baseAddress,
                width: Int(output.cols()),
                height: Int(output.rows()),
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: cs,
                bitmapInfo: bitmapInfo,
                releaseCallback: release,
                releaseInfo: payload
            )!
            return context.makeImage()!
        }
    }

    public func to8BitGray(weights: Mat) -> CVImage {
        let bitsPerComponents = 8 * mat.elemSize1()
        var bit8 = Mat()
        if bitsPerComponents == 16 {
            mat.convert(to: bit8, rtype: CvType.CV_8UC3, alpha: 1 / 257)
        } else {
            bit8 = mat
        }

        let gray = Mat()
        Core.transform(src: bit8, dst: gray, m: weights)
        return CVImage(mat: gray)
    }

    public func toMlx() -> MLXArray {
        var output = Mat()
        if !mat.isContinuous() {
            mat.copy(to: output)
        } else {
            output = mat
        }

        print(
            "Size to MLX, \(output.rows()), \(output.cols()), \(output.elemSize()), \(output.elemSize1())"
        )
        let bytesPerRow = output.elemSize() * Int(output.cols())
        print("Bytes per row \(bytesPerRow)")
        print("Byte count \(bytesPerRow * Int(output.rows()))")
        let data = Data(
            bytes: output.dataPointer(),
            count: bytesPerRow * Int(output.rows())
        )
        print("data count \(data.count)")

        if output.elemSize1() == 1 {
            return MLXArray.init(
                data,
                [Int(output.rows()), Int(output.cols()), 3],
                type: UInt8.self
            )
        } else {
            return MLXArray.init(
                data,
                [Int(output.rows()), Int(output.cols()), 3],
                type: UInt16.self
            )
        }
    }
}
