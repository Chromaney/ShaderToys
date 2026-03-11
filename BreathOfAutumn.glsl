// Shader "Breath of Autumn" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Just something from messing around with fractals (part 1).

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R (iResolution.xy)
#define EPS (1.0 / min(R.x, R.y))
#define T iTime

// change to 1.0 (or higher) for better antialiasing
#define AA_LVL 0.0

vec3 palette(vec2 t){
    vec3 baseCol = mix(vec3(1.0, 0.6, 0.2), vec3(0.8, 1.0, 0.4), t.x);
    vec3 col = pow(baseCol, vec3((t.y + 0.05) * vec3(5.0)));
    return col;
}

vec2 fracJul(vec2 c, vec2 c0){
    float n = 100.0;
    float esc = n;
    float escSet = 0.0;
    float escTr = 2.0;
    float lenMax = 1.0e12;
    
    for (float i = 0.0; i < n; i += 1.0){
        c = c0 + vec2(c.x * c.x - c.y * c.y, 2.0 * c.x * c.y);
        
        if (dot(c, c) > lenMax){
            esc = i;
            escSet = 1.0;
            break;
        }
    }
    
    float escPot = esc - log2(log2(dot(c, c)) / log2(lenMax));
    return vec2(escSet, escPot / n);
}

vec3 getImage(vec2 pos){
    vec2 uv = 2.0 * (pos - R / 2.0) * EPS;
    uv = uv * 0.1 + vec2(-0.520, -0.580);
    
    vec3 col = vec3(0.0);
    float t = T * 0.2;
    vec2 basePos = vec2(-0.51, -0.51);
    
    float n = 10.0;
    for (float i = 0.0; i < n; i += 1.0){
        float per = 1.0 - 0.11 * i * i / n / n;
        float curT = t / per + i / n * TAU;
        float curR = 3.0 * (0.005 + 0.002 * sin(i / n * TAU + t * 0.13));
        vec2 c0 = basePos + curR * vec2(cos(curT), sin(1.07 * curT));
        vec2 res1 = fracJul(uv, c0);
        
        vec3 curCol = palette(vec2(i / (n - 1.0), 0.5 + 0.5 * cos(1.73 * curT)));
        float curVal = 0.5 + 0.5 * sin(log(res1.y) * TAU * 1.0);
        col.xyz += curVal * step(0.5, res1.x) * curCol;
    }
    col *= 3.0 / n;
    
    return col;
}

void mainImage(out vec4 col, in vec2 pos){
    col = vec4(0.0, 0.0, 0.0, 1.0);
    
    float aaSz = AA_LVL;
    float aaCnt = 0.0;
    for (float dx = -aaSz; dx <= aaSz; dx += 1.0)
        for (float dy = -aaSz; dy <= aaSz; dy += 1.0){
            vec2 delta = vec2(dx, dy) / (aaSz + 1.0);
            col.xyz += getImage(pos + delta);
            aaCnt += 1.0;
        }
    col.xyz /= aaCnt;
}
