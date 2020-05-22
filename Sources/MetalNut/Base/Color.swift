//
//  MetalNutColor.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/11/15.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

/// RGBA with normalized color channel value form 0.0 to 1.0
public struct Color {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float
    
    public init(red: Float, green: Float, blue: Float, alpha: Float = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public static let black = Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    public static let white = Color(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    public static let red = Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    public static let green = Color(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
    public static let blue = Color(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
    public static let transparent = Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
}
