// Shader "Fractal Nebula" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Just something from messing around with fractals (part 2).

// --------------------------------

// [BufferA]
// [iChannel0: BufferA, filter = linear, wrap = clamp]

// Image generation buffer with time-based smoothing 
// (multisampling AA is too slow for me).

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R (iResolution.xy)
#define EPS (1.0 / min(R.x, R.y))
#define T iTime

vec3 colFromHue(float h){
    return clamp(abs(fract(h - vec3(0.0, 1.0, 2.0) / 3.0) - 1.0 / 2.0) * 6.0 - 1.0, 
        0.0, 1.0);
}

vec2 fracJul(vec2 z, vec2 c0){
    float n = 100.0;
    float esc = n;
    float escSet = 0.0;
    float escTr = 4.0;
    float escExp = -1.0;
    float lenMax = 1.0e12;
    
    for (float i = 0.0; i < n; i += 1.0){
        vec2 _z = z;
        vec2 _zsq = vec2(_z.x * _z.x - _z.y * _z.y, 2.0 * _z.x * _z.y);
        z = c0 + _zsq;
        
        float z2 = dot(z, z);
        float _z2 = dot(_z, _z);
        
        if ((escSet < 0.5) && (z2 > escTr)){
            esc = i;
            escSet = 1.0;
        }
        
        escExp = sqrt(z2 / _z2);
        
        if (z2 > lenMax){
            esc = i;
            escSet = 1.0;
            break;
        }
    }
    
    return vec2(escSet, escExp);
}

vec3 getImage(vec2 pos){
    vec2 uv = 2.0 * (pos - R / 2.0) * EPS;
    uv = uv * 0.1 + vec2(-0.000, -0.200);
    
    vec3 col = vec3(0.0);
    float t = T * 0.05;
    vec2 basePos = vec2(-0.51, -0.51);
    
    float n = 10.0;
    for (float i = 0.0; i < n; i += 1.0){
        vec3 curCol = colFromHue(i / n - 0.43 * t);
        float per = 1.0 - 0.11 * i * i / n / n;
        float curT = t / per + i / n * TAU;
        float curR = 3.0 * (0.005 + 0.002 * sin(i / n * TAU + t * 0.13));
        vec2 sh = curR * vec2(cos(curT), sin(1.07 * curT));
        vec2 c0 = basePos + sh;
        vec2 res1 = fracJul(uv, c0);
        
        vec3 colAdd = res1.y * step(res1.x, 0.5) * curCol;
        col.xyz += colAdd / n;
    }
    
    return col;
}

void mainImage(out vec4 col, in vec2 pos){
    col.xyz = tanh(0.9 * getImage(pos) - 0.15);
    
    if (iFrame > 0){
        vec3 prevCol = texelFetch(iChannel0, ivec2(pos), 0).xyz;
        col.xyz = mix(col.xyz, prevCol, exp(- 5.0 * iTimeDelta));
    }
    col.w = 1.0;
}

// [Image]
// [iChannel0: BufferA, filter = linear, wrap = clamp]

// Main image output.

void mainImage(out vec4 col, in vec2 pos){
    col.xyz = texelFetch(iChannel0, ivec2(pos), 0).xyz;
    col.w = 1.0;
}
