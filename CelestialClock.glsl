// Shader "Celestial Clock" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Combination of experimenting with lighting and fractal-like structures.
// With some clockwork-like movement.
// Use pressed LMB to rotate around.

// --------------------------------

// [Common]

#define M_PI 3.1415926536

#define N_LIGHTS 7.0

mat2 rotMtx(float ang){
    float cosAng = cos(ang);
    float sinAng = sin(ang);
    return mat2(cosAng, -sinAng, sinAng, cosAng); // applied from right
}

float incStep(float t){
    float fixedPart = 2.0 * M_PI * floor(t / (2.0 * M_PI));
    float scaledVal = 2.0 * ((t + sin(t) - fixedPart) / (2.0 * M_PI) - 0.5);
    float svSign = sign(scaledVal);
    scaledVal *= (scaledVal * scaledVal); // 3
    scaledVal *= scaledVal; // 6
    float val = (svSign * scaledVal + 0.5) * M_PI + fixedPart;
    return val;
}

float smoothMin(float a, float b, float k){
    k *= 4.0;
    float h = max(k - abs(a - b), 0.0) / k;
    return (min(a, b) - h * h * k * (1.0 / 4.0));
}

float smoothMax(float a, float b, float k){
    return (a + b - smoothMin(a, b, k));
}

vec3 colFromHue(float h){
    return clamp(abs(fract(h - vec3(0.0, 1.0, 2.0) / 3.0) - 1.0 / 2.0) * 6.0 - 1.0, 0.0, 1.0);
}

float gyroid(vec3 pos, vec2 period){
    return dot(sin(pos * period.x), cos(pos.zxy * period.y));
}

float weightFcn(float t){
    return (1.0 - t * t * (-2.0 * t + 3.0));
}

// [BufferA]

// Main image buffer.

#define RM_MAX_ITER 100
#define RM_MAX_DIST 30.0
#define RM_PROX_DIST 0.003
#define RM_SURF_EPS 0.7

#define NORM_COORD_STEP 0.001
#define NORM_COORD_STEP_VEC vec3(NORM_COORD_STEP, 0.0, 0.0)

float sphereSDF(vec3 pos, float r){
    // centered on vec3(0.0)
    return (length(pos) - r);
}

float sphereShellSDF(vec3 pos, vec2 r){
    // centered on vec3(0.0)
    return (abs(length(pos) - r.x) - r.y);
}

float patternSDF(vec3 pos, vec2 shellSize, float scale){
    vec3 coordShift = vec3(0.5 * scale);
    vec3 modifPos = mod(pos - coordShift, scale) - coordShift;
    return sphereShellSDF(modifPos, shellSize * scale);
}

float objSDF(vec3 pos, vec2 shellSize, vec2 secShellSize, vec2 patternScale, int n){
    float dist = sphereShellSDF(pos, shellSize);
    float curScale = patternScale.x;
    for(int i = 0; i < n; i ++){
        float patternDist = patternSDF(pos, secShellSize, curScale);
        dist = smoothMax(dist, -patternDist, 0.007);
        curScale /= patternScale.y;
    }
    return dist;
}

vec3 lightPosFromId(float id){
    if (abs(id - (N_LIGHTS - 1.0)) < 0.1){
        return vec3(0.0);
    }
    
    float nSub = round(N_LIGHTS / 3.0);
    float axis = mod(id, 3.0);
    float subId = floor(id / 3.0);
    float baseR = 6.5;
    
    vec3 axisMatch = vec3(
        float(abs(axis - 0.0) < 0.001), 
        float(abs(axis - 1.0) < 0.001), 
        float(abs(axis - 2.0) < 0.001)
    );
    vec3 pos = baseR * axisMatch.yzx;
    
    mat2 curRotMtx = rotMtx(subId / nSub * 2.0 * M_PI + iTime * 0.25);
    
    if (axisMatch.x > 0.5){
        pos.yz *= curRotMtx;
    }
    if (axisMatch.y > 0.5){
        pos.zx *= curRotMtx;
    }
    if (axisMatch.z > 0.5){
        pos.xy *= curRotMtx;
    }
    
    pos.yz *= rotMtx(iTime * 0.12);
    pos.zx *= rotMtx(iTime * 0.14);
    pos.xy *= rotMtx(iTime * 0.15);
    
    return pos;
}

