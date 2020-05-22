//
//  FlipFilter.swift
//  MetalNut
//
//  Created by 김지수 on 2020/01/29.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import Metal

public class FlipFilter: BaseFilter {
    /// Whether to flip horizontally or not
    public var horizontal: Bool
    /// Whether to flip vertically or not
    public var vertical: Bool
    
    public init(horizontal: Bool, vertical: Bool) {
        self.horizontal = horizontal
        self.vertical = vertical
        super.init(kernelFunctionName: "flipKernel")
    }
    
    public override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&horizontal, length: MemoryLayout<Bool>.size, index: 0)
        encoder.setBytes(&vertical, length: MemoryLayout<Bool>.size, index: 1)
    }
}
