//
//  FlipFilter.metal
//  MetalNut
//
//  Created by 김지수 on 2020/01/29.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void flipKernel(texture2d<half, access::write> outputTexture [[texture(0)]],
                       texture2d<half, access::read> inputTexture [[texture(1)]],
                       constant bool *horizontal [[buffer(0)]],
                       constant bool *vertical [[buffer(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    
    if ((gid.x >= outputTexture.get_width()) || (gid.y >= outputTexture.get_height())) { return; }
    
    const uint x = bool(*horizontal) ? inputTexture.get_width() - 1 - gid.x : gid.x;
    const uint y = bool(*vertical) ? inputTexture.get_height() - 1 - gid.y : gid.y;
    
    const half4 outColor = inputTexture.read(uint2(x, y));
    outputTexture.write(outColor, gid);
}
