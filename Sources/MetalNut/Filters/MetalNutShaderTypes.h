//
//  MetalNutShaderTypes.h
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/10.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;

#ifndef MetalNutShaderTypes_h
#define MetalNutShaderTypes_h

#define M_PI 3.14159265358979323846264338327950288

// Luminance Constants

constant half3 kLuminanceWeighting = half3(0.2125, 0.7154, 0.0721); // Values from "Graphics Shaders: Theory and Practice" by Bailey and Cunningham

half lum(half3 c);

half3 clipcolor(half3 c);

half3 setlum(half3 c, half l);

half sat(half3 c);

half mid(half cmin, half cmid, half cmax, half s);

half3 setsat(half3 c, half s);

float mod(float x, float y);

float2 mod(float2 x, float2 y);

struct SingleInputVertexIO
{
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
};

struct TwoInputVertexIO
{
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
    float2 textureCoordinate2 [[user(texturecoord2)]];
};

struct Uniform {
	float4x4 modelMatrix;
};

#endif /* MetalNutShaderTypes_h */
