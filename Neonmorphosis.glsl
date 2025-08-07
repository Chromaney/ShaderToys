// Shader "Neonmorphosis" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Experimenting with pathtraced lighting. 2D case for simplicity.

// Probably possible to achieve same visuals way faster with a different approach.
// Removing randomness in ray initializations or increasing raymarching tolerance 
// causes interesting effects but this wasn't the idea.

// --------------------------------

// [Common]

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R iResolution

#define rand(v) (fract(sin(dot(v, vec3(113.5, 271.9, 124.6))) * 43758.5453123))

mat2 rotMtx(float ang){
    float cosAng = cos(ang);
    float sinAng = sin(ang);
    return mat2(cosAng, -sinAng, sinAng, cosAng); // applied from right
}

vec3 colFromHue(float h){
    return clamp(abs(fract(h - vec3(0.0, 1.0, 2.0) / 3.0) - 1.0 / 2.0) * 6.0 - 1.0, 0.0, 1.0);
}

float gyroid(vec3 pos, vec2 period){
    return dot(sin(pos * period.x), cos(pos.zxy * period.y));
}

// [BufferA]

// SDF storage buffer to reduce calculations in the main image buffer.

vec3 sceneSDF(vec2 pos){
    pos *= 0.3;
    float t = iTime * 0.025;
    
    // complicating gyroid patterns
    vec3 gPos = vec3(pos + 0.2 * cos(pos * 0.3 + t * 0.08), 
        0.5 * sin(t * 0.15 + 1.79));
    gPos.xy *= rotMtx(t * 0.23);
    gPos.yz *= rotMtx(t * -0.32);
    float g1 = gyroid(gPos, vec2(10.0)) / 1.5; // -1 to +1
    gPos += gPos.zxy;
    gPos.zx *= rotMtx(t * 0.17);
    gPos.yx *= rotMtx(t * -0.28);
    float g2 = gyroid(gPos, vec2(29.0)) / 1.5; // -1 to +1
    float g = (g1 + g2) / 2.0; // -1 to +1
    g = fract(g); // 2x folded 0 to 1
    
    // "periodic" SDFs
    float solidTresh = 5.0 / 6.0;
    float solidRange = 1.0 / 6.0;
    float solid = min(abs(g - solidTresh + 0.0) - solidRange, 
                  min(abs(g - solidTresh - 1.0) - solidRange, 
                      abs(g - solidTresh + 1.0) - solidRange));
    
    float lightTresh = 0.4;
    float lightRange = 0.01;
    float light = min(abs(g - lightTresh + 0.0) - lightRange, 
                  min(abs(g - lightTresh - 1.0) - lightRange, 
                      abs(g - lightTresh + 1.0) - lightRange));
    
    vec3 res = vec3(solid, 1.0, (gPos.x + gPos.y + gPos.z) * 0.5);
    if (res.x > light)
        res.xy = vec2(light, 2.0);
    return res;
}

void mainImage(out vec4 col, in vec2 pos){
    // same coords as in the main image, 
    // but enlarged area to be able to sample into extra "outside" area
    // synced coords (1)
    pos = (pos - R.xy / 2.0) / min(R.x, R.y) * 1.618;
    col = vec4(sceneSDF(pos), 0.0);
}

// [BufferB]
// [iChannel0: BufferB, filter = linear, wrap = clamp]
// [iChannel1: BufferA, filter = linear, wrap = clamp]

// Main image and smoothing buffer.

#define RM_MAX_ITER 20.0
#define RM_MAX_DIST 0.5
#define RM_PROX_DIST 0.01
#define RM_RAY_COUNT 25.0

vec3 sceneSDF(vec2 pos){
    // sampling from SDF texture, linear interpolation seems sufficient
    // synced coords (2)
    return texture(iChannel1, pos / 1.618 / (R.xy / min(R.x, R.y)) + 0.5).xyz;
}

vec3 rayMarch(vec2 orig, vec2 dir){
    float dist = 0.0;
    float startInsideLen = 0.0;
    float wasOut = 0.0;
    vec3 accumLight = vec3(0.0);
    
    for (float iter = 0.0; iter < RM_MAX_ITER; iter += 1.0){
        vec2 pos = orig + dir * dist;
        vec3 sceneDistFieldRes = sceneSDF(pos);
        float curStep = sceneDistFieldRes.x;
        float curObjType = sceneDistFieldRes.y;
        float curHue = sceneDistFieldRes.z;
        
        // update on ray leaving solid
        if (((curStep > 0.0) || (curObjType > 1.5)) && (wasOut < 0.5))
            wasOut = 1.0;
        
        // fixing too small steps
        curStep = (step(0.0, curStep) * 2.0 - 1.0) * \
            max(abs(curStep), 0.9 * RM_PROX_DIST);
        
        vec3 light = 0.35 * mix(vec3(1.0), colFromHue(curHue), 0.9) * \
            step(1.5, curObjType) * step(curStep, 0.0);
        accumLight += light / max(dist, 0.05);
        
        // initially inside solid - for lighting edges
        startInsideLen += abs(curStep) * \
            step(wasOut, 0.5) * step(curObjType, 1.5) * step(curStep, 0.0);
        
        dist += abs(curStep);
        
        // stop on reentering solid
        if ((wasOut > 0.5) && (curObjType < 1.5) && (curStep < -1.0 * RM_PROX_DIST))
            break;
        
        if (dist > RM_MAX_DIST)
            break;
    }
    
    // edge "lighting"
    accumLight *= exp(-50.0 * startInsideLen) * ((startInsideLen > 0.0) ? 25.0 : 1.0);
    return accumLight;
}

void mainImage(out vec4 col, in vec2 pos){
    vec4 prevCol;
    if (iFrame == 0){ // "memory"
        prevCol = vec4(0.0);
    } else {
        prevCol = texelFetch(iChannel0, ivec2(pos), 0);
    }
    
    pos = (pos - R.xy / 2.0) / min(R.x, R.y); // synced coords (3)
    vec4 colAccum = vec4(0.0);

    for (float ray = 0.0; ray < RM_RAY_COUNT; ray += 1.0){ // simple pathtracing
        float randVal = rand(vec3(pos, iTime));
        float randVals[4] = float[4](
            rand(vec3(pos.x, pos.y + ray, iTime)), 
            rand(vec3(pos.y, pos.x + iTime, ray)), 
            rand(vec3(iTime + ray, pos.x, pos.y)), 
            rand(vec3(pos.y + iTime, ray, pos.x))
        );
        
        // randomize sampling position (for spatial smoothing)
        vec2 curPos = pos + 0.5 / min(R.x, R.y) * vec2(randVals[0], randVals[1]);
        // randomized sampling angle (base + deviation) (for spatial smoothing)
        float curAng = TAU * \
            ((ray + 0.5 * randVals[3] - 0.25) / (RM_RAY_COUNT - 1.0) + randVals[2]);
        vec2 curDir = vec2(cos(curAng), sin(curAng));
        colAccum.xyz += rayMarch(curPos, curDir) / RM_RAY_COUNT;
    }
    
    colAccum = log2(1.0 + colAccum); // range flattening
    // time-domain smoothing, dependent on image "speed"
    col = mix(colAccum, prevCol, 0.9);
}

// [Image]
// [iChannel0: BufferB, filter = linear, wrap = clamp]

// Output.

void mainImage(out vec4 col, in vec2 pos){
    col = texelFetch(iChannel0, ivec2(pos), 0);
}