vec3 lightColorFromId(float id){ // synced
    float baseHue = 0.67 + 0.1 * cos(incStep(iTime * 0.67 + 4.0 * M_PI / 3.0) / 4.3);
    float curHue;
    if (abs(id - (N_LIGHTS - 1.0)) < 0.1){
        curHue = baseHue + 0.33;
    } else {
        curHue = baseHue + 0.1 * (2.0 * id / (N_LIGHTS - 2.0) - 1.0);
    }
    return (0.2 + 0.8 * colFromHue(fract(curHue)));
}

float lightSizeFromId(float id){
    if (abs(id - (N_LIGHTS - 1.0)) < 0.1){
        return 1.6;
    }
    
    return 1.0;
}

float lightIntFromId(float id){
    return 20.0;
}

vec4 lightGeomFromId(float id){
    return vec4(lightPosFromId(id), lightSizeFromId(id));
}

vec4 lightColIntFromId(float id){
    return vec4(lightColorFromId(id) * lightIntFromId(id), 1.0);
}

float lightDissipFcn(vec3 src, vec3 dst){
    // should be const / r^2, but const is too mathy to calculate and r^2 is too dark
    return 1.0 / (1.0 + length(dst - src));
}

vec3 inftyColor(vec3 dir){
    float colorCoeff1 = 0.5 + 0.5 * gyroid(dir, vec2(10.0, 10.0)) / 3.0; // 0 to 1
    float colorCoeff2 = 0.5 + 0.5 * gyroid(dir, vec2(8.0, 8.0)) / 3.0; // 0 to 1
    vec3 col = vec3(0.1, 0.1, 0.1) * (0.5 + 0.5 * colorCoeff1) + 
        vec3(0.0, 0.05, 0.1) * (0.5 + 0.5 * colorCoeff2);
    return col;
}

mat3 objRotMtx(){ // synced
    float t = iTime * 0.67;
    float angX = incStep(t) / 13.0;
    float angY = incStep(t + 2.0 * M_PI / 3.0) / 12.0;
    float angZ = incStep(t + 4.0 * M_PI / 3.0) / 11.0;
    float sx = sin(angX), cx = cos(angX);
    float sy = sin(angY), cy = cos(angY);
    float sz = sin(angZ), cz = cos(angZ);
    vec3 comp1 = vec3(cy * cz, sx * sy * cz - cx * sz, cx * sy * cz + sx * sz);
    vec3 comp2 = vec3(cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - sx * cz);
    vec3 comp3 = vec3(-sy, sx * cy, cx * cy);
    
    return mat3(comp1, comp2, comp3);
}

vec2 objParams(){ // synced
    return vec2(
        0.075 + 0.025 * cos(incStep(iTime * 0.67 + 2.0 * M_PI / 3.0) / 1.3), 
        2.0 + 0.1 * cos(incStep(iTime * 0.67) / 1.6)
    );
}

float objDistField(vec3 pos, vec2 objPar){
    return objSDF(pos, vec2(3.8, 0.2), vec2(0.6 - objPar.x, objPar.x), vec2(1.0, objPar.y), 2);
}

vec3 sceneNorm(vec3 pos, mat3 objRot, vec2 objPar){
    // since normal is now only for object, rotation can be separated from SDF calculations
    pos *= objRot;
    float sdfShX = objDistField(pos + NORM_COORD_STEP_VEC.xzy, objPar);
    float sdfShY = objDistField(pos + NORM_COORD_STEP_VEC.yxz, objPar);
    float sdfShZ = objDistField(pos + NORM_COORD_STEP_VEC.zyx, objPar);
    vec3 norm = normalize(vec3(sdfShX, sdfShY, sdfShZ) - objDistField(pos, objPar));
    return (norm * transpose(objRot));
}

vec4 rayMarch(vec3 origin, vec3 dir, out float objType, mat3 objRot, vec2 objPar){
    float dist = 0.0;
    objType = 1.5;
    
    for (int iter = 0; iter < RM_MAX_ITER; iter ++){
        vec3 pos = origin + dir * dist;
        float curStep = objDistField(pos * objRot, objPar);
        dist += curStep;
        if (abs(curStep) < RM_PROX_DIST){
            break;
        }
        if (dist > RM_MAX_DIST){
            objType = -0.5;
            break;
        }
    }
    
    vec3 pos = origin + dir * dist;
    return vec4(pos, dist);
}

