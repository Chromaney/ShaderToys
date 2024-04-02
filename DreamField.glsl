// Shader "Dream Field" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A combination of Perlin noise, color-changing texture and "low-bit" effects.
// Dithering was designed to look more "structured" compared to Bayer matrix.

// --------------------------------

// [Common]

#define M_PI 3.1415926536

// [BufferA]

// Buffer for Perlin noise.

vec4 hash2to4(vec2 coord){
    vec4 col = vec4(0.0);
    uint k = 835171995U;
    uint a = uint(coord.x + 123.0);
    uint b = uint(coord.y + 456.0);

    uvec4 res = uvec4(a + k, b + k, a * b, k);
    res = (res.zxwy * k + res.ywxz) ^ res.w;
    res = (res.zxwy * k + res.ywxz) ^ res.z;
    res = (res.zxwy * k + res.ywxz) ^ res.y;
    res = (res.zxwy * k + res.ywxz) ^ res.x;

    col = vec4(res.xyzw) / float(0xffffffffU);
    return col;
}

vec4 blendFcn(vec4 a, vec4 b, float t){
    //return (a + (b - a) * smoothstep(0.0, 1.0, t));
    return ((b - a) * ((t * (t * 6.0 - 15.0) + 10.0) * t * t * t) + a);
}

vec4 perlinNoise(vec2 coord, float scale){
    vec2 intCoord = floor(coord / scale);
    vec2 fracCoord = mod(coord, vec2(scale)) / scale;
    
    vec4 rand00 = hash2to4(intCoord + vec2(0.0, 0.0));
    vec4 rand01 = hash2to4(intCoord + vec2(0.0, 1.0));
    vec4 rand10 = hash2to4(intCoord + vec2(1.0, 0.0));
    vec4 rand11 = hash2to4(intCoord + vec2(1.0, 1.0));
    
    vec2 dir00 = fracCoord - vec2(0.0, 0.0);
    vec2 dir01 = fracCoord - vec2(0.0, 1.0);
    vec2 dir10 = fracCoord - vec2(1.0, 0.0);
    vec2 dir11 = fracCoord - vec2(1.0, 1.0);
    
    vec4 val00 = mat2x4(cos(2.0 * M_PI * rand00), sin(2.0 * M_PI * rand00)) * dir00;
    vec4 val01 = mat2x4(cos(2.0 * M_PI * rand01), sin(2.0 * M_PI * rand01)) * dir01;
    vec4 val10 = mat2x4(cos(2.0 * M_PI * rand10), sin(2.0 * M_PI * rand10)) * dir10;
    vec4 val11 = mat2x4(cos(2.0 * M_PI * rand11), sin(2.0 * M_PI * rand11)) * dir11;
    
    vec4 val0x = blendFcn(val00, val01, fracCoord.y);
    vec4 val1x = blendFcn(val10, val11, fracCoord.y);
    vec4 valxx = blendFcn(val0x, val1x, fracCoord.x);
    
    return valxx;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    
    vec4 col = vec4(0.0);
    float baseLenScale = 128.0;
    float amplScale = 1.0;
    vec2 sampleCoord = fragCoord;
    mat2 sampleCoordTf = mat2(2.0, 0.0, 0.0, 2.0) * mat2(0.0, 1.0, -1.0, 0.0);
    for (int i = 0; i < 4; i ++){
        vec4 staticNoise = vec4(perlinNoise(sampleCoord, baseLenScale));
        vec4 dynNoise = vec4(perlinNoise(
            sampleCoord + vec2(1.0, 1.0) * 10.0 * iTime, baseLenScale));
        col += amplScale * vec4(staticNoise.xy, dynNoise.zw);
        sampleCoord = sampleCoordTf * sampleCoord;
        amplScale /= 2.0;
    }
    col = 0.5 + 0.5 * col;
    fragColor = col;
}

// [BufferB]
// [iChannel0: BufferA, filter = linear, wrap = clamp]

// Buffer for color-changing texture.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    vec2 pos = mod(texture(iChannel0, uv).xy + texture(iChannel0, uv).zw, 1.0);
    
    float scaledTime = 0.02 * iTime;
    vec3 colX = 0.5 + 0.5 * cos(2.0 * M_PI * 
        (pos.x + vec3(1.01, 1.12, 1.23) * 1.015 * scaledTime + vec3(0.2, 0.5, 0.8)));
    vec3 colY = 0.5 + 0.5 * cos(2.0 * M_PI * 
        (pos.y + vec3(1.17, 1.34, 1.09) * 1.000 * scaledTime + vec3(0.3, 0.6, 0.0)));
    colX *= sin(M_PI * pos.x);
    colY *= sin(M_PI * pos.y);
    vec3 col = colX + colY - colX * colY;
    
    fragColor = vec4(col, 1.0);
}

// [Image]
// [iChannel0: BufferB, filter = linear, wrap = clamp]

// Main effect code.

float flip16(float x){
    x = mod(x, 16.0);
    float res = 0.0;
    float mult = 8.0;
    for (int i = 0; i < 4; i ++){
        res += mult * mod(x, 2.0);
        x = floor(x / 2.0);
        mult /= 2.0;
    }
    return res;
}

float flip256(float x){
    x = mod(x, 256.0);
    float res = 0.0;
    float mult = 128.0;
    for (int i = 0; i < 8; i ++){
        res += mult * mod(x, 2.0);
        x = floor(x / 2.0);
        mult /= 2.0;
    }
    return res;
}

float maskPattern(float x, float y){
    float xm = mod(x, 16.0);
    float ym = mod(mod(y, 16.0) + xm, 16.0);
    float val = flip256(flip16(15.0 + flip16(ym) + xm) * 16.0 + flip16(flip16(xm) + ym));
    return (val / (256.0 - 1.0));
}

float maskCoeff(float x, float y){
    float val1 = maskPattern(x, y);
    float val2 = maskPattern(y, x);
    
    float val = val1 + val2 - 2.0 * val1 * val2;
    return val;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    
    float fcScale = 4.0;
    vec2 roughCoordInt = floor(fragCoord / fcScale);
    vec2 roughCoord = roughCoordInt * fcScale / iResolution.xy;
    
    vec3 col = texture(iChannel0, roughCoord).xyz;
    
    float discrCoeff = 4.0;
    float mask = maskCoeff(roughCoordInt.x, roughCoordInt.y);
    
    col += (mask - 0.5) / discrCoeff;
    col = floor(col * discrCoeff) / (discrCoeff - 1.0);
    
    fragColor = vec4(pow(col, vec3(1.0 / 1.0)), 1.0);
}
