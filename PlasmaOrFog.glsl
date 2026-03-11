// Shader "Plasma or Fog" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Experimenting with combining volumetric glow-like lighting and turbulent noise.
// With four different versions.

// Screen sections: 
// LB - smooth turbulent noise with volumetric lighting mostly around edges;
// LT - same but with triangular function in noise 
//     (inspired by https://www.shadertoy.com/view/WfdBD7);
// RB - LB but with smaller number of raymarching steps so that rendering doesn't reach 
//     far enough (with different light accumulation to cause foggy effects);
// RT - same but with triangular function in noise (same as LT).

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

void smoothNoise3(vec3 pos, float t, float n, bool triMode, out vec3 d, out vec3 e){
    float scale = 1.11; // 1.06
    d = vec3(0.0);
    e = vec3(0.0);
    float scaleAcc = 1.0;
    float divAcc = 0.0;
    mat3 curRot3 = 1.0 / 325.0 * mat3(
        12.0, 316.0, -75.0, 
        -100.0, 75.0, 300.0, 
        -309.0, -12.0, -100.0);
    for(float i = 0.0; i < clamp(n, 0.0, 100.0); i += 1.0){
        /*pos.xy = scale * (rotMtx(TAU * 0.427) * pos.xy + vec2(+2.75, -4.78));
        pos.xz = scale * (rotMtx(TAU * 0.651) * pos.xz + vec2(+3.86, +6.35));
        pos.yz = scale * (rotMtx(TAU * 0.398) * pos.yz + vec2(-1.49, -2.91));
        scaleAcc *= (scale * scale);*/
        pos = scale * curRot3 * pos + vec3(1.78, -3.42, 5.96);
        scaleAcc *= scale;
        float k = clamp(n - i, 0.0, 1.0) / scaleAcc;
        if (triMode){
            /*e += asin(cos(TAU * pos + t + d.yzx)) / PI * 2.0 * k;
            d += asin(cos(1.0 * pos + t + e.xzy)) / PI * 2.0 * k;*/
            e += (abs(mod(TAU * pos + t + d.yzx, TAU) / PI - 1.0) * 2.0 - 1.0) * k;
            d += (abs(mod(1.0 * pos + t + e.xzy, TAU) / PI - 1.0) * 2.0 - 1.0) * k;
        } else {
            e += cos(TAU * pos + t + d.yzx) * k;
            d += cos(1.0 * pos + t + e.xzy) * k;
        }
        divAcc += k;
    }
    d = d / divAcc * 0.5 + 0.5;
    e = e / divAcc * 0.5 + 0.5;
}

// [Image]

float getSection(vec2 pos, out vec2 ctr, out vec2 sc){
    pos /= R;
    vec2 sect2 = floor(pos * vec2(2.0));
    float sect = sect2.x + 2.0 * sect2.y;
    ctr = sect2 * 0.5 + 0.25;
    sc = vec2(2.0);
    
    /*sect = 0.0;
    ctr = vec2(0.5);
    sc = vec2(1.0);*/
    
    return sect;
}

vec4 scene(vec3 pos, float sect){
    vec3 n1, n2;
    float noiseSteps = 10.0;
    smoothNoise3(pos, T * 0.1, noiseSteps, (sect > 1.5), n1, n2);
    return vec4(n1, n2.x * 2.0 - 1.0);
}

vec4 rayMarch(in vec3 orig, in vec3 dir, in float sect, 
    out float dist, out float iter, out vec3 accumLight){
    
    vec3 param = vec3(0.0);
    if (mod(sect, 2.0) == 0.0){
        param = vec3(300.0, 10.0, 0.001);
    } else if (mod(sect, 2.0) == 1.0){
        param = vec3(50.0, 10.0, 0.003);
    }
    
    float maxIter = param.x;
    float maxDist = param.y;
    float proxDist = param.z;
    
    accumLight = vec3(0.0);
    
    iter = 0.0;
    dist = 0.0;
    vec3 pos = orig;
    float curStep = 0.0;
    for (; (iter < maxIter) && (dist <= maxDist); iter += 1.0){
        vec4 curScene = scene(pos, sect);
        curStep = curScene.w * 0.25;
        bool addLight = (curStep < 0.0);
        curStep = abs(curStep);
        curStep = max(curStep, proxDist); // increase small steps
        
        if (addLight){
            float baseVal = curStep;
            //baseVal *= 1.0e0;
            //baseVal *= 1.0 / (1.0 + dist * dist);
            //baseVal *= exp(-dist * 0.75);
            //baseVal *= exp(-(curStep / proxDist - 1.0) * 1.0);
            
            if (mod(sect, 2.0) == 0.0){
                baseVal *= 3.0e1;
                baseVal *= exp(-dist * 1.0);
                baseVal *= exp(-(curStep / proxDist - 1.0) * 5.0);
            } else if (mod(sect, 2.0) == 1.0){
                baseVal *= exp(-dist * 0.75);
            }
            accumLight += baseVal * curScene.xyz;
        }
        
        dist += curStep;
        pos += dir * curStep;
    }
    
    return vec4(pos, dist);
}

void mainImage(out vec4 col, in vec2 pos){
    vec2 uv = (pos - R / 2.0) * EPS;
    vec2 uv0 = uv;
    
    vec2 ctr, sc;
    float sect = getSection(pos, ctr, sc);
    
    uv = uv + 0.5 - ctr;
    uv = uv * sc;
    
    vec3 camPos, rayDir;
    camPos = vec3(0.0, 0.0, 0.23 * T);
    rayDir = normalize(vec3(uv, 1.0));
    
    vec3 curCol;
    float dist, iter;
    vec4 rmRes;
    rmRes = rayMarch(camPos, rayDir, sect, dist, iter, curCol);
    
    col.rgb = vec3(0.0);
    if (mod(sect, 2.0) == 0.0){
        float curColMin = min(curCol.r, min(curCol.g, curCol.b));
        vec3 colEd = curCol - curColMin * 0.5;
        colEd = pow(colEd, vec3(0.7));
        colEd += curColMin * 0.5;
        col.rgb = tanh(pow(colEd, vec3(1.5)) * 2.0);
    } else if (mod(sect, 2.0) == 1.0){
        float curColMin = min(curCol.r, min(curCol.g, curCol.b));
        vec3 colEd = curCol - curColMin * 0.3;
        colEd = pow(colEd, vec3(0.7));
        colEd += curColMin * 0.3;
        col.rgb = tanh(pow(colEd, vec3(0.8)) * 1.2);
    }
    
    col.w = 1.0;
    
    col.rgb *= smoothstep(abs(uv0.x) / 0.005, 1.0, 0.0);
    col.rgb *= smoothstep(abs(uv0.y) / 0.005, 1.0, 0.0);
}
