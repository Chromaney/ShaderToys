// Shader "Essence of Movement" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Just a small thing I had an idea for after remembering about 3D "cosine walks".

// --------------------------------

// [Common]

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

vec3 colFromHue(float h){
    return clamp(abs(6.0 * fract(h - vec3(0.0, 1.0, 2.0) / 3.0) - 3.0) - 1.0, 0.0, 1.0);
}

// [BufferA]
// [iChannel0: BufferA, filter = linear, wrap = clamp]

// Main calculation and memory buffer.

#define nPts 80

float getData(int pt, int coord){
    int id = pt * 3 + coord;
    int w = int(round(iChannelResolution[0].x));
    return texelFetch(iChannel0, ivec2(id % w, id / w), 0).w;
}

bool toSetData(int pt, int coord, vec2 pos){
    int id = pt * 3 + coord;
    int w = int(round(iChannelResolution[0].x));
    ivec2 texId = ivec2(id % w, id / w);
    return (ivec2(pos) == texId);
}

void mainImage(out vec4 col, in vec2 pos){
    vec2 uv = (pos - R / 2.0) * EPS * 0.7;
    
    col = vec4(0.0, 0.0, 0.0, 1.0);
    for (int i = 0; i < nPts; i ++){
        float curX = getData(i, 0);
        float curY = getData(i, 1);
        float curZ = getData(i, 2);
        vec3 curPt = vec3(curX, curY, curZ);
        vec3 delta = cos(curPt.yzx * TAU) * 0.25 * iTimeDelta;
        vec3 nextPt = curPt + delta;
        float per = 1.0;
        nextPt = mod(nextPt + 0.5 * per, per) - 0.5 * per;
        for (int c = 0; c < 3; c ++)
            if (toSetData(i, c, pos))
                col.w = nextPt[c];
        float distPow = 3.0;
        float drawDist = pow(abs(uv.x - curPt.x), distPow) + \
            pow(abs(uv.y - curPt.y), distPow);
        drawDist = pow(drawDist, 1.0 / distPow);
        vec3 curCol = colFromHue(float(i) / float(nPts));
        float sz = ((tanh(curPt.z * 4.0) * 0.5 + 0.5) * 0.2 + 0.8) * 0.07;
        curCol *= (1.0 - 1.0 / (1.0 + exp(-30.0 * (drawDist / sz - 1.0))));
        col.rgb = col.rgb + curCol - 1.0 * col.rgb * curCol;
    }
    
    col.rgb = 1.0 - col.rgb;
    
    vec3 prevCol = texelFetch(iChannel0, ivec2(pos), 0).rgb;
    col.rgb = mix(col.rgb, prevCol, 1.0 * exp(-1.0 * iTimeDelta));
    
    if (iFrame == 0){
        for (int i = 0; i < nPts; i ++){
            for (int c = 0; c < 3; c ++)
                if (toSetData(i, c, pos))
                    col.w = rand33(vec3(pos, 1.0))[c] * 2.0 - 1.0;
        }
        col.rgb = vec3(0.0);
    }
}

// [Image]
// [iChannel0: BufferA, filter = linear, wrap = clamp]

// Output buffer.

void mainImage(out vec4 col, in vec2 pos){
    col.rgb = texelFetch(iChannel0, ivec2(pos), 0).rgb;
    col.a = 1.0;
}
