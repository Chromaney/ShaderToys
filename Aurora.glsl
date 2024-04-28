// Shader "2D Aurora" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A simple-ish 2D imitation of an aurora visuals.

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

vec3 blendFcn3(vec3 t){
    return (t * t * t * (t * (t * 6.0 - 15.0) + 10.0));
}

float perlinNoise3(vec3 coord, float scale){
    vec3 intCoord = floor(coord / scale);
    vec3 fracCoord = mod(coord, vec3(scale)) / scale;
    vec3 blendVals = blendFcn3(fracCoord);
    
    vec2 r000 = hash3to3(intCoord + vec3(0.0, 0.0, 0.0)).xy;
    vec2 r001 = hash3to3(intCoord + vec3(0.0, 0.0, 1.0)).xy;
    vec2 r010 = hash3to3(intCoord + vec3(0.0, 1.0, 0.0)).xy;
    vec2 r011 = hash3to3(intCoord + vec3(0.0, 1.0, 1.0)).xy;
    vec2 r100 = hash3to3(intCoord + vec3(1.0, 0.0, 0.0)).xy;
    vec2 r101 = hash3to3(intCoord + vec3(1.0, 0.0, 1.0)).xy;
    vec2 r110 = hash3to3(intCoord + vec3(1.0, 1.0, 0.0)).xy;
    vec2 r111 = hash3to3(intCoord + vec3(1.0, 1.0, 1.0)).xy;
    
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

float perlinNoise3Val(vec3 sampleCoord){
    float col = 0.0;
    float amplScale = 1.0;
    for (int i = 0; i < 6; i ++){
        float curNoise = perlinNoise3(sampleCoord, 1.0);
        col += amplScale * curNoise;
        sampleCoord = 2.0 * sampleCoord;
        amplScale /= 2.0;
    }
    col = 0.5 + 0.5 * col;
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    vec3 noiseCoord = vec3(uv, iTime * 0.03);
    fragColor = vec4(perlinNoise3Val(noiseCoord));
}

// [BufferB]
// [iChannel0: BufferB, filter = linear, wrap = clamp]
// [iChannel1: BufferA, filter = linear, wrap = clamp]

// "Memory" buffer.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    vec2 uv0 = uv - 0.5 / iResolution.xy;
    
    float minRes = 1.0 / max(iResolution.x, iResolution.y);
    
    if (iFrame == 0){
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        float rand1 = texture(iChannel1, uv).x;
        float rand2 = texture(iChannel1, fract(0.5 + (uv - 0.5) * rand1)).x;
        
        float limLo = 0.45;
        float limHi = 0.55;
        float spawnVal = rand1;
        spawnVal = smoothstep(limLo, limHi, spawnVal) * smoothstep(limHi, limLo, spawnVal) * 4.0;
        
        float dY = 1.0 * minRes;
        vec2 prevVal = vec2(0.0);
        if (uv0.y >= dY){
            prevVal = texture(iChannel0, vec2(uv.x + 5.0 * minRes * (rand2 - 0.5), uv0.y - dY)).xy;
        }
        
        vec2 curVal = prevVal - vec2(3.0 * minRes, 0.0);
        float blendCoeff = max((spawnVal - curVal.x) * 0.25, 0.0);
        
        fragColor = vec4(mix(curVal.x, spawnVal * (1.0 - 0.5 * uv.y), blendCoeff), rand2, 0.0, 1.0);
    }
}

// [Image]
// [iChannel0: BufferB, filter = linear, wrap = clamp]

// Main image buffer.

vec3 palette(float t){
    t = 3.5 * t - 1.0;
    vec3 amps = vec3(0.3, 0.9, 0.2);
    vec3 centers = vec3(1.0, 0.3, 0.7);
    vec3 widths = vec3(0.35, 0.20, 0.35);
    vec3 color = amps * exp(- pow((t - centers) / widths, vec3(2.0)) / 2.0);
    color.b += color.g * 0.1;
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    float minRes = 1.0 / max(iResolution.x, iResolution.y);
    
    vec2 inData = texture(iChannel0, uv).xy;
    vec3 color = palette(pow(1.0 - inData.x, (1.0 + 1.5 * (inData.y - 0.5))));
    
    vec2 grad = vec2(dFdx(inData.x), dFdy(inData.x)) * (0.0013 / minRes);
    float corrCoeff = smoothstep(-0.05, 0.0, -grad.y) * smoothstep(-0.01, 0.0, -length(grad));
    fragColor = vec4(color * corrCoeff, 1.0);
    
    fragColor = vec4(pow(fragColor.xyz, vec3(1.0 / 2.2)), 1.0);
}
