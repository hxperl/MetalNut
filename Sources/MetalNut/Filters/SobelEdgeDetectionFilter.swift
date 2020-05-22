//
//  SobelEdgeDetectionFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/10.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

/// Sobel edge detection, with edges highlighted in white
public class SobelEdgeDetectionFilter: BaseFilter {
    /// Adjusts the dynamic range of the filter. Higher values lead to stronger edges, but can saturate the intensity colorspace. Default is 1.0
    public var edgeStrength: Float
    
    public init(edgeStrength: Float = 1) {
        self.edgeStrength = edgeStrength
        super.init(kernelFunctionName: "sobelEdgeDetectionKernel")
    }
    
    public override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&edgeStrength, length: MemoryLayout<Float>.size, index: 0)
    }
}
