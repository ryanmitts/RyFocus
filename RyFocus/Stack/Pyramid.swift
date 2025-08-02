//
//  Pyramid.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

//
//  Pyramid.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//
import Foundation
import MLX

class Pyramid {
    private var gauss_w: Int = 5
    private var downscaleGaussKernel: MLXArray
    private var upscaleGaussKernel: MLXArray
    private var img: MLXArray
    private var levels: Int
    var laplacianPyr: [MLXArray] = []
    let debug: Bool

    init(img: MLXArray, debug: Bool = false) {
        let rgbImg = img.asType(.float32)
        // Normalize to [0,1] range - assuming input is 8-bit [0,255] or 16-bit [0,65535]
        let maxVal = img.dtype == .uint8 ? 255.0 : 65535.0
        let normalizedRgb = rgbImg / maxVal
        self.img = Pyramid.rgbToYuv(normalizedRgb)
        let minDimension: Int = min(img.dim(0), img.dim(1))
        self.levels = Int(floor(log2(Float(minDimension) / Float(64))) + 1)
        self.debug = debug

        let kernel2d = Pyramid.gaussianKernel(l: self.gauss_w)
        self.downscaleGaussKernel = expandedDimensions(kernel2d, axes: [0, 3])
        self.upscaleGaussKernel = expandedDimensions(
            kernel2d * 4,
            axes: [0, 3]
        )
    }

    init(pyramid: [MLXArray], debug: Bool = false) {
        guard !pyramid.isEmpty else {
            fatalError("Empty pyramid")
        }

        self.laplacianPyr = pyramid
        self.img = pyramid[0]
        let minDimension: Int = min(pyramid[0].dim(0), pyramid[0].dim(1))
        self.levels = pyramid.count - 1
        self.debug = debug

        let kernel2d = Pyramid.gaussianKernel(l: self.gauss_w)
        self.downscaleGaussKernel = expandedDimensions(kernel2d, axes: [0, 3])
        self.upscaleGaussKernel = expandedDimensions(
            kernel2d * 4,
            axes: [0, 3]
        )
    }

    private static func rgbToYuv(_ rgb: MLXArray) -> MLXArray {
        let values: [Float32] = [
            0.299, 0.587, 0.114,
            -0.14713, -0.28886, 0.436,
            0.615, -0.51499, -0.10001,
        ]
        let transformMatrix = MLXArray(values).reshaped([3, 3])

        let rgbFlat = rgb.reshaped([-1, 3])
        let yuvFlat = matmul(rgbFlat, transformMatrix.transposed())
        return yuvFlat.reshaped(rgb.shape)
    }

    static func yuvToRgb(_ yuv: MLXArray) -> MLXArray {
        let values: [Float32] = [
            1.0, 0.0, 1.13983,
            1.0, -0.39465, -0.58060,
            1.0, 2.03211, 0.0,
        ]
        let transformMatrix = MLXArray(values).reshaped([3, 3])

        let yuvFlat = yuv.reshaped([-1, 3])
        let rgbFlat = matmul(yuvFlat, transformMatrix.transposed())
        return rgbFlat.reshaped(yuv.shape)
    }

    private static func gaussianKernel(l: Int, sig: Float32 = 1.0) -> MLXArray {
        let start = -(Float32(l - 1)) / 2.0
        let stop = Float32(l - 1) / 2.0
        let ax = linspace(start, stop, count: l)
        let gauss = exp(-0.5 * ax.square() / MLXArray(sig).square())
        let kernel = outer(gauss, gauss)
        return kernel / sum(kernel)
    }

