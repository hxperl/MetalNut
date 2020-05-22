//
//  RenderView.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2020/05/22.
//

import MetalKit

public class RenderView: MTKView, ImageConsumer {
    
	private var lock = DispatchSemaphore(value: 1)
    private var currentTexture: Texture?
    private var renderPipelineState:MTLRenderPipelineState!
    
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: MetalDevice.sharedDevice)
        
        commonInit()
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    private func commonInit() {
        framebufferOnly = false
        autoResizeDrawable = true
        self.device = MetalDevice.sharedDevice
        self.renderPipelineState = MetalDevice.generateRenderPipelineState(vertexFunctionName:"oneInputVertex", fragmentFunctionName:"passthroughFragment", operationName:"RenderView")
        enableSetNeedsDisplay = false
        isPaused = true
    }
    
    public func newTextureAvailable(_ texture: Texture, from source: ImageSource) {
		lock.wait()
		guard case .videoFrame = texture.type else {
			lock.signal()
			return
		}
        self.drawableSize = CGSize(width: texture.metalTexture.width, height: texture.metalTexture.height)
        currentTexture = texture
        self.draw()
		lock.signal()
    }
    
    
    public override func draw(_ rect:CGRect) {
        if let currentDrawable = self.currentDrawable, let imageTexture = currentTexture {
            let commandBuffer = MetalDevice.sharedCommandQueue.makeCommandBuffer()
            let outputTexture = Texture(mtlTexture: currentDrawable.texture, type: imageTexture.type)
            commandBuffer?.renderQuad(pipelineState: renderPipelineState, inputTexture: imageTexture, outputTexture: outputTexture)
            commandBuffer?.present(currentDrawable)
            commandBuffer?.commit()
        }
    }
    
    public func add(source: ImageSource) {}
    
    public func remove(source: ImageSource) {}
    
    
}
