//
//  MetalNutMatrix.swift
//  MetalNut
//
//  Created by Geonseok Lee on 2019/11/15.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//
import Foundation

public struct Matrix4x4 {
    public var m11: Float, m12: Float, m13: Float, m14: Float
    public var m21: Float, m22: Float, m23: Float, m24: Float
    public var m31: Float, m32: Float, m33: Float, m34: Float
    public var m41: Float, m42: Float, m43: Float, m44: Float
    
    public init(rowMajorValues: [Float]) {
        guard rowMajorValues.count > 15 else { fatalError("Tried to initialize a 4x4 matrix with fewer than 16 values") }
        
        self.m11 = rowMajorValues[0]
        self.m12 = rowMajorValues[1]
        self.m13 = rowMajorValues[2]
        self.m14 = rowMajorValues[3]
        
        self.m21 = rowMajorValues[4]
        self.m22 = rowMajorValues[5]
        self.m23 = rowMajorValues[6]
        self.m24 = rowMajorValues[7]
        
        self.m31 = rowMajorValues[8]
        self.m32 = rowMajorValues[9]
        self.m33 = rowMajorValues[10]
        self.m34 = rowMajorValues[11]
        
        self.m41 = rowMajorValues[12]
        self.m42 = rowMajorValues[13]
        self.m43 = rowMajorValues[14]
        self.m44 = rowMajorValues[15]
    }
    
    public static let identity = Matrix4x4(rowMajorValues:[1.0, 0.0, 0.0, 0.0,
                                                                  0.0, 1.0, 0.0, 0.0,
                                                                  0.0, 0.0, 1.0, 0.0,
                                                                  0.0, 0.0, 0.0, 1.0])
}

public struct Matrix {
    var m: [Float]
    
    public init() {
        m = [1, 0, 0, 0,
             0, 1, 0, 0,
             0, 0, 1, 0,
             0, 0, 0, 1
        ]
    }
    
    mutating public func translation(_ position: SIMD3<Float>) {
        m[12] = position.x
        m[13] = position.y
        m[14] = position.z
    }
    
    mutating public func scaling(_ scale: Float) {
        m[0] = scale
        m[5] = scale
        m[10] = scale
        m[15] = 1.0
    }
    
    mutating func rotationMatrix(_ rot: SIMD3<Float>) {
        m[0] = cos(rot.y) * cos(rot.z)
        m[4] = cos(rot.z) * sin(rot.x) * sin(rot.y) - cos(rot.x) * sin(rot.z)
        m[8] = cos(rot.x) * cos(rot.z) * sin(rot.y) + sin(rot.x) * sin(rot.z)
        m[1] = cos(rot.y) * sin(rot.z)
        m[5] = cos(rot.x) * cos(rot.z) + sin(rot.x) * sin(rot.y) * sin(rot.z)
        m[9] = -cos(rot.z) * sin(rot.x) + cos(rot.x) * sin(rot.y) * sin(rot.z)
        m[2] = -sin(rot.y)
        m[6] = cos(rot.y) * sin(rot.x)
        m[10] = cos(rot.x) * cos(rot.y)
        m[15] = 1.0
    }
}
