//
//  ContrastFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/20.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

/// Adjusts the contrast of the image
public class ContrastFilter: BaseFilter {
    /// The adjusted contrast (0.0 ~ 4.0, with 1.0 as the default)
    public var contrast: Float
    
    public init(contrast: Float = 1) {
        self.contrast = contrast
        super.init(kernelFunctionName: "contrastKernel")
    }
    
    public override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&contrast, length: MemoryLayout<Float>.size, index: 0)
    }
}
