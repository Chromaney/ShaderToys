// Shader "Semiconductor" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// An attempt at learning different raymarching techniques.
// Some intended effects had to be cut to keep FPS reasonable.

// Change VIEW_SCALE values (0+ to 1 floats) to make render area smaller for performance concerns.

#define VIEW_SCALE vec2(1.0, 1.0)

#define M_PI 3.1415926536

#define RM_MAX_ITER 100
#define RM_MAX_DIST 40.0
#define RM_PROX_DIST 0.001
#define RM_SURF_EPS 0.7

#define NORM_COORD_STEP 0.001
#define NORM_COORD_STEP_VEC vec3(NORM_COORD_STEP, 0.0, 0.0)

#define FOG_COLOR vec3(0.5, 0.7, 0.7)
#define LIGHT_DIR vec3(0.0, 1.0, 0.0)
// ^ already normalized

#define LATTICE_STEP vec3(5.0, 15.0, 5.0)
#define LATTICE_BASE_DIST min(LATTICE_STEP.x, min(LATTICE_STEP.y, LATTICE_STEP.z))
#define ITEM_BASE_SIZE (0.25 * LATTICE_BASE_DIST)
// ^ should account for all shapes with rotation

#define ROT_MTX(ang) mat2(cos(ang), -sin(ang), sin(ang), cos(ang))
// ^ applied from right

float sphereShellSDF(vec3 pos, vec2 r){
    // centered on vec3(0.0)
    return (abs(length(pos) - r.x) - r.y);
}

float octahedronSDF(vec3 pos, float a){ // approximation
    // centered on vec3(0.0)
    pos = abs(pos);
    return ((pos.x + pos.y + pos.z - a) * 0.57735027);
}

vec2 sceneDistField(vec3 pos){
    // returns vec2(distance_to_scene, object_type)
    
    vec3 latticeBlock = floor(pos / LATTICE_STEP);
    vec2 res = vec2(1.0e6, -0.5);
    
    // can't reduce the amount of checked blocks because of asymmetries between them
    vec3 blockMiddle = (latticeBlock + 0.5) * LATTICE_STEP;
    for (float idX = -1.0; idX < 1.5; idX += 1.0){
        for (float idZ = -1.0; idZ < 1.5; idZ += 1.0){
            vec3 blockShift = vec3(idX, 0, idZ);
            vec2 curBlockXZ = latticeBlock.xz + blockShift.xz;
            float curBlockXZSum = curBlockXZ.x + curBlockXZ.y + 0.5;
            float objType = mod(curBlockXZSum, 2.0);
            float mvtDir = objType * 2.0 - 2.0;
            float wrapPosYShift = mvtDir * fract(
                iTime * (mod(curBlockXZSum, 4.0) / 4.0) / LATTICE_STEP.y + 
                curBlockXZ.x / 3.0) * LATTICE_STEP.y;
            // ^ mod part can't be zero since sampled only at integer points
            vec3 wrapPos = pos - blockMiddle - blockShift * LATTICE_STEP;
            wrapPos.zx *= ROT_MTX(curBlockXZ.x - curBlockXZ.y + mvtDir * iTime);
            for (float dY = -LATTICE_STEP.y; dY < 1.5 * LATTICE_STEP.y; dY += LATTICE_STEP.y){
                wrapPos.y = pos.y + wrapPosYShift - blockMiddle.y - dY;
                // ^ trying to replace with "wrapPos.y += LATTICE_STEP.y" causes octahedrons to disappear

                float dist;
                if (objType < 1.0){ // cut sphere
                    float mainSphereDist = sphereShellSDF(wrapPos, ITEM_BASE_SIZE * vec2(1.0, 0.15));
                    float cutSphereDist = sphereShellSDF(
                        abs(wrapPos) - 0.95 * vec3(1.0, 1.0, 1.0) * ITEM_BASE_SIZE, 
                        ITEM_BASE_SIZE * vec2(1.0, 0.1));
                    dist = max(mainSphereDist, -cutSphereDist);
                } else { // octahedron
                    dist = octahedronSDF(wrapPos, ITEM_BASE_SIZE * 1.75);
                } // no empty blocks

                if (dist < res.x){
                    res.x = dist;
                    res.y = objType;
                }
            }
        }
    }
    
    return res;
}

