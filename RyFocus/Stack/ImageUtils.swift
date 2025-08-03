//
//  ImageUtils.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import CoreGraphics
import opencv2
import MLX

@FocusStackActor
func cgImageToMat(image: CGImage) -> Mat {
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
    let mat = Mat()
    Imgproc.cvtColor(src: initial, dst: mat, code: .COLOR_RGBA2RGB)
    return mat
}

@FocusStackActor
public func matTo8BitGray(image: Mat, weights: Mat) -> Mat {
    let bitsPerComponents = 8 * image.elemSize1()
    var bit8 = Mat()
    if bitsPerComponents == 16 {
        image.convert(to: bit8, rtype: CvType.CV_8UC3, alpha: 1 / 257)
    } else {
        bit8 = image
    }

    let gray = Mat()
    Core.transform(src: bit8, dst: gray, m: weights)
    return gray
}

@FocusStackActor
public func matToMlx(image: Mat) -> MLXArray {
    var output = Mat()
    if !image.isContinuous() {
        image.copy(to: output)
    } else {
        output = image
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