vec4 lightMarch(vec3 pos, vec4 lightGeom, vec4 lightCol, vec3 curSceneNorm, mat3 objRot, vec2 objPar){
    //returns vec4: xyz - resulting light intensity, w - diffuse light component
    
    vec3 lightPos = lightGeom.xyz;
    float lightSize = lightGeom.w;
    
    float normStep = RM_PROX_DIST * (1.0 + RM_SURF_EPS);
    vec3 origin = pos + curSceneNorm * normStep;
    
    vec3 lightDir = normalize(lightPos - origin);
    float lightDist = length(lightPos - origin);
    
    float dist = RM_PROX_DIST * (1.0 + RM_SURF_EPS);
    float minAngMiss = 1.0;
    float angLightSize = lightSize / lightDist;
    
    float lightCoeff = 1.0;
    
    for (int iter = 0; iter < RM_MAX_ITER; iter ++){
        vec3 pos = origin + lightDir * dist;
        float curStep = objDistField(pos * objRot, objPar);
        
        
        minAngMiss = min(max(curStep / dist / angLightSize, 0.0), minAngMiss);
        dist += curStep;
        
        if (dist >= lightDist){ // replaces RM_MAX_DIST check
            break;
        }
        if (abs(curStep) < RM_PROX_DIST){
            break;
        }
    }
    
    if (dist < lightDist){
        lightCoeff = 0.0;
    } else {
        lightCoeff *= minAngMiss;
    }
    
    lightCoeff *= lightDissipFcn(origin, lightPos);
    
    float dotNormLight = dot(curSceneNorm, lightDir);
    float diffLightVal = max(
        dotNormLight + (1.0 - dotNormLight * dotNormLight) * lightSize / lightDist, 
        0.0);
    // ^ corrected for non-point light sources
    
    return vec4(lightCoeff * lightCol.xyz, diffLightVal);
}

vec4 sceneColor(vec4 rmRes, float objType, vec3 camPos, vec3 rayDir, mat3 objRot, vec2 objPar){
    // returns vec4: xyz - color, w - bloom strength
    vec4 col = vec4(0.0);
    vec3 pos = rmRes.xyz;
    
    float closestLightId = -1.0;
    float minDist = rmRes.w;
    vec4 closestLightColor = vec4(0.0);
    for (float id = 0.0; id < N_LIGHTS - 0.5; id += 1.0){
        vec4 lightGeom = lightGeomFromId(id);
        vec4 lightColor = lightColIntFromId(id);
        vec3 lightPos = lightGeom.xyz;
        float lightSize = lightGeom.w;
        
        float coeff2 = dot(rayDir, rayDir);
        float coeff1 = 2.0 * dot(rayDir, camPos - lightPos);
        float coeff0 = dot(camPos - lightPos, camPos - lightPos) - lightSize * lightSize;
        float det = coeff1 * coeff1 - 4.0 * coeff2 * coeff0;
        if (det >= 0.0){
            float curDist = (-coeff1 - sqrt(det)) / (2.0 * coeff2);
            if (curDist < minDist){
                minDist = curDist;
                closestLightId = id;
                closestLightColor = lightColor;
            }
        }
    }
    
    if (closestLightId > -0.5){ // light source
        col.xyzw = closestLightColor * lightDissipFcn(camPos + rayDir * minDist, camPos);
    } else {
        if (objType < 0.0){ // infinity
            col.xyz = inftyColor(rayDir);
        } else { // any not (infinity / not reached / light source) -> just object
            vec3 curSceneNorm = sceneNorm(pos, objRot, objPar);
            
            vec2 texEffParams = 5.0 * vec2(
                1.0 + 0.1 * cos(iTime / 5.2 + 2.0), 
                1.0 + 0.1 * cos(iTime / 6.0)
            );

            float texEffect = 0.5 + 0.5 * gyroid(pos * objRot, texEffParams) / 3.0;
            texEffect = 1.0 + 1.0 - 2.0 * abs(smoothstep(0.4, 0.6, texEffect) - 0.5);

            for (float id = 0.0; id < N_LIGHTS - 0.5; id += 1.0){
                vec4 lightMarchRes = lightMarch(pos, 
                    lightGeomFromId(id), lightColIntFromId(id), curSceneNorm, objRot, objPar);
                col.xyz += lightMarchRes.xyz * lightMarchRes.w;
            }
            col.xyz *= texEffect;
            col.xyz += 0.75 * (vec3(0.1, 0.1, 0.1) + vec3(0.0, 0.05, 0.1));
            // ^ add average ininity color
            col.xyz *= vec3(1.0); // surface color
            col *= lightDissipFcn(pos, camPos);
        }
        // col.w is 0.0 from init
    }
    
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec2 mousePos = iMouse.xy;
    if (iMouse.z == 0.0){
        mousePos = vec2(0.3, 0.3) * iResolution.xy;
    }
    mat2 rotXZ = rotMtx((mousePos.x / iResolution.x * 2.0 - 1.0) * M_PI);
    mat2 rotYZ = rotMtx((mousePos.y / iResolution.y * 1.0 - 0.5) * M_PI);
    
    vec3 camPos = vec3(0.0, 0.0, -10.0);
    camPos.yz *= rotYZ;
    camPos.xz *= rotXZ;
    vec3 rayDir = normalize(vec3(uv, 1.0));
    rayDir.yz *= rotYZ;
    rayDir.xz *= rotXZ;
    
    mat3 objRot = objRotMtx();
    vec2 objPar = objParams();
    
    float objType;
    vec4 rmRes = rayMarch(camPos, rayDir, objType, objRot, objPar);
    vec4 col = sceneColor(rmRes, objType, camPos, rayDir, objRot, objPar);
    
    fragColor = col;
}

