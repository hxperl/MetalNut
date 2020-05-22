//
//  UniformFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2020/01/23.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import Metal

public class UniformFilter: BaseFilter {
	
	private var renderPipelineState: MTLRenderPipelineState!
	private var uniform: MTLBuffer!
	
	public init(matrix: Matrix) {
		self.renderPipelineState = MetalDevice.generateRenderPipelineState(vertexFunctionName:"oneInputUniformVertex", fragmentFunctionName:"passthroughFragment", operationName:"UniformFilter")
		
		uniform = MetalDevice.sharedDevice.makeBuffer(length: MemoryLayout<Float>.size * 16, options: [])
		let bufferPointer = uniform.contents()
		memcpy(bufferPointer, matrix.m, MemoryLayout<Float>.size * 16)
		super.init(kernelFunctionName: "")
	}
    
	public override func newTextureAvailable(_ texture: Texture, from source: ImageSource) {
		guard let commandBuffer = MetalDevice.sharedCommandQueue.makeCommandBuffer() else { return }
		let inputWidth = texture.metalTexture.width
		let inputHeight = texture.metalTexture.height
		let outputTexture = Texture(device: MetalDevice.sharedDevice, width: inputWidth, height: inputHeight, type: texture.type)
		commandBuffer.renderQuad(pipelineState: self.renderPipelineState, inputTexture: texture, outputTexture: outputTexture, uniform: uniform)
		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()
		clearOldInputs()

		for consumer in consumers {
			consumer.newTextureAvailable(outputTexture, from: self)
		}
    }
}
