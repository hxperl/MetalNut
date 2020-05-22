//
//  BrightnessFilter.metal
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/20.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void brightnessKernel(texture2d<half, access::write> outputTexture [[texture(0)]],
                             texture2d<half, access::read> inputTexture [[texture(1)]],
                             constant float *brightness [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    if ((gid.x >= outputTexture.get_width()) || (gid.y >= outputTexture.get_height())) { return; }
    
    const half4 inColor = inputTexture.read(gid);
    const half4 outColor(inColor.rgb + half3(*brightness), inColor.a);
    outputTexture.write(outColor, gid);
}
