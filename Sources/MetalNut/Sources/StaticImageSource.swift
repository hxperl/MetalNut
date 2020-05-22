//
//  StaticImageSource.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/11/19.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import MetalKit

public class StaticImageSource {

    private let lock = DispatchSemaphore(value: 1)

    // image consumers
    public var consumers: [ImageConsumer] {
        lock.wait()
        let c = _consumers
        lock.signal()
        return c
    }

    private var _consumers: [ImageConsumer] = []

    /// Texture from static image
    private var texture: MTLTexture? {
        lock.wait()
        let t = _texture
        lock.signal()
        return t
    }

    private var _texture: MTLTexture?

    private var currentTexture: MTLTexture? {
        if let texture = image?.metalTexture { return texture }
        if let texture = cgimage?.metalTexture { return texture }
        if let texture = imageData?.metalTexture { return texture }
        return nil
    }

    private var image: UIImage?
    private var cgimage: CGImage?
    private var imageData: Data?

    public init(image: UIImage) { self.image = image }
    public init(cgimage: CGImage) { self.cgimage = cgimage }
    public init(imageData: Data) { self.imageData = imageData }
    public init(texture: MTLTexture) { _texture = texture }

    /// image consumer 에게 텍스쳐 전달
    public func transmitTexture() {
        lock.wait()
        if _texture == nil { _texture = currentTexture }
        guard let texture = _texture else {
            lock.signal()
            return
        }
        let consumers = _consumers
        lock.signal()
        let output = Texture(mtlTexture: texture, type: .photo)
        for consumer in consumers {
            consumer.newTextureAvailable(output, from: self)
        }
    }
}


extension StaticImageSource: ImageSource {
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
}

public extension UIImage {
    var metalTexture: MTLTexture? {
        if let cgimage = cgImage { return cgimage.metalTexture }
        return nil
    }
}

public extension CGImage {
    var metalTexture: MTLTexture? {
        let loader = MTKTextureLoader(device: MetalDevice.sharedDevice)
        if let texture = try? loader.newTexture(cgImage: self, options: [MTKTextureLoader.Option.SRGB : false]) {
            return texture
        }
        // Texture loader can not load image data to create texture
        // Draw image and create texture
        let descriptor = MTLTextureDescriptor()
		descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = width
        descriptor.height = height
        descriptor.usage = .shaderRead
        let bytesPerRow: Int = width * 4
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue
        if let currentTexture = MetalDevice.sharedDevice.makeTexture(descriptor: descriptor),
            let context = CGContext(data: nil,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: bytesPerRow,
                                    space: MetalDevice.sharedColorSpace,
                                    bitmapInfo: bitmapInfo) {
            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

            if let data = context.data {
                currentTexture.replace(region: MTLRegionMake3D(0, 0, 0, width, height, 1),
                                       mipmapLevel: 0,
                                       withBytes: data,
                                       bytesPerRow: bytesPerRow)
                return currentTexture
            }
        }

        return nil
    }
}

public extension Data {
    var metalTexture: MTLTexture? {
        let loader = MTKTextureLoader(device: MetalDevice.sharedDevice)
        return try? loader.newTexture(data: self, options: [MTKTextureLoader.Option.SRGB : false])
    }
}

public extension MTLTexture {
    var cgimage: CGImage? {
        let bytesPerPixel: Int = 4
        let bytesPerRow: Int = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: Int(width * height * bytesPerPixel))
        getBytes(&data, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
		let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue
        if let context = CGContext(data: &data,
                                   width: width,
                                   height: height,
                                   bitsPerComponent: 8,
                                   bytesPerRow: bytesPerRow,
                                   space: MetalDevice.sharedColorSpace,
                                   bitmapInfo: bitmapInfo) {
            return context.makeImage()
        }

        return nil
    }

    var uiImage : UIImage? {
        if let sourceImage = cgimage {
            return UIImage(cgImage: sourceImage)
        }
        return nil
    }
}
