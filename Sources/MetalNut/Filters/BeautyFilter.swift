//
//  BeautyFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/10.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

public class BeautyFilter: BaseFilterGroup {
    public var distanceNormalizationFactor: Float {
        get { return blurFilter.distanceNormalizationFactor }
        set { blurFilter.distanceNormalizationFactor = newValue }
    }
    
    public var stepOffset: Float {
        get { return blurFilter.stepOffset }
        set { blurFilter.stepOffset = newValue }
    }
    
    public var edgeStrength: Float {
        get { return edgeDetectionFilter.edgeStrength }
        set { edgeDetectionFilter.edgeStrength = newValue }
    }
    
    public var smoothDegree: Float {
        get { return combinationFilter.smoothDegree }
        set { combinationFilter.smoothDegree = newValue }
    }
    
    private let blurFilter: BilateralBlurFilter
    private let edgeDetectionFilter: SobelEdgeDetectionFilter
    private let combinationFilter: _BeautyCombinationFilter
    
    public init(distanceNormalizationFactor: Float = 4, stepOffset: Float = 4, edgeStrength: Float = 1, smoothDegree: Float = 0.5) {
        blurFilter = BilateralBlurFilter(distanceNormalizationFactor: distanceNormalizationFactor, stepOffset: stepOffset)
        edgeDetectionFilter = SobelEdgeDetectionFilter(edgeStrength: edgeStrength)
        combinationFilter = _BeautyCombinationFilter(smoothDegree: smoothDegree)
        
        blurFilter.add(consumer: combinationFilter)
        edgeDetectionFilter.add(consumer: combinationFilter)
        
        super.init(kernelFunctionName: "")
        
        initialFilters = [blurFilter, edgeDetectionFilter, combinationFilter]
        terminalFilter = combinationFilter
    }
}

fileprivate class _BeautyCombinationFilter: BaseFilter {
    fileprivate var smoothDegree: Float
    
    fileprivate init(smoothDegree: Float = 0.5) {
        self.smoothDegree = smoothDegree
        super.init(kernelFunctionName: "beautyCombinationKernel")
    }
    
    override func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        encoder.setBytes(&smoothDegree, length: MemoryLayout<Float>.size, index: 0)
    }
}

