//
//  MetalNutPosition.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/11/15.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

/// Normalized position with coordinate values from 0.0 to 1.0
public struct Position {
    public var x: Float
    public var y: Float
    
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
    
    public static let center = Position(x: 0.5, y: 0.5)
}
