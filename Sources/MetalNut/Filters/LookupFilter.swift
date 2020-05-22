//
//  LookupFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

public class LookupFilter: BaseFilter {
    public var intensity: Float
    
    public init(intensity: Float = 1) {
        self.intensity = intensity
        super.init(kernelFunctionName: "lookupKernel", samplers: ["lookup": "original_lookup.png"])
    }
    
    public override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)
    }
}
