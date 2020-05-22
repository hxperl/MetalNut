//
//  ResizeFilter.metal
//  MetalNut
//
//  Created by Geonseok Lee on 2019/12/10.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void resizeKernel(texture2d<half, access::write> outputTexture [[texture(0)]],
                         texture2d<half, access::sample> inputTexture [[texture(1)]],
                         constant float2 *size [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    if ((gid.x >= outputTexture.get_width()) || (gid.y >= outputTexture.get_height())) { return; }
    
    constexpr sampler quadSampler;
    const half4 outColor = inputTexture.sample(quadSampler, float2(float(gid.x) / outputTexture.get_width(), float(gid.y) / outputTexture.get_height()));
    outputTexture.write(outColor, gid);
}
