// [Shadertoy shader]
// [Name: Fingerprints on glass]
// [Tags: 2d, noise-based, organic]
// [Description: Shader for an effect of fingerprints on the back side of "glass".]
// [Subpages below]

// [Common]
// [Code below]
#define TAU 6.2831853
#define SAMPLE_LOD 3.0
#define PRINT_COL vec3(1.0, 0.03, 0.03)
#define DIFF_COL vec3(0.2, 0.6, 1.0)
#define SPEC_COL vec3(0.6, 0.8, 1.0)
#define SAMPLE_NOISE(coord) textureLod(iChannel0, (iResolution.x > iResolution.y) ? coord.xy : coord.yx, SAMPLE_LOD)
#define scTime (iTime / 100.0)

// [BufferA]
// [iChannel0: BufferA, filter = mipmap, wrap = repeat]
// [Code below]
// Buffer for uniform (hopefully) RGBA noise.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec4 col = vec4(0.0);
    if (iFrame == 0){
        uint k = 835171995U;
        uint a = uint(fragCoord.x);
        uint b = uint(fragCoord.y);

        uvec4 res = uvec4(a + k, b + k, a * b, k);
        res = (res.zxwy * k + res.ywxz) ^ res.w;
        res = (res.zxwy * k + res.ywxz) ^ res.z;
        res = (res.zxwy * k + res.ywxz) ^ res.y;
        res = (res.zxwy * k + res.ywxz) ^ res.x;

        col = vec4(res.xyzw) / float(0xffffffffU);
    } else {
        col = texelFetch(iChannel0, ivec2(fragCoord), 0);
    }
    fragColor = col;
}

// [BufferB]
// [iChannel0: BufferA, filter = mipmap, wrap = repeat]
// [iChannel1: BufferB, filter = mipmap, wrap = repeat]
// [Code below]
// Buffer for fractal noise.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    vec2 noiseUV = fragCoord / iResolution.xy;
    
    vec4 col = vec4(0.0);
    if (iFrame == 0){
        float randVal = iDate.w;
        float scale = 1.0;
        float colScale = 0.0;
        for (int i = 0; i < 5; i ++){
            colScale += 1.0 / scale;
            
            float baseShift = scale + randVal;
            vec2 shift = vec2(sin(5.781 * baseShift), cos(5.781 * baseShift));
            vec4 noise4 = textureLod(iChannel0, noiseUV * scale + shift, 5.0);
            col += (32.0 * (noise4 - 0.5) + 0.5) / scale;
            scale *= 2.0;
        }
        col /= colScale;
    } else {
        col = texture(iChannel1, uv);
    }
    fragColor = col;
}

