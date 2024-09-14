// Shader "Between Order and Chaos" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A shader born out of desire to try something CA/WFC-inspired.
// But then it took on a life of its own, lol.
// Uses classic "noise -> memory buffer -> output processing" pipeline.
// This time - for a picture with moving parts of chaotic colors and orderly gradients.
// Commented out code lines are alternative/early versions of certain parts.

// --------------------------------

// [Common]

#define M_PI 3.1415926536

// [BufferA]

// 3D Perlin noise buffer.

vec3 hash3to3(vec3 coord){
    uint k = 835171995U;
    uvec3 res = uvec3(coord) + k;
    
    res = (res.zxy * k + res.yzx) ^ res.z;
    res = (res.zxy * k + res.yzx) ^ res.y;
    res = (res.zxy * k + res.yzx) ^ res.x;
    
    return (vec3(res.xyz) / float(0xffffffffU));
}

vec3 blendFcn(vec3 t){
    return (t * t * t * (t * (t * 6.0 - 15.0) + 10.0));
}

float perlinNoise(vec3 coord, float scale){
    vec3 intCoord = floor(coord);
    vec3 fracCoord = fract(coord);
    vec3 blendVals = blendFcn(fracCoord);
    
    vec3 intCoordPlus = intCoord + vec3(1.0, 1.0, 1.0);
    vec3 modVec = vec3(scale);
    intCoord = mod(intCoord, modVec);
    intCoordPlus = mod(intCoordPlus, modVec);
    
    vec2 r000 = hash3to3(vec3(intCoord.x,     intCoord.y,     intCoord.z    )).xy;
    vec2 r001 = hash3to3(vec3(intCoord.x,     intCoord.y,     intCoordPlus.z)).xy;
    vec2 r010 = hash3to3(vec3(intCoord.x,     intCoordPlus.y, intCoord.z    )).xy;
    vec2 r011 = hash3to3(vec3(intCoord.x,     intCoordPlus.y, intCoordPlus.z)).xy;
    vec2 r100 = hash3to3(vec3(intCoordPlus.x, intCoord.y,     intCoord.z    )).xy;
    vec2 r101 = hash3to3(vec3(intCoordPlus.x, intCoord.y,     intCoordPlus.z)).xy;
    vec2 r110 = hash3to3(vec3(intCoordPlus.x, intCoordPlus.y, intCoord.z    )).xy;
    vec2 r111 = hash3to3(vec3(intCoordPlus.x, intCoordPlus.y, intCoordPlus.z)).xy;
    
    r000 = vec2((r000.x - 0.5) * M_PI, r000.y * 2.0 * M_PI);
    r001 = vec2((r001.x - 0.5) * M_PI, r001.y * 2.0 * M_PI);
    r010 = vec2((r010.x - 0.5) * M_PI, r010.y * 2.0 * M_PI);
    r011 = vec2((r011.x - 0.5) * M_PI, r011.y * 2.0 * M_PI);
    r100 = vec2((r100.x - 0.5) * M_PI, r100.y * 2.0 * M_PI);
    r101 = vec2((r101.x - 0.5) * M_PI, r101.y * 2.0 * M_PI);
    r110 = vec2((r110.x - 0.5) * M_PI, r110.y * 2.0 * M_PI);
    r111 = vec2((r111.x - 0.5) * M_PI, r111.y * 2.0 * M_PI);
    
    vec3 grad000 = vec3(cos(r000.x) * cos(r000.y), sin(r000.x), cos(r000.x) * sin(r000.y));
    vec3 grad001 = vec3(cos(r001.x) * cos(r001.y), sin(r001.x), cos(r001.x) * sin(r001.y));
    vec3 grad010 = vec3(cos(r010.x) * cos(r010.y), sin(r010.x), cos(r010.x) * sin(r010.y));
    vec3 grad011 = vec3(cos(r011.x) * cos(r011.y), sin(r011.x), cos(r011.x) * sin(r011.y));
    vec3 grad100 = vec3(cos(r100.x) * cos(r100.y), sin(r100.x), cos(r100.x) * sin(r100.y));
    vec3 grad101 = vec3(cos(r101.x) * cos(r101.y), sin(r101.x), cos(r101.x) * sin(r101.y));
    vec3 grad110 = vec3(cos(r110.x) * cos(r110.y), sin(r110.x), cos(r110.x) * sin(r110.y));
    vec3 grad111 = vec3(cos(r111.x) * cos(r111.y), sin(r111.x), cos(r111.x) * sin(r111.y));
    
    vec3 dir000 = fracCoord - vec3(0.0, 0.0, 0.0);
    vec3 dir001 = fracCoord - vec3(0.0, 0.0, 1.0);
    vec3 dir010 = fracCoord - vec3(0.0, 1.0, 0.0);
    vec3 dir011 = fracCoord - vec3(0.0, 1.0, 1.0);
    vec3 dir100 = fracCoord - vec3(1.0, 0.0, 0.0);
    vec3 dir101 = fracCoord - vec3(1.0, 0.0, 1.0);
    vec3 dir110 = fracCoord - vec3(1.0, 1.0, 0.0);
    vec3 dir111 = fracCoord - vec3(1.0, 1.0, 1.0);
    
    float val000 = dot(grad000, dir000);
    float val001 = dot(grad001, dir001);
    float val010 = dot(grad010, dir010);
    float val011 = dot(grad011, dir011);
    float val100 = dot(grad100, dir100);
    float val101 = dot(grad101, dir101);
    float val110 = dot(grad110, dir110);
    float val111 = dot(grad111, dir111);
    
    float k_1 = val000;
    float k_x = val100 - val000;
    float k_y = val010 - val000;
    float k_z = val001 - val000;
    float k_xy = val110 - val100 - val010 + val000;
    float k_xz = val101 - val100 - val001 + val000;
    float k_yz = val011 - val010 - val001 + val000;
    float k_xyz = val111 - val110 - val101 - val011 + val100 + val010 + val001 - val000;
    
    float val = 1.0 * k_1 + blendVals.x * k_x + blendVals.y * k_y + blendVals.z * k_z + 
        blendVals.x * blendVals.y * k_xy + blendVals.x * blendVals.z * k_xz + 
            blendVals.y * blendVals.z * k_yz + 
        blendVals.x * blendVals.y * blendVals.z * k_xyz;
    
    return val;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    
    vec3 col = vec3(0.0);
    float baseLenScale = 128.0;
    float amplScale = 1.0;
    vec3 sampleCoord = vec3(uv, iTime * 0.03178);
    float distScale = 1.0;
    
    for (int i = 0; i < int(ceil(log2(max(iResolution.x, iResolution.y)))); i ++){
        vec3 curSampleCoord = sampleCoord;
        vec3 curNoise = vec3(perlinNoise(1.0 - curSampleCoord, distScale));
        // ^ (1.0 - coord) is fixing very obvious vertical "RNG" pattern
        col += amplScale * curNoise;
        sampleCoord = 2.0 * sampleCoord;
        amplScale /= 2.0;
        distScale *= 2.0;
    }
    col = 0.5 + 0.5 * col;
    col = smoothstep(0.0, 1.0, smoothstep(0.0, 1.0, col)); // exaggerate values
    fragColor = vec4(col, 1.0);
}

