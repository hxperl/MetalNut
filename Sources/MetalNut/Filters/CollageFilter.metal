//
//  CollageFilter.metal
//  MetalNut
//
//  Created by Geonseok Lee on 2020/01/23.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void collageKernel(texture2d<half, access::write> outputTexture [[texture(0)]],
					  texture2d<half, access::read> inputTexture [[texture(1)]],
					  texture2d<half, access::read> inputTexture2 [[texture(2)]],
					  uint2 gid [[thread_position_in_grid]]) {
 
	if ((gid.x >= outputTexture.get_width()) || (gid.y >= outputTexture.get_height())) { return; }

	half4 color = inputTexture.read(gid);
	half4 color2 = inputTexture2.read(gid);
	
	half4 result;

	if (color2.a == 0) {
		result = color;
	} else {
		result = color2;
	}

	outputTexture.write(result, gid);
}
