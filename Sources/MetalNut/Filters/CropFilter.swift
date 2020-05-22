//
//  CropFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/10.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

/// Crops image to the specific rect
public class CropFilter: BaseFilter {
    /// A rectangular area to crop out of the image, normalized to coordinates from 0.0 ~ 1.0. The (0.0, 0.0) position is in the upper left of the image
    public var rect: Rect
    
    public init(rect: Rect) {
        self.rect = rect
        super.init(kernelFunctionName: "cropKernel")
    }
    
    public override func outputTextureSize(withInputTextureSize inputSize: IntSize) -> IntSize {
        return IntSize(width: Int(rect.width * Float(inputSize.width)), height: Int(rect.height * Float(inputSize.height)))
    }
    
    public override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&rect, length: MemoryLayout<Rect>.size, index: 0)
    }
}
