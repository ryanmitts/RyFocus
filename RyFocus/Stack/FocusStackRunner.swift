//
//  FocusStackError.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//


//
//  FocusStackRunner.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import CoreGraphics
import Foundation
import ImageIO
import opencv2
import MLX
import Combine
internal import RealModule

enum FocusStackError: Error {
    case failedToSave
    case unableToOpen
}

extension Rect {
    var cgRect: CGRect {
        return CGRect(
            origin: CGPoint(x: Double(x), y: Double(y)),
            size: CGSize(width: Double(width), height: Double(height))
        )
    }
}

extension CGRect {
    var rect: Rect {
        return Rect(x: Int32(origin.x), y: Int32(origin.y), width: Int32(width), height: Int32(height))
    }
}

extension Double {
    func round(to places: Int) -> Double {
        let divisor = Double.pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

@Observable
@MainActor
class FocusStackRunner {
    var progress: Double = 0.0
    var isRunning: Bool = false
    var progressiveFocusMap: MLXImage?

    func findWarp(
        incomingRef: Mat,
        incomingSrc: Mat,
        maxRes: Int,
        rough: Bool,
        prevWarp: Mat? = nil
    ) -> Mat {
        let startTime = CFAbsoluteTimeGetCurrent()

        var warp = Mat(rows: 2, cols: 3, type: CvType.CV_32F, scalar: Scalar(0))
        warp.at(row: 0, col: 0).v = 1.0
        warp.at(row: 1, col: 1).v = 1.0

        if prevWarp != nil {
            warp = prevWarp!
        }

        let res = max(incomingRef.cols(), incomingRef.rows())
        var ref = Mat()
        let src = Mat()
        var scale = Float(1.0)
        if res <= maxRes {
            ref = incomingRef
            incomingSrc.copy(to: src)
        } else {
            scale = Float(maxRes) / Float(res)
            Imgproc.resize(
                src: incomingRef,
                dst: ref,
                dsize: Size2i(),
                fx: Double(scale),
                fy: Double(scale),
                interpolation: InterpolationFlags.INTER_AREA.rawValue
            )
            Imgproc.resize(
                src: incomingSrc,
                dst: src,
                dsize: Size2i(),
                fx: Double(scale),
                fy: Double(scale),
                interpolation: InterpolationFlags.INTER_AREA.rawValue
            )
        }

        warp.at(row: 0, col: 2).v *= scale
        warp.at(row: 1, col: 2).v *= scale

        let mask = Mat()
        if rough {
            Video.findTransformECC(
                templateImage: src,
                inputImage: ref,
                warpMatrix: warp,
                motionType: Video.MOTION_AFFINE,
                criteria: TermCriteria(
                    type: TermCriteria.count + TermCriteria.eps,
                    maxCount: 25,
                    epsilon: 0.01
                ),
                inputMask: mask,
                gaussFiltSize: 1
            )
        } else {
            Video.findTransformECC(
                templateImage: src,
                inputImage: ref,
                warpMatrix: warp,
                motionType: Video.MOTION_AFFINE,
                criteria: TermCriteria(
                    type: TermCriteria.count + TermCriteria.eps,
                    maxCount: 50,
                    epsilon: 0.001
                ),
                inputMask: mask,
                gaussFiltSize: 3
            )
        }

        warp.at(row: 0, col: 2).v /= scale
        warp.at(row: 1, col: 2).v /= scale

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("  findWarp (\(rough ? "rough" : "fine")): \(String(format: "%.2f", duration))ms")

        return warp
    }

    func applyTransform(src: CVImage, warp: Mat) -> CVImage {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let res = Mat(
            rows: src.mat.rows(),
            cols: src.mat.cols(),
            type: src.mat.type()
        )
        Imgproc.warpAffine(
            src: src.mat,
            dst: res,
            M: warp,
            dsize: Size2i(width: src.mat.width(), height: src.mat.height()),
            flags: InterpolationFlags.INTER_LANCZOS4.rawValue,
            borderMode: .BORDER_REFLECT
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("  applyTransform: \(String(format: "%.2f", duration))ms")
        
        return CVImage(mat: res)
    }

    func transformPoint(point: Point2f, warp: Mat) -> Point2f {
        let x =
            warp.at(row: 0, col: 0).v * point.x + warp.at(row: 0, col: 1).v
            * point.y + warp.at(row: 0, col: 2).v
        let y =
            warp.at(row: 1, col: 0).v * point.x + warp.at(row: 1, col: 1).v
            * point.y + warp.at(row: 1, col: 2).v
        return Point2f(x: x, y: y)
    }

    func stackWithSecurityScope(imageURLs: [URL], debug: Bool = false) async throws -> MLXImage {
        isRunning = true
        progress = 0.0
        progressiveFocusMap = nil
        
        defer {
            isRunning = false
            progress = 0.0
            progressiveFocusMap = nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                #if os(macOS)
                // Start security-scoped access for all URLs
                let accessingUrls = imageURLs.map { ($0, $0.startAccessingSecurityScopedResource()) }
                defer {
                    // Stop security-scoped access when done
                    for (url, accessing) in accessingUrls {
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                }
                #endif
                
                do {
                    let result = try await self.stack(
                        imageURLs: imageURLs, 
                        debug: debug,
                        reportProgress: { progress, focusMap in
                            Task { @MainActor in
                                self.progress = progress
                                self.progressiveFocusMap = focusMap
                            }
                        }
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func stack(imageURLs: [URL], debug: Bool = false, reportProgress: @escaping @Sendable (Double, MLXImage?) -> Void) async throws -> MLXImage {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        
        // TODO Wrong error.
        guard !imageURLs.isEmpty else { throw FocusStackError.unableToOpen }

        let totalImages = imageURLs.count

        var crops: [Rect] = []
        var warps: [Mat] = []

        guard var refCGImage = await loadCGImage(from: imageURLs[0])
        else {
            throw FocusStackError.unableToOpen
        }
        var refCvImage = CVImage(image: refCGImage)
        let grayWeights = Mat(rows: 1, cols: 3, type: CvType.CV_32F)
        try grayWeights.put(row: 0, col: 0, data: [0.299, 0.587, 0.114])
        var refGray = refCvImage.to8BitGray(weights: grayWeights)

        // For the reference image
        crops.append(
            Rect(
                x: 0,
                y: 0,
                width: Int32(refCGImage.width),
                height: Int32(refCGImage.height)
            )
        )
        warps.append(Mat.eye(rows: 2, cols: 3, type: CvType.CV_32F))

        let pyrStartTime = CFAbsoluteTimeGetCurrent()
        let refPyr = Pyramid(img: refCvImage.toMlx(), debug: debug)
        let refLaplacian = refPyr.generateLaplacianPyramid()
        let accumulator = FocusAccumulator(
            initialPyr: refLaplacian,
            debug: debug
        )
        let pyrEndTime = CFAbsoluteTimeGetCurrent()
        let pyrDuration = (pyrEndTime - pyrStartTime) * 1000
        print("Reference pyramid generation: \(String(format: "%.2f", pyrDuration))ms")
        
        // Generate initial focus map from reference image
        let initialFocusMap = accumulator.getCurrentFocusMap()
        reportProgress(0.0, initialFocusMap)

        for i in 1..<imageURLs.count {
            let imageStartTime = CFAbsoluteTimeGetCurrent()
            print("\nProcessing image \(i + 1)/\(imageURLs.count)")
            
            guard let srcCGImage = await loadCGImage(from: imageURLs[i])
            else {
                throw FocusStackError.unableToOpen
            }
            let srcCvImage = CVImage(image: srcCGImage)
            let srcGray = srcCvImage.to8BitGray(weights: grayWeights)

            let warpRough = findWarp(
                incomingRef: refGray.mat,
                incomingSrc: srcGray.mat,
                maxRes: 256,
                rough: true
            )
            var warp = findWarp(
                incomingRef: refGray.mat,
                incomingSrc: srcGray.mat,
                maxRes: 2048,
                rough: false,
                prevWarp: warpRough
            )

            let tmp = warps[i - 1].clone()
            let newRow = Mat(
                rows: 1,
                cols: 3,
                type: CvType.CV_32F,
                scalar: Scalar(0)
            )
            newRow.at(row: 0, col: 2).v = 1.0
            tmp.push_back(newRow)

            warp = warp * tmp

            print("Image warp")
            print(
                """
                      \(warp.get(row: 0, col: 0)[0].round(to: 2)) \(warp.get(row: 0, col: 1)[0].round(to: 2)) \(warp.get(row: 0, col: 2)[0].round(to: 2))
                      \(warp.get(row: 1, col: 0)[0].round(to: 2)) \(warp.get(row: 1, col: 1)[0].round(to: 2)) \(warp.get(row: 1, col: 2)[0].round(to: 2))
                """
            )

            let warpedSrc = applyTransform(src: srcCvImage, warp: warp)

            warps.append(warp)

            let tl = transformPoint(point: Point2f(x: 0, y: 0), warp: warp)
            let tr = transformPoint(
                point: Point2f(x: Float(srcCvImage.mat.width()), y: 0),
                warp: warp
            )
            let bl = transformPoint(
                point: Point2f(x: 0, y: Float(srcCvImage.mat.height())),
                warp: warp
            )
            let br = transformPoint(
                point: Point2f(
                    x: Float(srcCvImage.mat.width()),
                    y: Float(srcCvImage.mat.height())
                ),
                warp: warp
            )
            let top = Int32(max(tl.y, tr.y).rounded(.up))
            let left = Int32(max(tl.x, bl.x).rounded(.up))
            let bottom = Int32(max(bl.y, br.y).rounded(.down))
            let right = Int32(max(br.x, tr.x).rounded(.down))

            let cropArea = Rect(
                x: left,
                y: top,
                width: right - left,
                height: bottom - top
            )
            print("Crop: \(cropArea.cgRect)")
            crops.append(cropArea)

            refCGImage = srcCGImage
            refCvImage = srcCvImage
            refGray = srcGray

            let srcPyrStartTime = CFAbsoluteTimeGetCurrent()
            let srcPyramid = Pyramid(img: warpedSrc.toMlx(), debug: debug)
            let srcPyrGenerated = srcPyramid.generateLaplacianPyramid()
            let srcPyrEndTime = CFAbsoluteTimeGetCurrent()
            let srcPyrDuration = (srcPyrEndTime - srcPyrStartTime) * 1000
            print("  Source pyramid generation: \(String(format: "%.2f", srcPyrDuration))ms")
            
            accumulator.updateWithPyramids(srcPyrGenerated)

            // Update progressive focus map
            let updatedFocusMap = accumulator.getCurrentFocusMap()
            let currentProgress = Double(i + 1) / Double(totalImages)
            reportProgress(currentProgress, updatedFocusMap)
            
            let imageEndTime = CFAbsoluteTimeGetCurrent()
            let imageDuration = (imageEndTime - imageStartTime) * 1000
            print("  Total image processing: \(String(format: "%.2f", imageDuration))ms")
            
            // Yield control to keep UI responsive
            await Task.yield()
        }

        var crop = crops.first!
        for i in 1..<crops.count {
            crop = crop.cgRect.intersection(crops[i].cgRect).rect
        }
        print("The crop: \(crop.cgRect)")

        let collapseStartTime = CFAbsoluteTimeGetCurrent()
        let bestPyr = Pyramid(pyramid: accumulator.bestPyr, debug: debug)
        // TODO: Need to actually know the original bit depth.
        let collapsed = bestPyr.collapsePyramid()
        let collapseEndTime = CFAbsoluteTimeGetCurrent()
        let collapseDuration = (collapseEndTime - collapseStartTime) * 1000
        print("\nPyramid collapse: \(String(format: "%.2f", collapseDuration))ms")

        // Convert float32 RGB to 8-bit: clamp to [0,1], scale to [0,255], convert to uint8
        let clamped = clip(collapsed, min: 0.0, max: 1.0)
        let scaled = clamped * 255.0
        let collapsed8bit = scaled.asType(.uint8)
        
        // Apply final crop
        let croppedImage = collapsed8bit[
            Int(crop.y)..<Int(crop.y + crop.height),
            Int(crop.x)..<Int(crop.x + crop.width),
            0...
        ]

        let bestImageMlx = MLXImage(croppedImage, bitsPerCompontent: 8)


        let overallEndTime = CFAbsoluteTimeGetCurrent()
        let overallDuration = (overallEndTime - overallStartTime) * 1000
        print("\nTotal focus stacking time: \(String(format: "%.2f", overallDuration))ms")

        return bestImageMlx

    }

    private func loadCGImage(from url: URL) async -> CGImage? {
        guard
            let imageSource = CGImageSourceCreateWithURL(
                url as CFURL,
                nil
            )
        else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(
            imageSource,
            0,
            nil
        )
    }
}
