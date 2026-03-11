// Shader "Bendy Light Show" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// What if light somehow was affected by close objects and even its color?
// I mean, that's how it actually works, but rarely on a perceivable scale.
// And this just looks cool.

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R (iResolution.xy)
#define EPS (1.0 / max(R.x, R.y))
#define T (iTime * 1.0)

#define RM_MAX_ITER 700.0
#define RM_MAX_DIST 15.0
#define RM_PROX_DIST 0.005

#define GRID_STEP 3.0
#define SPH_SZ 1.0

mat2 rotMtx(float ang){
    float c = cos(ang), s = sin(ang);
    return mat2(c, s, -s, c);
}

void setCamera(vec2 uv, out vec3 orig, out vec3 dir){
    vec2 mousePos = iMouse.xy;
    if (iMouse.z == 0.0){
        mousePos = vec2(0.75, 0.75) * R;
    }
    mat2 rotXZ = rotMtx(-(mousePos.x / R.x * 2.0 - 1.0) * PI);
    mat2 rotYZ = rotMtx(-(mousePos.y / R.y * 1.0 - 0.5) * PI);

    orig = vec3(0.0);
    dir = normalize(vec3(uv, 0.5));
    dir.yz = rotYZ * dir.yz;
    dir.xz = rotXZ * dir.xz;
}

vec4 sceneDistField(vec3 pos){
    vec3 relPos = mod(pos, GRID_STEP) - 0.5 * GRID_STEP;
    float dist = length(relPos) - SPH_SZ;
    return vec4(relPos * sign(dist), dist);
}

vec3 sceneVolColor(vec3 pos){
    vec3 cell = floor(pos / GRID_STEP) + 0.5 * GRID_STEP;
    vec3 col = sin(cell * 0.1 * vec3(42.7, 53.1, 37.1) + \
        iTime * 0.2 * vec3(0.73, 0.67, 0.56)) * 0.3 + 0.7;
    return col;
}

vec4 rayMarch(vec3 orig, vec3 dir, out float iter, out vec3 accumLight){
    accumLight = vec3(0.0);
    float dist = 0.0;
    vec3 pos = orig;
    for (iter = 0.0; (iter < RM_MAX_ITER) && (dist < RM_MAX_DIST); iter += 1.0){
        vec4 sdfRes = sceneDistField(pos);
        float curStep = max(abs(sdfRes.w * 0.1), RM_PROX_DIST);
        vec3 curNorm = sdfRes.xyz;
        
        vec3 svc = sceneVolColor(pos);
        accumLight += svc * smoothstep(1.0, 0.0, curStep / 0.05) * \
            0.05 / (0.01 + dist * dist);
        
        vec3 colInfl = sin(svc * TAU);
        float effStr = smoothstep(1.0, 0.0, \
            curStep / (0.1 * (GRID_STEP - 2.0 * SPH_SZ)));
        dir = dir - 0.002 * effStr * curNorm;
        dir = dir + 0.002 * effStr * colInfl;
        dir = dir + 0.002 * effStr * cross(curNorm, colInfl);
        dir = normalize(dir);
        
        dist += curStep;
        pos += dir * curStep;
    }
    
    return vec4(pos, dist);
}

void mainImage(out vec4 col, in vec2 pos){
    vec2 uv = (pos - R / 2.0) * EPS;
    vec3 camPos, rayDir;
    setCamera(uv, camPos, rayDir);
    
    float iter;
    vec3 accumLight;
    vec4 rmRes = rayMarch(camPos, rayDir, iter, accumLight);
    col = vec4(tanh(accumLight), 1.0);
}
