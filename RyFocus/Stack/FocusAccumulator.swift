//
//  FocusAccumulator.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//


//
//  FocusAccumulator.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//
import MLX
import Foundation

@FocusStackActor
class FocusAccumulator {
    var bestPyr: [MLXArray] = []
    var contributionMap: MLXArray? = nil  // Track which pixels were updated by current image
    let pyrLevels: Int
    let height: Int
    let width: Int
    var imageCount: Int = 1
    let debug: Bool

    init(initialPyr: [MLXArray], debug: Bool = false) {
        self.pyrLevels = initialPyr.count
        self.height = initialPyr[0].shape[0]
        self.width = initialPyr[0].shape[1]
        self.bestPyr = initialPyr
        self.debug = debug
        
        // Initialize contribution map to zeros - will show contributions as images are processed
        self.contributionMap = zeros([height, width], dtype: .float32)
    }
    
    func updateWithPyramids(_ newPyr: [MLXArray]) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard newPyr.count == self.pyrLevels else {
            fatalError("Pyramid level count mismatch")
        }
        
        var totalUpdates = 0
        var totalPixels = 0
        
        for level in 0..<self.pyrLevels {
            let levelUpdates: Int
            let levelPixels = self.bestPyr[level].shape[0] * self.bestPyr[level].shape[1]
            
            if level == self.pyrLevels - 1 {
                // Coarsest level: Running average
                levelUpdates = processCoarsestLevel(level: level, newLevel: newPyr[level])
            } else if level == 0 {
                // Finest level: Neighborhood-based WTA (3x3)
                levelUpdates = processFinestLevel(level: level, newLevel: newPyr[level])
            } else {
                // Intermediate levels: Pixel-by-pixel WTA
                levelUpdates = processIntermediateLevel(level: level, newLevel: newPyr[level])
            }
            
            totalUpdates += levelUpdates
            totalPixels += levelPixels
        }
        
        let percentage = Float(totalUpdates) / Float(totalPixels) * 100.0
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("Image \(self.imageCount + 1): \(totalUpdates) pixels (\(String(format: "%.1f", percentage))%) updated in \(String(format: "%.2f", duration))ms")
        
        self.imageCount += 1
    }
    
    private func extractYChannel(_ pyramid: [MLXArray]) -> [MLXArray] {
        return pyramid.map { level in
            level[0..., 0..., 0..<1].squeezed(axes: [2])
        }
    }
    
    private func processCoarsestLevel(level: Int, newLevel: MLXArray) -> Int {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let countF32 = Float(self.imageCount)
        let newCountF32 = Float(self.imageCount + 1)
        
        // Running average: ((Previous Average × Image Count) + New Pixel Value) / (Image Count + 1)
        self.bestPyr[level] = (self.bestPyr[level] * countF32 + newLevel) / newCountF32
        
        if debug {
            self.bestPyr[level].eval()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("  Coarsest level processing: \(String(format: "%.2f", duration))ms")
        
        return self.bestPyr[level].shape[0] * self.bestPyr[level].shape[1]
    }
    
    private func processIntermediateLevel(level: Int, newLevel: MLXArray) -> Int {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let bestY = self.bestPyr[level][0..., 0..., 0]
        let newY = newLevel[0..., 0..., 0]
        
        // Compute Y² for focus measure
        let bestFocus = bestY * bestY
        let newFocus = newY * newY
        
        // Create mask where new focus is better
        let updateMask = newFocus .> bestFocus
        
        if debug {
            updateMask.eval()
        }
        
        // Apply updates using the mask
        let updates = applyMask(level: level, newLevel: newLevel, mask: updateMask)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("  Intermediate level \(level) processing: \(String(format: "%.2f", duration))ms")
        
        return updates
    }
    
    private func processFinestLevel(level: Int, newLevel: MLXArray) -> Int {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let bestY = self.bestPyr[level][0..., 0..., 0]
        let newY = newLevel[0..., 0..., 0]
        
        guard bestY.shape[0] >= 3 && bestY.shape[1] >= 3 else {
            return 0 // Not enough pixels for 3x3 neighborhoods
        }
        
        // Compute Y² for both images
        let bestYSquared = bestY * bestY
        let newYSquared = newY * newY
        
        // Compute difference (new_Y² - best_Y²)
        let ySquaredDiff = newYSquared - bestYSquared
        
        // Create 3x3 box filter kernel
        let boxKernel = ones([3, 3, 1, 1])
        
        // Apply 3x3 convolution to compute neighborhood sums
        let paddedDiff = expandedDimensions(ySquaredDiff, axes: [2, 3])
        let neighborhoodSums = conv2d(
            paddedDiff,
            boxKernel,
            stride: .init(1),
            padding: .init(1)
        )
        
        // Create update mask (neighborhood_sums > 0)
        let updateMask = neighborhoodSums[0..., 0..., 0, 0] .> 0
        
        if debug {
            neighborhoodSums.eval()
            updateMask.eval()
        }
        
        // Apply updates using the mask
        let updates = applyMask(level: level, newLevel: newLevel, mask: updateMask)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("  Finest level processing: \(String(format: "%.2f", duration))ms")
        
        return updates
    }
    
    private func applyMask(level: Int, newLevel: MLXArray, mask: MLXArray) -> Int {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Expand mask to match YUV channels
        let expandedMask = expandedDimensions(mask, axes: [2])
        let channelMask = broadcast(expandedMask, to: self.bestPyr[level].shape)
        
        // Apply conditional update
        let updated = MLX.where(channelMask, newLevel, self.bestPyr[level])
        
        // Update contribution map for level 0 (finest level)
        if level == 0 {
            // Set updated pixels to 1.0 (cumulative - don't reset to zeros)
            self.contributionMap = MLX.where(mask, ones(like: mask), self.contributionMap!)
        }
        
        // Count updates (only for Y channel to avoid triple counting)
        let yMask = mask.asType(.int32)
        let updateCount = sum(yMask).item(Int.self)
        
        self.bestPyr[level] = updated
        
        if debug {
            self.bestPyr[level].eval()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        print("    Apply mask for level \(level): \(String(format: "%.2f", duration))ms")
        
        return updateCount
    }
    
    func getCurrentFocusMap() -> MLXImage {
        // Generate the current progressive stacked result by collapsing the current pyramid
        let progressivePyr = Pyramid(pyramid: self.bestPyr, debug: false)
        let collapsedResult = progressivePyr.collapsePyramid()
        
        // Convert to displayable format: clamp to [0,1], scale to [0,255], convert to uint8
        let clamped = clip(collapsedResult, min: 0.0, max: 1.0)
        let scaled = clamped * 255.0
        let uint8Result = scaled.asType(DType.uint8)
        
        return MLXImage(uint8Result, bitsPerCompontent: 8)
    }
}
