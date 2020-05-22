//
//  ResizeFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/10.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import MetalKit

/// Resizes image to the specific size. The image will be scaled
public class ResizeFilter: BaseFilter {
    /// Size to resize, normalized to coordinates from 0.0 ~ 1.0
    public var size: Size
    
    public init(size: Size) {
        self.size = size
        super.init(kernelFunctionName: "resizeKernel")
    }
    
    public override func outputTextureSize(withInputTextureSize inputSize: IntSize) -> IntSize {
        return IntSize(width: Int(size.width * Float(inputSize.width)), height: Int(size.height * Float(inputSize.height)))
    }
    
    public override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&size, length: MemoryLayout<Size>.size, index: 0)
    }
}