// [BufferB]
// [iChannel0: BufferA, filter = mipmap, wrap = clamp]

// Horizontal selective blur buffer.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 normCoord = fragCoord / iResolution.xy;
    vec2 coordScale = max(iResolution.x, iResolution.y) / iResolution.xy;
    
    vec3 col = vec3(0.0);
    
    float rMax = 0.03;
    float nSamples = 15.0;
    float sampleStep = 2.0 * rMax / (nSamples - 1.0);
    float weightSum = 0.0;
    
    for (float dx = -rMax; dx <= rMax + 0.1 * sampleStep; dx += sampleStep){
        float curDx = dx * coordScale.x;
        vec2 curCoord = normCoord + vec2(curDx, 0.0);
        vec4 srcCol = textureLod(iChannel0, curCoord, 1.0);
        float curWeight = weightFcn(abs(dx / rMax));
        col += srcCol.xyz * srcCol.w * curWeight;
        weightSum += curWeight;
    }
    
    col *= (1.0 / weightSum);
    fragColor = vec4(col, 1.0);
}

// [Image]
// [iChannel0: BufferA, filter = mipmap, wrap = clamp]
// [iChannel1: BufferB, filter = mipmap, wrap = clamp]

// Vertical selective blur buffer + output.
// Blur is somewhat resolution-dependent.

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 normCoord = fragCoord / iResolution.xy;
    vec2 coordScale = max(iResolution.x, iResolution.y) / iResolution.xy;
    
    vec3 col = vec3(0.0);
    
    float rMax = 0.03;
    float nSamples = 15.0;
    float sampleStep = 2.0 * rMax / (nSamples - 1.0);
    float weightSum = 0.0;
    
    for (float dy = -rMax; dy <= rMax + 0.1 * sampleStep; dy += sampleStep){
        float curDy = dy * coordScale.y;
        vec2 curCoord = normCoord + vec2(0.0, curDy);
        vec4 srcCol = textureLod(iChannel1, curCoord, 1.0);
        float curWeight = weightFcn(abs(dy / rMax));
        col += srcCol.xyz * srcCol.w * curWeight;
        weightSum += curWeight;
    }
    
    col = texture(iChannel0, normCoord).xyz + col * 10.0 / weightSum;
    fragColor = vec4(pow(col, vec3(1.0 / 2.2)), 1.0);
}
