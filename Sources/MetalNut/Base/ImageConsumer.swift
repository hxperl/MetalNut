//
//  ImageConsumer.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/11.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

public protocol ImageConsumer: AnyObject {
    /// 텍스처를 제공 받기 위한 image source 추가
    ///
    /// - Parameter source: image source object to add
    func add(source: ImageSource)
    
    /// image source 제거
    ///
    /// - Parameter source: image source object to remove
    func remove(source: ImageSource)
    
    /// image source로 부터 새로운 텍스처를 받음
    ///
    /// - Parameters:
    ///     - texture: 새로운 텍스처
    ///     - source: 새로운 텍스처를 전달한 image source object
    func newTextureAvailable(_ texture: Texture, from source: ImageSource)
}

public protocol ImageRelay: ImageSource, ImageConsumer {
	
}
