// Shader "K-Scope 3000" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Just wanted to do something fun and colorful, 
// and remembered wanting to make a kaleidoscope.
// Use mouse to change patterns.

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R (iResolution.xy)
#define EPS (1.0 / max(R.x, R.y))
#define T (iTime * 1.0)

vec3 rand33(vec3 x){
    return fract(sin(x * \
        mat3(127.1, 311.7, 74.7, 269.5, 183.3, 246.1, 113.5, 271.9, 124.6)) * \
        43758.5453123);
}

mat2 rotMtx(float ang){
    float c = cos(ang), s = sin(ang);
    return mat2(c, s, -s, c);
}

vec3 colFromHue(float h){
    return clamp(abs(6.0 * fract(h - vec3(0.0, 1.0, 2.0) / 3.0) - 3.0) - 1.0, 0.0, 1.0);
}

float distPoly(vec2 pt, float n, float r0, float a0){
    //improved approach from here: https://www.shadertoy.com/view/MtKcWW
    float ap = mod(atan(pt.y, pt.x) - a0, TAU / n) - PI / n;
    pt = length(pt) * vec2(cos(ap), sin(ap));
    
    vec2 pm = r0 * vec2(cos(PI / n), sin(PI / n));
    pm = vec2(pm.x, clamp(pt.y, -pm.y, pm.y));
    
    return (length(pm - pt) * sign(pt.x - pm.x));
}

vec3 layer(vec2 uv){
    vec2 cell = floor(uv);
    if (mod(cell.y, 2.0) > 0.5){ // hexagonal grid
        uv.x += 0.5;
        cell = floor(uv);
    }
    uv = fract(uv) - 0.5;
    
    vec3 cellRand = rand33(vec3(cell, 1.0));
    vec3 cellRand2 = fract(cellRand * 43758.5453123); // bad "random" for performance
    
    float randEps = 1.0e-5;
    float nSidesPre = cellRand.x * (5.0 + 1.0 - randEps) + 3.0 + randEps;
    float nSides = floor(nSidesPre);
    float sz = 0.25 * cellRand.y + 0.25;
    float ang = cellRand.z * TAU;
    float dist = distPoly(uv, nSides, sz, ang);
    // show inside and only some polygons
    float sel = step(dist, 0.0) * step(0.5, fract(nSidesPre));
    
    vec3 cellCol = \
        colFromHue(cellRand2.y + T * (2.0 * cellRand2.z - 1.0) * 0.1) * 0.9 + 0.1;
    float colExp = 2.0 * cellRand2.x - 1.0;
    colExp *= (colExp > 0.0) ? 8.0 : 2.0;
    cellCol = (cellCol + 0.5) * exp(dist / sz * colExp);
    
    return (sel * cellCol);
}

vec3 pattern(vec2 uv, float majShift, float minShift, float uvScale){
    vec3 accCol = vec3(0.0);
    uv *= 0.3 / uvScale;
    majShift /= uvScale;
    minShift /= uvScale;
    float scale = 1.43;
    float nIter = 7.0;
    float normMul = 0.0;
    for(float i = -1.0; i < nIter; i += 1.0){
        uv = scale * rotMtx(0.43 * TAU + majShift * 0.005) * uv + \
            vec2(103.7, -264.9) + vec2(sin(minShift), cos(minShift)) * 2.0;
        vec3 curCol = layer(uv);
        float curMul = pow(scale, -i / 4.0);
        if (i >= 0.0){
            accCol += curCol * curMul;
            normMul += curMul;
        }
    }
    accCol /= normMul;
    accCol = smoothstep(0.0, 0.67 + 0.33 / uvScale, accCol) * 6.0;
    return accCol;
}

// calculate barycentric coordinates
// triangle orientation is variable
vec3 triang(in vec2 p, out float type, out float triType){
    // base triangle axes (as coefficients in ax + by = 0), normalized
    vec2 b1 = vec2(0.0, 1.0);
    vec2 b2 = vec2(sqrt(3.0), -1.0) / 2.0;
    vec2 b3 = vec2(sqrt(3.0), 1.0) / 2.0;
    // trilinear coordinates, c.z == c.x + c.y
    vec3 c = vec3(dot(p, b1), dot(p, b2), dot(p, b3));
    vec3 ci = floor(c);
    
    type = mod(ci.x + ci.y + ci.z, 2.0); // triangle orientation (^ or v)
    triType = mod(dot(ci, vec3(2.0 - type, 0.0, 2.0 - type)), 3.0);
    
    c -= ci;
    c.z = 1.0 - c.z;
    if (type > 0.5)
        c = 1.0 - c;
    
    return c;
}

vec3 imgCol(vec2 pos){
    vec2 uv = (pos - R / 2.0) * EPS;
    vec2 mousePos = iMouse.xy / R;
    if (iMouse.z == 0.0){
        mousePos = vec2(0.95, 0.9);
    }
    
    float type, triType;
    vec3 uvwTriang = triang(uv * 6.0, type, triType);
    for (float tt = 0.0; tt < triType; tt ++)
        uvwTriang = uvwTriang.zxy;
    if (type > 0.5)
        uvwTriang.xz = uvwTriang.zx;
    
    vec2 v1 = vec2(1.0, 0.0), \
         v2 = rotMtx(TAU / 3.0) * v1, \
         v3 = rotMtx(2.0 * TAU / 3.0) * v1;
    
    vec2 uvTriangTiled = mat3x2(v1, v2, v3) * uvwTriang;
    float uvScale = 4.0 - 3.0 * mousePos.y;
    return pattern(uvTriangTiled, mousePos.x, T * 0.03, uvScale);
}

void mainImage(out vec4 col, in vec2 pos){
    vec2 uv = (pos - R / 2.0) * EPS;
    vec3 accCol = vec3(0.0);
    float cnt = 0.0;
    float aaSz = 1.0;
    for (float dx = -aaSz; dx <= aaSz; dx += 1.0)
        for (float dy = -aaSz; dy <= aaSz; dy += 1.0){
            accCol += imgCol(pos + 0.33 * vec2(dx, dy));
            cnt += 1.0;
        }
    accCol /= cnt;
    col = vec4(accCol * smoothstep(0.5, 0.0, length(uv)), 1.0);
}
