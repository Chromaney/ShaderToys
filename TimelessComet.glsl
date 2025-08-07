// Shader "Timeless Comet" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Just an experiment with IFSs. Took a while to make it look somewhat interesting.
// And current shader limitations don't help with getting high quality images.

// Some of the ideas have been referenced from here: 
// https://www.shadertoy.com/view/4dXGWS
// Some transformation functions (and parts of idea) taken from here: 
// https://flam3.com/flame_draves.pdf

// --------------------------------

// [Common]

#define T (2.0 * 3.1415926536)
#define INF 1.0e6

#define R iResolution.xy
#define EPS (1.0 / max(R.x, R.y))
#define EPS_CURR (1.0 * EPS)

// "random" value function
#define rand(v) (fract(sin(dot(v, vec3(113.5, 271.9, 124.6))) * 43758.5453123))

mat2 rotMtx(float ang){
    // rotation matrix
    float c = cos(ang), s = sin(ang);
    return mat2(c, s, -s, c);
}

// [BufferA]
// [iChannel0: BufferA, filter = mipmap, wrap = clamp]

// IFS density and coloring generation/accumulation buffer.

const int nProbs = 4; // number of probabilities and transformations

vec2 tf1(vec2 pos, float t){
    float a = T / 2.0 * pos.y + cos(0.23 * t);
    return exp(pos.x - 1.0) * vec2(cos(a), sin(a));
}

vec2 tf2(vec2 pos, float t){
    float m = 0.1;
    vec2 v = (0.0 - pos.yx) * sin(pos);
    return mod(v, m) / m * sign(v);
}

vec2 tf3(vec2 pos, float t){
    float r2 = dot(pos, pos);
    return vec2(pos.x * sin(r2) - pos.y * cos(r2), pos.x * cos(r2) + pos.y * sin(r2));
}

vec2 tf4(vec2 pos, float t){
    return (mat2(0.8, 0.1, -0.1, 0.85) * rotMtx(0.276 * T + t * 0.59) * pos + \
        vec2(-0.1, -0.05));
}

vec4 cellUpdateDist(vec4 curr, vec4 upd){
    // cell state: xyz - coloring values (0 to 1), w - average distance below treshold;
    // update value: xyz - same, w - distance to cell center;
    // distances scaled to pixels
    float mixCoeff = 1.0 - clamp(upd.w / (curr.w * 1.0), 0.0, 1.0);
    vec3 color = mix(curr.xyz, upd.xyz, mixCoeff);
    float dist = mix(curr.w, upd.w, mixCoeff);
    return vec4(color, dist);
}

vec4 cellUpdateDens(vec4 curr, vec4 upd){
    // cell state: xyz - coloring values (0 to 1), w - accumulated density (0 to ?);
    // update value: xyz - same, w - distance to cell center;
    // distance scaled to pixels
    float mixCoeff = 1.0 / pow((1.0 + curr.w), 0.25) * 1.0 / pow((1.0 + upd.w), 1.0);
    vec3 color = mix(curr.xyz, upd.xyz, mixCoeff);
    float dens = curr.w + mixCoeff * 0.2; // exp(- 1.0 * upd.w)
    return vec4(color, dens);
}

vec4 getSceneCol(vec2 fragCoord){
    vec2 uv0 = (fragCoord - 0.5 * R) * EPS_CURR + vec2(0.0, 0.0);
    vec3 randSrc = vec3(iTime, uv0);
    vec2 uv = vec2(rand(randSrc), rand(randSrc.yzx));
    uv = 0.999 * sqrt(uv.x) * vec2(cos(T * uv.y), sin(T * uv.y)); // random in circle
    float n = 1000.0; // also affects fractal depth
    float nAct = n - 300.0; // "active" iterations --- used in calculations
    float r = iTime; // random number over iterations
    
    float t = (iTime + 45.0) * 0.1;
    
    float probs[nProbs] = float[nProbs](1.0, 1.0, 1.0, 1.0);
    float probsSum[nProbs + 1] = float[nProbs + 1](0.0, 0.0, 0.0, 0.0, 0.0);
    for (int i = 1; i <= nProbs; i ++){
        probsSum[i] = probsSum[i - 1] + probs[i - 1];
    }
    for (int i = 1; i <= nProbs; i ++){
        probsSum[i] /= probsSum[nProbs];
    }
    
    vec3 accum = vec3(0.0);
    float accumN = 0.0;
    vec4 accumFull = vec4(0.0, 0.0, 0.0, INF);
    
    for (float i = 0.0; i < n; i += 1.0){
        r = rand(vec3(r + uv0.x, i + uv0.y, uv0.x * uv0.y));
        float choice = -1.0;
        
        if (r < probsSum[1]){
            uv = tf1(uv, t);
            choice = 1.0;
        } else if (r < probsSum[2]){
            uv = tf2(uv, t);
            choice = 2.0;
        } else if (r < probsSum[3]){
            uv = tf3(uv, t);
            choice = 3.0;
        } else {
            uv = tf4(uv, t);
            choice = 4.0;
        }
        
        uv = mat2(0.9, -0.2, -0.1, 0.85) * rotMtx(0.627 * T + t) * uv + \
            vec2(0.05, -0.03);
        
        if (i >= nAct){
            float d = length(uv0 - uv) / EPS_CURR; // scale to pixels
            accum += vec3(choice == 1.0, choice == 2.0, choice == 3.0);
            accumN += 1.0;
            accumFull = cellUpdateDist(accumFull, \
                vec4(accum / accumN * float(nProbs), d));
        }
    }
    
    return accumFull;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    // fragColor: 3x coloring params, accumulated density
    vec4 prevVal = texelFetch(iChannel0, ivec2(fragCoord), 0);
    prevVal.w = exp(prevVal.w) - 1.0; // unflatten distribution
    vec4 curVal = getSceneCol(fragCoord);
    if (iFrame == 0){
        curVal = vec4(1.0 / vec3(nProbs), 0.0);
    } else {
        curVal = cellUpdateDens(prevVal, curVal);
        curVal.w *= 0.930;
    }
    curVal.w = log(1.0 + curVal.w); // flatten distribution
    fragColor = curVal;
}

// [Image]
// [iChannel0: BufferA, filter = mipmap, wrap = clamp]

// Main image (with "postprocessing") buffer.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    float smoothR = textureLod(iChannel0, fragCoord / R, 4.0).w;
    smoothR = 4.0 * pow(1.0 - smoothR, 5.0);
    
    float dens = textureLod(iChannel0, fragCoord / R, smoothR - 1.0).w;
    float colorScaling = 1.0 / (1.0 + exp(-20.0 * (dens - 0.2)));
    vec4 col = textureLod(iChannel0, fragCoord / R, smoothR);
    col.w = 1.0 - col.x - col.y - col.z;
    
    // Some color manipulation.
    col.xyz = pow(col.xyz, vec3(1.0)) * 1.5 * vec3(
        3.0 - col.y - col.z, 
        3.0 - col.x - col.z, 
        3.0 - col.x - col.y);
    fragColor.x = col.x + col.y;
    fragColor.y = 0.8 * col.x * (col.y + col.z);
    fragColor.z = pow(col.z, 1.7) + 0.5 * sin(col.x * T);
    
    fragColor = vec4(fragColor.xyz * colorScaling, 1.0);
}
