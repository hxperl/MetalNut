//
//  ImageSource.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/11.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

infix operator --> : AdditionPrecedence

@discardableResult public func --><T: ImageConsumer>(source: ImageSource, destination:T) -> T {
    return source.add(consumer: destination)
}

public protocol ImageSource: AnyObject {
    /// Output 텍스처를 출력하기 위한 image consumer 추가
    ///
    /// - Parameter consumer: image consumer object to add
    /// - Returns: image consumer object
    func add<T: ImageConsumer>(consumer: T) -> T
    
    /// Adds an image consumer at the specific index
    ///
    /// - Parameters:
    ///   - consumer: image consumer object to add
    ///   - index: index for the image consumer object
    func add(consumer: ImageConsumer, at index: Int)
    
    /// image consumer 제거
    ///
    /// - Parameters consumer: image consumer object to remove
    func remove(consumer: ImageConsumer)
    
    /// Removs all image consumers
    func removeAllConsumers()
}