// [BufferB]
// [iChannel0: BufferA, filter = linear, wrap = repeat]
// [iChannel1: BufferB, filter = nearest, wrap = clamp]

// "Memory" and nearest-values processing buffer.

ivec2 wrapCoords(ivec2 coord){ // texture wrap mode darkens edges over time
    ivec2 iiRes = ivec2(iResolution.xy);
    if (coord.x < 0){
        coord.x += iiRes.x;
    }
    if (coord.x >= iiRes.x){
        coord.x -= iiRes.x;
    }
    if (coord.y < 0){
        coord.y += iiRes.y;
    }
    if (coord.y >= iiRes.y){
        coord.y -= iiRes.y;
    }
    return coord;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    float val, waveMax, bloom;
    if (iFrame == 0){
        val = texelFetch(iChannel0, ivec2(fragCoord - 0.5), 0).r;
        waveMax = 0.0;
        bloom = 0.0;
    } else {
        float pts[9];
        // potentially interesting things with different weights, but also very unstable
        const float diagWt = 1.0;
        const float edgeWt = 1.0;
        const float centWt = 1.0;
        float weights[9] = float[9](
            diagWt, edgeWt, diagWt, 
            edgeWt, centWt, edgeWt, 
            diagWt, edgeWt, diagWt
        );
        float baseVal = 0.0;
        float baseBloom = 0.0;
        float weightsSum = 0.0;
        float weightsMax = 0.0;
        float weightsMin = 1.0e6;
        
        for (int dx = -1; dx <= 1; dx ++){
            for (int dy = -1; dy <= 1; dy ++){
                int arrIdx = (dx + 1) * 3 + (dy + 1);
                pts[arrIdx] = 
                    texelFetch(iChannel1, wrapCoords(ivec2(fragCoord - 0.5) + ivec2(dx, dy)), 0).r;
                float curWeight = weights[arrIdx];
                weightsSum += curWeight;
                weightsMax = max(weightsMax, curWeight);
                if (curWeight > 0.0){
                    weightsMin = min(weightsMin, curWeight);
                }
                baseVal += curWeight * pts[arrIdx];
                baseBloom += curWeight * 
                    texelFetch(iChannel1, wrapCoords(ivec2(fragCoord - 0.5) + ivec2(dx, dy)), 0).b;
            }
        }
        baseVal /= weightsSum;
        baseBloom /= weightsSum;
        
        float minDiff = 1.0e6;
        for (int dx = -1; dx <= 1; dx ++){
            for (int dy = -1; dy <= 1; dy ++){
                int arrIdx = (dx + 1) * 3 + (dy + 1);
                float curWeight = weights[arrIdx];
                if ((dx != 0) || (dy != 0)) {
                    if (curWeight > 0.0){
                        //float curDiff = (pts[arrIdx] - baseVal) * curWeight / weightsMax;
                        float curDiff = (pts[arrIdx] - baseVal) * curWeight;
                        minDiff = (abs(minDiff) < abs(curDiff)) ? minDiff : curDiff;
                    }
                }
            }
        }
        
        float newRand = texelFetch(iChannel0, ivec2(fragCoord - 0.5), 0).r;
        float updDiffLim = (0.002 + 0.001 * sin(2.0 * M_PI * 100.0 * newRand)) * 1.5; // quick random
        //updDiffLim *= (1.0 - cos(2.0 * M_PI * iTime * 0.1)) / 2.0;
        
        /*float waveH = pow((1.0 + cos(2.0 * M_PI * (uv.x * 0.25 + iTime * 0.15 + 0.1))) / 2.0, 20.0);
        float waveV = pow((1.0 + cos(2.0 * M_PI * (uv.y * 0.25 + iTime * 0.15 + 0.1 + 0.5))) / 2.0, 20.0);
        waveMax = max(waveH * 1.0, waveV * 1.0);*/
        
        /*vec2 scale = iResolution.xy / max(iResolution.x, iResolution.y);
        float waveH = cos(2.0 * M_PI * (uv.x * 2.0 + cos(iTime * 0.25)) * scale.x);
        float waveV = cos(2.0 * M_PI * (uv.y * 2.0 + sin(iTime * 0.25)) * scale.y);
        waveMax = 0.5 + 0.5 * waveH * waveV * sin(iTime * 1.0);
        waveMax = smoothstep(0.0, 1.0, smoothstep(0.0, 1.0, waveMax));
        waveMax = pow(clamp(waveMax - 0.4, 0.0, 1.0) / (1.0 - 0.4), 1.0);*/
        
        vec2 scale = iResolution.xy / max(iResolution.x, iResolution.y);
        float t = iTime * 2.0 * M_PI * 0.015 + 0.1; // shift to better align pattern for 10 s
        vec2 pos1 = 1.3 * vec2(cos(t), sin(t));
        vec2 pos2 = 1.5 * vec2(sin(t * 0.83), cos(t * 0.83));
        float scale1 = 3.0 + 1.0 * cos(t * 0.94 + 0.50);
        float scale2 = 2.2 + 0.8 * sin(t * 1.07 + 0.87);
        float wave1 = cos(2.0 * M_PI * length((uv - pos1) * scale) * scale1);
        float wave2 = cos(2.0 * M_PI * length((uv - pos2) * scale) * scale2);
        waveMax = 0.5 + 0.5 * wave1 * wave2;
        waveMax = smoothstep(0.0, 1.0, smoothstep(0.0, 1.0, waveMax));
        waveMax = pow(clamp(waveMax - 0.4, 0.0, 1.0) / (1.0 - 0.4), 1.0);
        
        updDiffLim *= waveMax;
        if (abs(minDiff) > updDiffLim){
            val = mix(baseVal, baseVal + minDiff, 5.0);
            val = mix(val, newRand, 0.001);
        } else {
            val = pts[4];
        }
        
        float newBloom = max(abs(val - 0.5) - 0.5, 0.0);
        bloom = 0.9990 * baseBloom + newBloom;
    }
    fragColor = vec4(vec3(val, waveMax, bloom), 1.0);
}

