// Shader "London Dots" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A simple animated effect of turning an image into "dots".
// Inspired by a random piece of art I have seen recently.
// (Name is only because of the image used.)

// --------------------------------

// [BufferA]
// [iChannel0: London, filter = linear, wrap = clamp, vflip = true]

// Buffer for image preprocessing.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 resCorr = iResolution.xy * vec2(3.0, 4.0); // corrected by original side ratio
    vec2 scaleCoeff = resCorr / max(resCorr.x, resCorr.y);
    vec2 uvScaled = (fragCoord / iResolution.xy - 0.5) * scaleCoeff + 0.5;
    vec3 col = texture(iChannel0, uvScaled).rgb;
    fragColor = vec4(pow(col, vec3(2.2)),1.0);
}

// [Image]
// [iChannel0: BufferA, filter = mipmap, wrap = clamp]

#define M_PI 3.1415926536
#define ANIM_CYCLE_LEN (10.0 * 2.0 / 3.0)

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord / iResolution.xy;
    float minRes = min(iResolution.x, iResolution.y);
    float maxRes = max(iResolution.x, iResolution.y);
    
    float maxLod = ceil(log2(maxRes));
    vec3 baseCol = textureLod(iChannel0, vec2(0.5, 0.5), maxLod).rgb;
    
    float curAnimStage = fract(iTime / ANIM_CYCLE_LEN);
    float curAnimCycle = floor(iTime / ANIM_CYCLE_LEN);
    float stageModif = clamp(1.5 * 2.0 * abs(curAnimStage - 0.5) - 0.5, 0.0, 1.0);
    stageModif = smoothstep(0.0, 1.0, stageModif);
    
    vec3 curRand = acos(cos(curAnimCycle * vec3(783.42, 567.92, 951.23) + \
        vec3(59.061, 73.801, 68.074))) / M_PI; // 0 to 1
    float minSizePx = clamp(minRes / 40.0, 8.0, 1.0e10);
    float maxSizePx = clamp(4.0 * minSizePx, 0.0, minRes);
    float curSizePx = mix(minSizePx, maxSizePx, curRand.x);
    float curLod = log2(curSizePx);
    
    vec2 fragCoordDelta = -curSizePx * (curRand.yz - 0.5);
    vec2 fragCoordMod = fragCoord + fragCoordDelta;
    vec2 uvTex = ((floor(fragCoordMod / curSizePx) + 0.5) * curSizePx - fragCoordDelta) / iResolution.xy;
    
    vec3 curCol = textureLod(iChannel0, uvTex, curLod).rgb;
    vec3 curClearCol = textureLod(iChannel0, uv, curLod * (1.0 - stageModif)).rgb;
    
    float maskSize = length(curCol - baseCol) / sqrt(3.0);
    maskSize = 0.25 + 0.75 * pow(maskSize, 0.25) * 1.0;
    
    float waveTime = (clamp(2.0 * (curAnimStage - 0.5), -0.5, 0.5) + 0.5);
    vec2 pos = floor(fragCoordMod / curSizePx);
    float cb = mod(pos.x + pos.y, 2.0);
    vec2 posNorm = pos / floor((iResolution.xy - 0.5) / curSizePx);
    
    vec4 phases = clamp(vec4(\
        0.0 + 2.0 * waveTime - 0.5 * posNorm.x - 0.00, \
        2.0 - 2.0 * waveTime - 0.5 * posNorm.x - 0.75, \
        0.0 + 2.0 * waveTime - 0.5 * posNorm.y - 0.25, \
        2.0 - 2.0 * waveTime - 0.5 * posNorm.y - 0.50 \
    ), 0.0, 1.0) * 2.0 * M_PI;
    
    vec4 waves = pow(clamp(sin(phases), 0.0, 1.0), vec4(4.0));
    float maskWobble = mix(max(waves.x, waves.y), max(waves.z, waves.w), cb);
    
    vec3 colorDiff = curCol - baseCol;
    curCol = curCol - maskWobble * colorDiff;
    curCol = clamp(curCol, 0.0, 1.0);
    
    maskWobble *= 0.5;
    
    maskSize = mix(maskSize * (1.0 + maskWobble), 
        maskSize + maskWobble - maskSize * maskWobble * 1.0, maskSize);
    // ^ works only for maskWobble < 0.5
    maskSize = clamp(maskSize, 0.0, 1.0);
    maskSize = mix(maskSize, 2.0, stageModif);
    
    float mask = length(2.0 * (mod(fragCoordMod - 0.5, curSizePx) / curSizePx - 0.5)) / maskSize;
    mask = 1.0 - mask;
    mask = clamp(mask / fwidth(mask), 0.0, 1.0);
    
    vec3 col = mix(mix(baseCol, curCol, mask), curClearCol, stageModif);
    fragColor = vec4(pow(col, vec3(1.0 / 2.2)), 1.0);
}
