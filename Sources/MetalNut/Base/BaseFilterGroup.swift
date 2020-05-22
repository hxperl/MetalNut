//
//  BaseFilterGroup.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/11.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal

open class BaseFilterGroup: BaseFilter {
    public var initialFilters: [BaseFilter]!
    public var terminalFilter: BaseFilter!
    
    public override var consumers: [ImageConsumer] { return terminalFilter.consumers }
    
    public override var sources: [WeakImageSource] { return initialFilters.first?.sources ?? [] }
    
    public override var outputTexture: MTLTexture? {
        return terminalFilter.outputTexture
    }
    
    
    // MARK: - ImageSource
    
    @discardableResult
    public override func add<T: ImageConsumer>(consumer: T) -> T {
        terminalFilter.add(consumer: consumer)
        return consumer
    }
    
    public override func add(consumer: ImageConsumer, at index: Int) {
        terminalFilter.add(consumer: consumer, at: index)
    }
    
    public override func remove(consumer: ImageConsumer) {
        terminalFilter.remove(consumer: consumer)
    }
    
    public override func removeAllConsumers() {
        terminalFilter.removeAllConsumers()
    }
    
    // MARK: - ImageConsumer
    
    public override func add(source: ImageSource) {
        for filter in initialFilters {
            filter.add(source: source)
        }
    }
    
    public override func remove(source: ImageSource) {
        for filter in initialFilters {
            filter.remove(source: source)
        }
    }
    
    public override func newTextureAvailable(_ texture: Texture, from source: ImageSource) {
        for filter in initialFilters {
            filter.newTextureAvailable(texture, from: source)
        }
    }
}