// [Image]
// [iChannel0: BufferB, filter = nearest, wrap = clamp]

// Main image buffer.

vec3 palette(float c, float d, float t){
    c = clamp(c, 0.0, 1.0);
    c = pow(c, 1.0 + 0.75 * cos(M_PI * d));
    
    vec3 col1 = vec3(0.10, 0.40, 0.20);
    vec3 col2 = vec3(0.20, 0.60, 0.60);
    vec3 col3 = vec3(0.66, 1.00, 1.00);
    float pos2 = 0.65;
    
    t *= 2.0 * M_PI;
    float colCoeff = 0.85 + 0.15 * cos(t);
    col1 *= colCoeff;
    col2 *= colCoeff;
    col3 *= colCoeff;
    
    float c12 = c / pos2;
    float c23 = (c - pos2) / (1.0 - pos2);
    vec3 col = (c12 <= 1.0) ? mix(col1, col2, c12) : mix(col2, col3, c23);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    vec3 data = texture(iChannel0, uv).rgb;
    float bloom = data.b;
    vec2 modifCoord = uv;
    vec2 bloomGrad = vec2(dFdx(bloom), dFdy(bloom));
    if (length(bloomGrad) > 0.0){
        modifCoord += 0.03 * bloom * normalize(bloomGrad);
    }
    vec3 dataM = texture(iChannel0, modifCoord).rgb;
    
    vec3 col = palette(dataM.r, data.b, iTime * 0.07 + 0.3); // shift to better align palette for 10 s
    col *= min(iTime * 0.3, 1.0);
    float gamma = 1.0; // no gamma corr. - colors selected w/o it
    fragColor = vec4(pow(col, vec3(1.0 / gamma)), 1.0);
}
