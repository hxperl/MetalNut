//
//  MetalNutDevice.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/11/15.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//
import Metal
import CoreGraphics

public class MetalDevice {
    public static let shared = MetalDevice()
    public static var sharedDevice: MTLDevice { return shared.device }
    public static var sharedCommandQueue: MTLCommandQueue { return shared.commandQueue }
    public static var sharedColorSpace: CGColorSpace { return shared.colorSpace }
    public static var sharedLibrary: MTLLibrary { return shared.library }
    
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let colorSpace: CGColorSpace
    public let library: MTLLibrary
    
    private init() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        colorSpace = CGColorSpaceCreateDeviceRGB()
		let bundle = Bundle(for: MetalDevice.self)
		let path = bundle.path(forResource: "default", ofType: "metallib")!
        library = try! device.makeLibrary(filepath: path)
    }
    
    public static func generateRenderPipelineState(vertexFunctionName: String, fragmentFunctionName: String, operationName: String) -> MTLRenderPipelineState {
        guard let vertexFunction = sharedLibrary.makeFunction(name: vertexFunctionName) else {
            fatalError("\(operationName): could not compile vertex function \(vertexFunctionName)")
        }
        
        guard let fragmentFunction = sharedLibrary.makeFunction(name: fragmentFunctionName) else {
            fatalError("\(operationName): could not compile fragment function \(fragmentFunctionName)")
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.rasterSampleCount = 1
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        return try! sharedDevice.makeRenderPipelineState(descriptor: descriptor)
    }
}

extension MTLCommandBuffer {
	func renderQuad(pipelineState:MTLRenderPipelineState, inputTexture: Texture, outputTexture:Texture, uniform: MTLBuffer? = nil) {
        let imageVertices: [Float] = [-1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0]
		let vertexBuffer = MetalDevice.sharedDevice.makeBuffer(bytes: imageVertices,
														   length: imageVertices.count * MemoryLayout<Float>.size,
														   options: [])!
		
        vertexBuffer.label = "Vertices"
		let clearColor = MTLClearColorMake(0, 0, 0, 0)
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = outputTexture.metalTexture
        renderPass.colorAttachments[0].clearColor = clearColor
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
		
        
        guard let renderEncoder = self.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
            
        let inputTextureCoordinates = inputTexture.textureCoordinates
        let textureBuffer = MetalDevice.sharedDevice.makeBuffer(bytes: inputTextureCoordinates,
                                                                         length: inputTextureCoordinates.count * MemoryLayout<Float>.size,
                                                                         options: [])!
        textureBuffer.label = "Texture Coordinates"

        renderEncoder.setVertexBuffer(textureBuffer, offset: 0, index: 1 )
		if uniform != nil {
			renderEncoder.setVertexBuffer(uniform, offset: 0, index: 2)
		}
        renderEncoder.setFragmentTexture(inputTexture.metalTexture, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}
