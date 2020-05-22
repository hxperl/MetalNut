//
//  ExposureFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/20.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

/// Adjusts the exposure of the image
public class ExposureFilter: BaseFilter {
    /// The adjusted exposure (-10.0 ~ 10.0, with 0.0 as the default)
    public var exposure: Float
    
    public init(exposure: Float = 0) {
        self.exposure = exposure
        super.init(kernelFunctionName: "exposureKernel")
    }
    
    public override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&exposure, length: MemoryLayout<Float>.size, index: 0)
    }
}
