//
//  MetalNutTexture.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/11/15.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//
import Metal
import AVFoundation

public enum TextureType {
    case photo
    case videoFrame(timestamp: CMTime)
    
    var timestamp: CMTime? {
        get {
            switch self {
            case .photo: return nil
            case let .videoFrame(timestamp): return timestamp
            }
        }
    }
}

public struct Texture {
    public let metalTexture: MTLTexture
    public let type: TextureType
    
    public var textureCoordinates: [Float] {
        [0, 0, 1, 0, 0, 1, 1, 1]
    }
    
    public init(mtlTexture: MTLTexture, type: TextureType) {
        self.metalTexture = mtlTexture
        self.type = type
    }
    
    public init(device: MTLDevice, pixelFormat: MTLPixelFormat = .bgra8Unorm, width: Int, height: Int, mipmapped: Bool = false, type: TextureType = .photo) {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
																		 width: width,
																		 height: height,
																		 mipmapped: mipmapped)
        
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        
        guard let newTexture = MetalDevice.sharedDevice.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Could not create texture of size: (\(width), \(height))")
        }
        
        self.metalTexture = newTexture
        self.type = type
    }
}
