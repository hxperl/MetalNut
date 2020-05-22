//
//  MetalNutBaseFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/11/15.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

public struct WeakImageSource {
    public weak var source: ImageSource?
    public var texture: MTLTexture?
    
    public init(source: ImageSource) { self.source = source }
}

/// A base filter processing texture. Subclass this class. Do not create an instance using the class directly.
open class BaseFilter: ImageRelay {
    
    let lock = DispatchSemaphore(value: 1)
    /// Image consumers
    public var consumers: [ImageConsumer] {
        lock.wait()
        let c = _consumers
        lock.signal()
        return c
    }
    private var _consumers: [ImageConsumer]
    
    /// Image sources
    public var sources: [WeakImageSource] {
        lock.wait()
        let s = _sources
        lock.signal()
        return s
    }
    public private(set) var _sources: [WeakImageSource]
    
    /// Filter name
    public let name: String
    
    private let samplers: [String: String]
    
    public var outputTexture: MTLTexture? {
        lock.wait()
        let o = _outputTexture
        lock.signal()
        return o
    }
    public private(set) var _outputTexture: MTLTexture?
    
    private var sampleTextures: [MTLTexture] = []
    
    private let threadgroupSize: MTLSize
    private var threadgroupCount: MTLSize?
    
    private var computePipeline: MTLComputePipelineState!
    
    public init(kernelFunctionName: String, samplers: [String: String] = [:]) {
        _consumers = []
        _sources = []
        self.name = kernelFunctionName
        self.samplers = samplers
        
        threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        
        if let kernelFunction = MetalDevice.sharedLibrary.makeFunction(name: kernelFunctionName) {
            computePipeline = try? MetalDevice.sharedDevice.makeComputePipelineState(function: kernelFunction)
        }
        
        for key in samplers.keys.sorted() {
            let imageName = samplers[key]!
            if !imageName.isEmpty {
                let texture = getSamplerTexture(named: imageName)!
                sampleTextures.append(texture)
            }
        }
    }
    
    open func newTextureAvailable(_ texture: Texture, from source: ImageSource) {
        lock.wait()
        
        // Check whether all input textures are ready
        var foundSource = false
        var empty = false
        for i in 0..<_sources.count {
            if _sources[i].source === source {
                _sources[i].texture = texture.metalTexture
                foundSource = true
            } else if _sources[i].texture == nil {
                if foundSource {
                    lock.signal()
                    return
                }
                empty = true
            }
        }
        if !foundSource || empty {
            lock.signal()
            return
        }
        
        let outputSize = outputTextureSize(withInputTextureSize: IntSize(width: texture.metalTexture.width, height: texture.metalTexture.height))
        if _outputTexture == nil ||
            _outputTexture!.width != outputSize.width ||
            _outputTexture!.height != outputSize.height {
            let descriptor = MTLTextureDescriptor()
			descriptor.pixelFormat = .rgba8Unorm
//			descriptor.pixelFormat = .bgra8Unorm
			descriptor.width = outputSize.width
			descriptor.height = outputSize.height
            descriptor.usage = [.shaderRead, .shaderWrite]
            if let output = MetalDevice.sharedDevice.makeTexture(descriptor: descriptor) {
                _outputTexture = output
            } else {
                lock.signal()
                return
            }
            threadgroupCount = nil
        }
        
        // Render image to output texture
        guard let commandBuffer = MetalDevice.sharedCommandQueue.makeCommandBuffer() else { return }
        commandBuffer.label = name + "Command"
        
            // Update thread group count if needed
        if threadgroupCount == nil {
            threadgroupCount = MTLSize(width: (outputSize.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                       height: (outputSize.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                       depth: 1)
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.label = name + "Encoder"
        
        encoder.setComputePipelineState(computePipeline)
        
        encoder.setTexture(_outputTexture, index: 0)
        for i in 0..<_sources.count { encoder.setTexture(_sources[i].texture, index: i + 1) }
        for i in 0..<sampleTextures.count { encoder.setTexture(sampleTextures[i], index: i + 2)}
        updateParameters(forComputeCommandEncoder: encoder)
        encoder.dispatchThreadgroups(threadgroupCount!, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        
        commandBuffer.commit()
        
		clearOldInputs()
        
        let consumers = _consumers
        lock.signal()
        
        let output = Texture(mtlTexture: _outputTexture!, type: texture.type)
        for consumer in consumers { consumer.newTextureAvailable(output, from: self)}
    }
	
	func clearOldInputs() {
		for i in 0..<_sources.count { _sources[i].texture = nil }
	}
    
    /// Calcutes the ouput texture size.
    /// Returns the input texture size by default.
    /// Override the method if needed.
    ///
    /// - Parameter inputSize: input texture size
    /// - Returns: output texture size
    open func outputTextureSize(withInputTextureSize inputSize: IntSize) -> IntSize {
        return inputSize
    }
    
    /// Updates parameters for the compute command encoder.
    /// Override the method to set bytes or other paramters for the compute command encoder.
    ///
    /// - Parameter encoder: compute command encoder to use
    open func updateParameters(forComputeCommandEncoder encoder: MTLComputeCommandEncoder) {
        fatalError("\(#function) must be overridden by subclass")
    }
    
    // MARK: - ImageSource
    
    @discardableResult
    public func add<T: ImageConsumer>(consumer: T) -> T {
        lock.wait()
        _consumers.append(consumer)
        lock.signal()
        consumer.add(source: self)
        return consumer
    }
    
    public func add(consumer: ImageConsumer, at index: Int) {
        lock.wait()
        _consumers.insert(consumer, at: index)
        lock.signal()
        consumer.add(source: self)
    }
    
    public func add(chain: ImageRelay) {
        for (idx, consumer) in consumers.enumerated() {
            chain.add(consumer: consumer, at: idx)
        }
        removeAllConsumers()
        add(consumer: chain, at: 0)
    }
    
    public func removeSelf() {
        for w_source in sources {
            w_source.source?.remove(consumer: self)
            for (idx, consumer) in consumers.enumerated() {
                w_source.source?.add(consumer: consumer, at: idx)
            }
        }
        removeAllConsumers()
        self._sources.removeAll()
    }
    
    public func remove(consumer: ImageConsumer) {
        lock.wait()
        if let index = _consumers.firstIndex(where: { $0 === consumer }) {
            _consumers.remove(at: index)
            lock.signal()
            consumer.remove(source: self)
        } else {
            lock.signal()
        }
    }
    
    public func removeAllConsumers() {
        lock.wait()
        let consumers = _consumers
        _consumers.removeAll()
        lock.signal()
        for consumer in consumers {
            consumer.remove(source: self)
        }
    }

    // MARK: - ImageConsumer
    
    public func add(source: ImageSource) {
        lock.wait()
        _sources.append(WeakImageSource(source: source))
        lock.signal()
    }
    
    public func remove(source: ImageSource) {
        lock.wait()
        if let index = _sources.firstIndex(where: { $0.source === source }) {
            _sources.remove(at: index)
        }
        lock.signal()
    }
    
    
    open func getSamplerTexture(named name: String) -> MTLTexture? {
        let bundle = Bundle(for: Self.self)
        let resourceURL = bundle.url(forResource: "FilterAssets", withExtension: "bundle")!
        let resourceBundle = Bundle(url: resourceURL)!
        let url = resourceBundle.url(forResource: name, withExtension: nil)!
        let data = try? Data(contentsOf: url)
        return data?.metalTexture
    }
}
