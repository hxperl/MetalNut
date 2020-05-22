//
//  CollageFilter.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2020/01/23.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import Metal

public class CollageFilter: ImageRelay {

	private let lock = DispatchSemaphore(value: 1)
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

	public var outputTexture: MTLTexture? {
        lock.wait()
        let o = _outputTexture
        lock.signal()
        return o
    }

    public private(set) var _outputTexture: MTLTexture?
	private let threadgroupSize: MTLSize
    private var threadgroupCount: MTLSize?

	private var computePipeline: MTLComputePipelineState!

	private var outputSize: IntSize?

    public init() {
		_consumers = []
        _sources = []

		threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)

		if let kernelFunction = MetalDevice.sharedLibrary.makeFunction(name: "collageKernel") {
            computePipeline = try? MetalDevice.sharedDevice.makeComputePipelineState(function: kernelFunction)
        }
    }

	public func newTextureAvailable(_ texture: Texture, from source: ImageSource) {
		lock.wait()
		
		if outputSize == nil {
			outputSize = IntSize(width: texture.metalTexture.width, height: texture.metalTexture.height)
		}

        for i in 0..<_sources.count {
            if _sources[i].source === source {
                _sources[i].texture = texture.metalTexture
            } else if _sources[i].texture == nil {
				_sources[i].texture = createTexture(width: outputSize!.width, height: outputSize!.height)
            }
        }
		
		if _sources[0].source !== source {
            lock.signal()
            return
        }
		
        if _outputTexture == nil ||
            _outputTexture!.width != outputSize!.width ||
            _outputTexture!.height != outputSize!.height {
			if let output = createTexture(width: outputSize!.width, height: outputSize!.height) {
                _outputTexture = output
            } else {
                lock.signal()
                return
            }
            threadgroupCount = nil
        }

        // Render image to output texture
        guard let commandBuffer = MetalDevice.sharedCommandQueue.makeCommandBuffer() else { return }
        commandBuffer.label = "collageKrnelCommand"

            // Update thread group count if needed
        if threadgroupCount == nil {
            threadgroupCount = MTLSize(width: (outputSize!.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                       height: (outputSize!.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                       depth: 1)
        }

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.label = "collageKrnelCommand"

        encoder.setComputePipelineState(computePipeline)

        encoder.setTexture(_outputTexture, index: 0)
        for i in 0..<_sources.count { encoder.setTexture(_sources[i].texture, index: i + 1) }
        encoder.dispatchThreadgroups(threadgroupCount!, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        commandBuffer.commit()

        let consumers = _consumers
        lock.signal()

        let output = Texture(mtlTexture: _outputTexture!, type: texture.type)
        for consumer in consumers { consumer.newTextureAvailable(output, from: self)}
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

    public func add(chain: BaseFilter) {
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
	
	private func createTexture(width: Int, height: Int) -> MTLTexture? {
		let descriptor = MTLTextureDescriptor()
//		descriptor.pixelFormat = .rgba8Unorm
		descriptor.pixelFormat = .bgra8Unorm
		descriptor.width = width
		descriptor.height = height
		descriptor.usage = [.shaderRead, .shaderWrite]
		return MetalDevice.sharedDevice.makeTexture(descriptor: descriptor)
	}
}