vec3 sceneNorm(vec3 pos){
    float sdfShX = sceneDistField(pos + NORM_COORD_STEP_VEC.xzy).x;
    float sdfShY = sceneDistField(pos + NORM_COORD_STEP_VEC.yxz).x;
    float sdfShZ = sceneDistField(pos + NORM_COORD_STEP_VEC.zyx).x;
    return normalize(vec3(sdfShX, sdfShY, sdfShZ) - sceneDistField(pos).x);
}

vec4 rayMarch(vec3 origin, vec3 dir){
    float dist = 0.0;
    float objType = -0.5;
    
    for (int iter = 0; iter < RM_MAX_ITER; iter ++){
        vec3 pos = origin + dir * dist;
        vec2 sceneDistFieldRes = sceneDistField(pos);
        float curStep = sceneDistFieldRes.x;
        dist += curStep;
        objType = sceneDistFieldRes.y;
        if (abs(curStep) < RM_PROX_DIST){
            break;
        }
        if (dist > RM_MAX_DIST){
            break;
        }
    }
    
    vec3 pos = origin + dir * dist;
    
    vec3 curSceneNorm = sceneNorm(pos);
    float diffLightVal = max(curSceneNorm.y, 0.0); // simplified from dot(curSceneNorm, LIGHT_DIR)
    vec3 halfway = normalize(LIGHT_DIR + (origin - pos));
    float surfColorCoeff = dot(curSceneNorm, dir);
    // ^ technically, should be -dir, but is squared later
    surfColorCoeff *= surfColorCoeff;
    
    float reflLightVal = 0.0;
    vec3 baseCol = vec3(0.6, 0.2, 1.0); // default for cubes
    
    if (objType < 0.0){
        // infinity / object not reached (infinity picks up properties as well, so needs fog now)
        diffLightVal = 1.0;
        baseCol = FOG_COLOR;
    } else if (objType < 1.0){ // cut sphere
        reflLightVal = pow(max(dot(halfway, curSceneNorm), 0.0), 200.0);
        baseCol = vec3(1.0, 0.1 + 0.5 * surfColorCoeff, 0.1); // shortened from mix
    } else { // octahedron
        reflLightVal = pow(max(dot(halfway, curSceneNorm), 0.0), 10.0);
    } // no empty blocks
    reflLightVal *= clamp(diffLightVal / 0.2, 0.0, 1.0);
    
    diffLightVal = diffLightVal * 0.75 + 0.25; // so that bottom surfaces also have color
    vec3 col = FOG_COLOR * baseCol * (diffLightVal + reflLightVal);
    // ^ fog color acts as light color as well
    
    return vec4(col, dist);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 uvExtent = 0.5 * VIEW_SCALE * iResolution.xy / iResolution.y;
    
    vec3 col = vec3(0.0);
    
    if ((abs(uv.x) < uvExtent.x) && (abs(uv.y) < uvExtent.y)){
        uv /= min(VIEW_SCALE.x, VIEW_SCALE.y);
        
        vec2 mousePos = iMouse.xy;
        if (iMouse.z == 0.0){
            mousePos = vec2(0.5, 0.5) * iResolution.xy;
        }
        mat2 rotXZ = ROT_MTX((mousePos.x / iResolution.x * 2.0 - 1.0) * M_PI);
        mat2 rotYZ = ROT_MTX((mousePos.y / iResolution.y * 1.0 - 0.5) * M_PI);

        vec3 camPos = vec3(0.0, 0.0, -5.0);
        camPos.yz *= rotYZ;
        camPos.xz *= rotXZ;
        vec3 rayDir = normalize(vec3(uv, 1.0));
        rayDir.yz *= rotYZ;
        rayDir.xz *= rotXZ;

        vec4 rmRes = rayMarch(camPos, rayDir);
        col = rmRes.xyz;

        float normDist = min(rmRes.w / RM_MAX_DIST, 1.0);
        normDist = 1.0 - exp(-normDist * (RM_MAX_DIST / 10.0));
        col = mix(col, FOG_COLOR, normDist);
    }
    
    fragColor = vec4(pow(col, vec3(1.0 / 2.2)), 1.0);
}
