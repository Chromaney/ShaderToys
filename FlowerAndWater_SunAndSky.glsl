// Shader "Flower and Water, Sun and Sky" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Didn't expect to get this much value out of a small smooth noise function.
// Started as an attempt to recreate this but then went its own direction: 
// https://scryfall.com/card/eoe/268/plains

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R (iResolution.xy)
#define EPS (1.0 / max(R.x, R.y))
#define T (iTime * 1.0)

#define SMST(x) smoothstep(0.0, 1.0, x)
#define rand(v) (fract(sin(dot(v, vec3(113.5, 271.9, 124.6))) * 43758.5453123))

mat2 rotMtx(float ang){
    float c = cos(ang), s = sin(ang);
    return mat2(c, s, -s, c);
}

vec4 smoothNoise(vec2 uv, float t, float n){
    float scale = 1.15;
    vec2 e = vec2(0.0);
    vec2 d = vec2(0.0);
    uv *= 3.0;
    for(float i = 0.0; i < n; i ++){
        uv = scale * (rotMtx(TAU * 0.427) * uv + vec2(2.27, -4.58));
        e += cos(TAU * uv + t + d.xy);
        d += cos(1.0 * uv + t + e.yx);
    }
    return (vec4(d, e) / n * 0.5 + 0.5);
}

vec4 circNoise(vec2 uv, float k, float t, float n){
    vec2 uvPol1 = vec2(length(uv) * 4.0, atan(uv.y, uv.x) / PI * 4.0);
    vec2 uv2 = uv * rotMtx(PI);
    vec2 uvPol2 = vec2(length(uv2) * 4.0, atan(uv2.y, uv2.x) / PI * 4.0) + vec2(100.0);
    
    vec4 curNoise1 = smoothNoise(uvPol1 * k, t, n);
    vec4 curNoise2 = smoothNoise(uvPol2 * k, t, n);
    
    float mixCoeffPre = abs(atan(uv.y, uv.x)) / PI;
    vec4 curNoise = mix(curNoise1, curNoise2, mixCoeffPre); // fixing seams
    return curNoise;
}

vec3 palette1(vec2 t){
    vec3 baseCol = mix(vec3(0.95, 0.70, 0.40), vec3(1.00, 0.75, 0.30), t.x);
    vec3 col = pow(baseCol, vec3((1.0 - t.y) * 2.0));
    return col;
}

vec3 palette2(vec2 t){
    vec3 baseCol = mix(vec3(0.30, 0.50, 0.60), vec3(0.50, 0.75, 0.80), t.x);
    vec3 col = pow(baseCol, vec3((1.0 - t.y) * 4.0));
    return col;
}

vec4 getSceneColor(vec2 uv){
    vec2 uv0 = uv;
    uv *= 1.5;
    vec2 uvLR = uv;
    
    vec2 uvNoiseCoord = uv * length(uv) * 3.0;
    uvNoiseCoord += vec2(-30.0);
    vec4 uvNoise = smoothNoise(uvNoiseCoord, T * 0.13, 3.0);
    
    float uvDisAng = (uvNoise.z - 0.5) * TAU * 1.0;
    vec2 uvDelta = 0.03 * (uvNoise.x * 2.0 - 1.0) * vec2(cos(uvDisAng), sin(uvDisAng));
    
    uv += uvDelta;
    
    vec2 uvLRNoiseCoord = uvLR / (length(uvLR) + 0.001) / 10.0;
    vec4 uvLRNoise = smoothNoise(uvLRNoiseCoord + vec2(40.0), T * 0.13, 3.0);
    
    float uvLRDisAng = (uvLRNoise.z - 0.5) * TAU * 1.0;
    vec2 uvLRDelta = 0.1 * (uvLRNoise.x * 2.0 - 1.0) * \
        vec2(cos(uvLRDisAng), sin(uvLRDisAng));
    uvLR += uvLRDelta;
    
    vec4 curNoise = circNoise(uv, 1.0, T * 0.5, 3.0);
    vec4 curNoiseC = smoothNoise(uv * 3.0, T * 0.43, 7.0);
    
    vec4 curNoiseLR = circNoise(uvLR, 0.2, T * 0.18, 1.0);
    vec4 curNoiseCLR = smoothNoise(uv * 2.0, T * 0.43, 3.0);
    
    float mixCoeff = pow(SMST(length(uv) * 8.0), 4.0);
    vec4 col = mix(curNoiseC, curNoise, mixCoeff);
    
    float mixCoeffLR = pow(SMST(length(uv) * 6.0), 8.0);
    vec4 colLR = mix(curNoiseCLR, curNoiseLR, mixCoeffLR);
    
    col *= mix(0.5, 2.0, abs(colLR.x - colLR.y));
    
    float palMixCoeff = (1.0 * sin(colLR.w * TAU) - 0.5 * cos(colLR.y * TAU)) / 3.0 + 0.5;
    palMixCoeff += (8.0 * abs(palMixCoeff - 0.5) * (colLR.x - 0.5) * (colLR.z - 0.5));
    palMixCoeff = SMST(SMST(palMixCoeff));
    palMixCoeff = pow(palMixCoeff, 0.04 / pow(length(uv0) + 0.001, 2.0));
    
    float detail = (0.5 * sin(colLR.x * TAU) + 1.0 * cos(colLR.z * TAU)) / 3.0 + 0.5;
    detail = pow(detail, 1.5);
    
    vec2 baseXY = vec2(colLR.x + colLR.y - 2.0 * colLR.x * colLR.y);
    vec3 col1 = palette1(mix(baseXY, col.xy, detail));
    vec3 col2 = palette2(mix(baseXY, col.yx, detail));
    vec3 newCol = mix(col1, col2, palMixCoeff);
    newCol += 0.3 * col1 * \
        smoothstep(1.0, 0.0, palMixCoeff) * (1.0 - smoothstep(1.0, 0.0, palMixCoeff));
    
    return vec4(newCol, 1.0);
}

void mainImage(out vec4 col, in vec2 pos){
    vec2 uv = (pos - R / 2.0) * EPS;
    col = getSceneColor(uv);
}
