// Shader "Unlocked Box" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Combining see-through "4D" rendering of a tesseract with a Menger-like fractal.
// Initially inspired by a lyric by an obscure band, 
// but then evolved into something else.

// --------------------------------

// [Common]

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R (iResolution.xy)
#define EPS (1.0 / max(R.x, R.y))
#define T (iTime * 1.0)

mat2 rotMtx(float ang){
    float c = cos(ang), s = sin(ang);
    return mat2(c, s, -s, c);
}

float boxDist2(vec2 pos, float sz){
    vec2 posM = abs(pos) - sz;
    float d = length(max(posM, 0.0));
    d += min(max(posM.x, posM.y), 0.0);
    return d;
}

float boxDist3(vec3 pos, float sz){
    vec3 posM = abs(pos) - sz;
    float d = length(max(posM, 0.0));
    d += min(max(posM.x, max(posM.y, posM.z)), 0.0);
    return d;
}

float boxDist4(vec4 pos, float sz){
    vec4 posM = abs(pos) - sz;
    float d = length(max(posM, 0.0));
    d += min(max(posM.x, max(posM.y, max(posM.z, posM.w))), 0.0);
    return d;
}

float opSub(float d1, float d2){
    return max(d1, -d2);
}

// [Image]

// raymarching iterations
#define RM_MAX_ITER 100.0
// raymarching distance limit
#define RM_MAX_DIST 10.0
// raymarching proximity distance (or minimal step size)
#define RM_PROX_DIST 0.03

// cube size
#define CUBE_SZ 1.0
// range to sweep in W dimension
#define SWEEP_SZ (length(vec4(CUBE_SZ)))
// layers to render in W dimension
#define N_STEPS_W 5.0

// removing squares (0) or cubes (1)
#define SUB_TYPE 0
// menger iterations
#define SUB_NUM 1

void setCamera(vec2 uv, float layer, out vec4 orig, out vec4 dir){
    vec2 mousePos = iMouse.xy;
    if (iMouse.z == 0.0){
        mousePos = vec2(0.5, 0.5) * R;
    }
    
    float t = 0.2 * iTime;
    mat2 rotXY = rotMtx(- t * 0.11 * TAU);
    mat2 rotYZ = rotMtx(- t * 0.13 * TAU);
    mat2 rotZW = rotMtx(- t * 0.17 * TAU);
    mat2 rotXZ = rotMtx(- t * 0.19 * TAU);
    mat2 rotYW = rotMtx(- t * 0.23 * TAU);
    mat2 rotXW = rotMtx(- t * 0.29 * TAU);
    
    orig = vec4(0.0, 0.0, -5.0, layer);
    dir = normalize(vec4(uv, 1.0, 0.0));
    
    orig.xy = rotXY * orig.xy;
    orig.yz = rotYZ * orig.yz;
    orig.zw = rotZW * orig.zw;
    orig.xz = rotXZ * orig.xz;
    orig.yw = rotYW * orig.yw;
    orig.xw = rotXW * orig.xw;
    
    dir.xy = rotXY * dir.xy;
    dir.yz = rotYZ * dir.yz;
    dir.zw = rotZW * dir.zw;
    dir.xz = rotXZ * dir.xz;
    dir.yw = rotYW * dir.yw;
    dir.xw = rotXW * dir.xw;
}

#if (SUB_TYPE == 0)
float crossDist4(vec4 pos, float sz){
    float d = boxDist2(pos.xy, sz);
    d = min(d, boxDist2(pos.xz, sz));
    d = min(d, boxDist2(pos.xw, sz));
    d = min(d, boxDist2(pos.yz, sz));
    d = min(d, boxDist2(pos.yw, sz));
    d = min(d, boxDist2(pos.zw, sz));
    return d;
}
#endif

#if (SUB_TYPE == 1)
float crossDist4(vec4 pos, float sz){
    float d = boxDist3(pos.xyz, sz);
    d = min(d, boxDist3(pos.xyw, sz));
    d = min(d, boxDist3(pos.xzw, sz));
    d = min(d, boxDist3(pos.yzw, sz));
    return d;
}
#endif

float sceneDistField(vec4 pos){
    float d = boxDist4(pos, CUBE_SZ);
    float subSz = CUBE_SZ / 3.0;
    d = opSub(d, crossDist4(pos, subSz));
    
    for (int i = 1; i <= SUB_NUM; i ++){
        pos = mod(pos + subSz, 2.0 * subSz) - subSz;
        subSz /= 3.0;
        d = opSub(d, crossDist4(pos, subSz) / 3.0);
    }
    
    return d;
}

vec4 rayMarch(in vec4 orig, in vec4 dir, 
    out float dist, out float iter, out vec3 accumLight){
    
    accumLight = vec3(0.0);
    
    iter = 0.0;
    dist = 0.0;
    vec4 pos = orig;
    float curStep = 0.0;
    for (; (iter < RM_MAX_ITER) && (dist <= RM_MAX_DIST); iter += 1.0){
        curStep = sceneDistField(pos);
        bool addLight = (curStep < 0.0);
        curStep = abs(curStep);
        curStep = max(curStep, RM_PROX_DIST); // increase small steps
        
        if (addLight){
            float baseVal = curStep / (2.0 * CUBE_SZ);
            vec4 colCoord = pos * PI;
            accumLight += baseVal * \
                vec3(0.5 + 1.0 * sin(colCoord.x), \
                     0.5 + 1.0 * sin(colCoord.y) * sin(colCoord.w), \
                     0.5 + 1.0 * sin(colCoord.z) * cos(colCoord.w));
        }
        
        dist += curStep;
        pos += dir * curStep;
    }
    
    return pos;
}

void mainImage(out vec4 col, in vec2 pos){
    vec2 uv = (pos - R / 2.0) * EPS;
    
    vec3 curCol = vec3(0.0), prevCol = vec3(0.0);
    float lStep = 2.0 * SWEEP_SZ / N_STEPS_W;
    for (float layer = -SWEEP_SZ; layer <= SWEEP_SZ; layer += lStep){
        vec4 camPos, rayDir;
        setCamera(uv, layer, camPos, rayDir);
        float dist, iter;
        vec3 nextCol;
        vec4 rmRes;
        rmRes = rayMarch(camPos, rayDir, dist, iter, nextCol);
        curCol += mix(prevCol, nextCol, 0.5);
        prevCol = nextCol;
    }
    
#if (SUB_TYPE == 0)
    float colorScale = 10.0;
#endif

#if (SUB_TYPE == 1)
    float colorScale = 7.0;
#endif
    
    col.rgb = tanh(curCol / (N_STEPS_W + 1.0) * colorScale);
    col.w = 1.0;
}