    func pyramidDown(img: MLXArray) -> MLXArray {
        let startTime = CFAbsoluteTimeGetCurrent()

        let padding = (self.gauss_w - 1) / 2
        let input = expandedDimensions(img, axes: [0])

        var convolved = MLXArray.zeros([0])
        for c in 0..<3 {
            let channelInput = input[0..., 0..., 0..., c..<(c + 1)]
            let channelConv = conv2d(
                channelInput,
                self.downscaleGaussKernel,
                stride: .init(1),
                padding: .init(padding)
            )
            if c == 0 {
                convolved = channelConv
            } else {
                convolved = concatenated([convolved, channelConv], axis: 3)
            }
        }

        convolved = convolved[0..., .stride(by: 2), .stride(by: 2), 0...]
        convolved = convolved.squeezed(axes: [0])

        if debug {
            convolved.eval()
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("    pyramidDown: \(String(format: "%.2f", duration))ms")

        return convolved
    }

    func pyramidUp(img: MLXArray, size: [Int]) async -> MLXArray {
        let startTime = CFAbsoluteTimeGetCurrent()

        let targetWidth = size[0]
        let targetHeight = size[1]
        let padding = (self.gauss_w - 1) / 2

        var upsampled = zeros([targetWidth, targetHeight, 3])
        upsampled[.stride(by: 2), .stride(by: 2), 0...] = img[0..., 0..., 0...]

        let input = expandedDimensions(upsampled, axes: [0])

        var convolved = MLXArray.zeros([0])
        for c in 0..<3 {
            let channelInput = input[0..., 0..., 0..., c..<(c + 1)]
            let channelConv = conv2d(
                channelInput,
                self.upscaleGaussKernel,
                stride: .init(1),
                padding: .init(padding)
            )
            if c == 0 {
                convolved = channelConv
            } else {
                convolved = concatenated([convolved, channelConv], axis: 3)
            }
        }

        convolved = convolved.squeezed(axes: [0])

        await MLX.asyncEval(convolved)

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("    pyramidUp: \(String(format: "%.2f", duration))ms")

        return convolved
    }

    private func gaussianPyramid() async -> [MLXArray] {
        let startTime = CFAbsoluteTimeGetCurrent()

        var pyramid: [MLXArray] = []
        var lower = self.img
        pyramid.append(lower)
        for _ in stride(from: 0, to: self.levels, by: 1) {
            lower = self.pyramidDown(img: lower)
            pyramid.append(lower)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("  gaussianPyramid: \(String(format: "%.2f", duration))ms")

        return pyramid
    }

    func generateLaplacianPyramid() async -> [MLXArray] {
        let startTime = CFAbsoluteTimeGetCurrent()

        self.laplacianPyr = []
        let gaussianPyr = await self.gaussianPyramid()

        for i in stride(from: 0, to: self.levels, by: 1) {
            let size = [
                gaussianPyr[i].shape[0], gaussianPyr[i].shape[1],
            ]
            let gaussianExpanded = self.pyramidUp(
                img: gaussianPyr[i + 1],
                size: size
            )
            let laplacian = gaussianPyr[i] - gaussianExpanded
            if self.debug {
                laplacian.eval()
            }
            self.laplacianPyr.append(laplacian)
        }

        let laplacianTop = gaussianPyr.last!
        self.laplacianPyr.append(laplacianTop)

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print(
            "  generateLaplacianPyramid: \(String(format: "%.2f", duration))ms"
        )
        return self.laplacianPyr
    }

    func collapsePyramid() -> MLXArray {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard !self.laplacianPyr.isEmpty else {
            fatalError("Empty pyramid")
        }

        let lastIdx = self.laplacianPyr.count - 1

        if lastIdx == 0 {
            return Pyramid.yuvToRgb(self.laplacianPyr[0])
        }

        var current = self.laplacianPyr[lastIdx]

        for level in stride(from: lastIdx - 1, through: 0, by: -1) {
            let targetSize = [
                self.laplacianPyr[level].shape[0],
                self.laplacianPyr[level].shape[1],
            ]

            let upsampled = pyramidUp(img: current, size: targetSize)
            current = upsampled + self.laplacianPyr[level]
            if debug {
                current.eval()
            }
        }

        let result = Pyramid.yuvToRgb(current)

        if debug {
            result.eval()
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("  collapsePyramid: \(String(format: "%.2f", duration))ms")

        return result
    }
}