// [BufferC]
// [iChannel0: BufferB, filter = mipmap, wrap = repeat]
// [Code below]
// Buffer for "fingerprints".

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 xy = fragCoord / iResolution.xy;
    vec2 xyCircScale = iResolution.xy / max(iResolution.x, iResolution.y);
    
    xy += (textureLod(iChannel0, xy, SAMPLE_LOD).xy - 0.5) * 0.02;
    
    vec3 col = vec3(0.0, 0.0, 0.0); // changes in loop (accumulator)
    float phase = 3.415 * scTime; // changes in loop
    
    for (float texFltIdx = 0.0; texFltIdx < 1.0 - 0.01; texFltIdx += 0.2){
        // shift values mod 0.2: 0.029, 0.122, 0.173, 0.078
        
        vec3 xyc0 = SAMPLE_NOISE(vec2(scTime * 1.0, 0.029 + texFltIdx)).xyz;
        
        float colOsc = pow(0.5 + 0.5 * cos(TAU * phase), 6.0); // max when phase = 0.0 + n
        float stage = floor(phase + 0.5); // changes when phase = 0.5 + n - furthest from above
        float colMixed = mix(xyc0.z, colOsc, 0.8);

        vec4 pertMtx = (SAMPLE_NOISE(vec2(scTime * 0.73, 0.722 + texFltIdx)) - 0.5) * 0.3;
        mat2 shape = mat2(1.0 + pertMtx.x, pertMtx.y, pertMtx.z, 1.0 + pertMtx.w);
        vec2 dir = shape * (xy - xyc0.xy) * xyCircScale * vec2(1.5, 1.0);
        float dist = length(dir);
        float linGrad = (0.1 - dist) / 0.1;

        vec4 frqPh = SAMPLE_NOISE(vec2(stage * 0.379, 0.173 + texFltIdx));
        frqPh.xy = round(frqPh.xy * vec2(5.0, 10.0) + vec2(2.5, 19.5));
        vec2 circDeform = vec2(0.03, 0.02) * sin(frqPh.xy * atan(dir.y, dir.x) + TAU * frqPh.zw);
        float circles = linGrad + (circDeform.x + circDeform.y) / (1.0 + 5.0 * linGrad);
        
        circles += (SAMPLE_NOISE(vec2(stage * 0.592, 0.478 + texFltIdx) + dir).x - 0.5) * 0.5;
        
        circles = pow(sin(TAU * 14.0 * circles) * 0.5 + 0.5, 4.0);
        circles *= smoothstep(0.2, 1.0, colMixed);
        
        float filled = pow(max(linGrad, 0.0), 0.5) * 0.7;
        float circFillMix = circles + filled - circles * filled;
        col += smoothstep(0.0, 0.1, 0.1 - dist) * circFillMix * PRINT_COL * colMixed;
        
        phase += 0.2;
    }
    
    fragColor = vec4(col, 1.0);
}

// [BufferD]
// [iChannel0: BufferC, filter = linear, wrap = clamp]
// [iChannel1: BufferD, filter = linear, wrap = clamp]
// [Code below]
// Buffer for "fingerprint" traces.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 xy = fragCoord / iResolution.xy;
    
    vec3 col = vec3(0.0, 0.0, 0.0);
    if (iFrame > 0){
        col = texture(iChannel1, xy).xyz;
    }
    
    vec3 colAdd = texture(iChannel0, xy).rgb;
    
    col *= 0.99;
    col = mix(col + 1.0 * colAdd, colAdd + 0.25 * col, pow(colAdd, vec3(0.5)));
    
    fragColor = vec4(col, 1.0);
}

// [Image]
// [iChannel0: BufferB, filter = mipmap, wrap = repeat]
// [iChannel1: BufferC, filter = linear, wrap = clamp]
// [iChannel2: BufferD, filter = linear, wrap = clamp]
// [Code below]
// Shader for an effect of fingerprints on the back side of "glass".

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 xy = fragCoord / iResolution.xy;
    vec2 xyCorrCoeff = iResolution.xy / max(iResolution.x, iResolution.y);

    vec3 col = texture(iChannel1, xy).xyz;
    vec3 colTrail = texture(iChannel2, xy).xyz;
    col = max(col, 0.75 * colTrail);
    
    vec3 lightL = normalize(vec3(0.02 * cos(TAU * 5.0 * scTime), 0.02 * sin(TAU * 5.0 * scTime), 1.0));
    
    vec2 noise = 0.3 * (textureLod(iChannel0, xy * 0.2 + 0.1, 2.0).rg - 0.5);
    vec3 lightN = normalize(vec3(noise, 1.0));
    vec3 lightV = normalize(vec3(0.1 * (vec2(0.5, 0.5) - xy) * xyCorrCoeff, 1.0));
    vec3 lightH = normalize(lightL + lightV);
    float specInt = dot(lightN, lightH);
    vec3 specCol = 0.25 * pow(max(specInt, 0.0), 8000.0) * SPEC_COL;
    
    col = mix(col, DIFF_COL, 0.25) + specCol;
    fragColor = vec4(col, 1.0);
}
