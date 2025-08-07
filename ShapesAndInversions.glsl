// Shader "Shapes and Inversions" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Playing around with the idea of inversive geometry.

#define M_PI 3.1415926536

#define EPS (1.0 / max(iResolution.x, iResolution.y))
#define X_MAX (0.5 * iResolution.x / max(iResolution.x, iResolution.y))
#define Y_MAX (0.5 * iResolution.y / max(iResolution.x, iResolution.y))
#define XY_MAX (min(X_MAX, Y_MAX))
#define AXIS_MAX (10.0 / (XY_MAX * XY_MAX))

// short noise function
#define nb(x) (fract(4681.75078 * x * (1.0 - x)))
#define noise(x) (nb(nb(nb(x))))

mat2 rotMtx(float ang){
    float c = cos(ang), s = sin(ang);
    return mat2(c, s, -s, c);
}

float smoothRand(float t, float base){
    float d = 0.0001;
    float a1 = d * floor(t) + base;
    float a2 = d * (floor(t) + 1.0) + base;
    return mix(noise(a1), noise(a2), smoothstep(0.0, 1.0, fract(t)));
}

vec2 invert(vec2 pt, vec3 par){
    vec2 ptRel = pt - par.xy;
    vec2 invPtRel = ptRel / max(dot(ptRel / par.z, ptRel / par.z), EPS);
    return (invPtRel + par.xy);
}

vec2 distCirc(vec2 pt, vec3 par){
    return vec2(length(pt - par.xy) - par.z, 0.0);
}

vec2 distLine(vec2 pt, vec3 par){
    return vec2(dot(vec3(pt, 1.0), par) / length(par.xy), 1.0);
}

vec2 distSegm(vec2 pt, vec2 p1, vec2 p2){
    // unsigned distance, so gradient issues around distance == 0
    float t = dot(pt - p1, p2 - p1) / dot(p2 - p1, p2 - p1);
    t = clamp(t, 0.0, 1.0);
    return vec2(length(mix(p1, p2, t) - pt), 0.0);
}

vec2 distPoly(vec2 pt, int n, vec2 c, vec2 p0){
    float dist = 1.0e6;
    float side = -1.0; // fixing unsigned distance issue
    vec2 pp = p0;
    for (int i = 0; i < n; i ++){
        vec2 pi = c + rotMtx(2.0 * M_PI / float(n)) * (pp - c);
        dist = min(dist, distSegm(pt, pp, pi).x);
        if ((side < 0.0) && (cross(vec3(pi - pp, 0.0), vec3(pt - pp, 0.0)).z < 0.0)){
            side = 1.0;
        }
        pp = pi;
    }
    return vec2(dist * side, 0.0);
}

vec2 distSecOrd(vec2 pt, vec3 ch, vec3 cl){
    // not exact, based on implicit form
    float dist = ch.x * pt.x * pt.x + ch.y * pt.y * pt.y + ch.z * pt.x * pt.y + \
        cl.x * pt.x + cl.y * pt.y + cl.z;
    float isInf = float(ch.z * ch.z - 4.0 * ch.x * ch.y >= 0.0);
    return vec2(dist, isInf);
}

vec2 distSine(vec2 pt, vec2 dir, vec2 p0, vec4 par){
    // not exact
    vec2 ab = vec2(dir.y, -dir.x);
    float dist = distLine(pt, vec3(ab, -dot(ab, p0))).x;
    vec2 p1 = p0 + normalize(dir);
    float t = dot(pt - p0, p1 - p0); // denominator simplifies to 1
    dist += par.x * sin(2.0 * M_PI * (par.y * t + par.z)) * exp(- t * t / par.w / par.w);
    // ^ exp to fix "noise" caused by fast oscillations at infinity
    return vec2(dist, 1.0);
}

vec3 selectAround(vec2 dist, float tresh){
    vec2 grad = vec2(dFdx(dist.x), dFdy(dist.x)) / EPS;
    float res = max(1.0 - abs(dist.x) / length(grad) / tresh, 0.0);
    if (dist.y < 0.5){
        /*if ((abs(dist.x) > 1.0e-3) && (length(grad) > 5.0e2)) // can interact with tresh if too low
            res = 0.0;*/
        float distTresh = 1.0e-3;
        float gradTresh = 1.0e2; // could be higher, but then circle center dot shows
        float extent = 2.0;
        res *= max(smoothstep(extent * distTresh, distTresh, abs(dist.x)), \
            smoothstep(extent * gradTresh, gradTresh, length(grad)));
    }
    return vec3(res, log2(1.0 + dist.x) * 0.50, log2(1.0 + length(grad)) * 0.10);
}

float valueCirc(vec2 pt, vec3 par, float tresh){
    vec2 dist = distCirc(pt, par);
    return selectAround(dist, tresh).x;
}

float valueLine(vec2 pt, vec3 par, float tresh){
    vec2 dist = distLine(pt, par);
    return selectAround(dist, tresh).x;
}

float valuePoly(vec2 pt, int n, vec2 c, vec2 p0, float tresh){
    vec2 dist = distPoly(pt, n, c, p0);
    return selectAround(dist, tresh).x;
}

float valueSecOrd(vec2 pt, vec3 ch, vec3 cl, float tresh){
    vec2 dist = distSecOrd(pt, ch, cl);
    return selectAround(dist, tresh).x;
}

float valueSine(vec2 pt, vec2 dir, vec2 p0, vec4 par, float tresh){
    vec2 dist = distSine(pt, dir, p0, par);
    return selectAround(dist, tresh).x;
}

vec3 getColor(vec2 uv, float t){
    float lineW = 0.008;
    vec3 parCirc = vec3(
        (smoothRand(t, 0.7) * 2.0 - 1.0) * X_MAX, 
        (smoothRand(t, 0.4) * 2.0 - 1.0) * Y_MAX, 
        (smoothRand(t, 0.1) * 1.8 + 0.2) * XY_MAX
    );
    vec3 parLine = vec3(
        cos(smoothRand(t, 0.8) * 2.0 * M_PI), 
        sin(smoothRand(t, 0.8) * 2.0 * M_PI), 
        (smoothRand(t, 0.2) * 2.0 - 1.0) * XY_MAX
    );
    vec2 parPolyCenter = vec2(
        (smoothRand(t, 0.15) * 1.5 - 0.75) * X_MAX, 
        (smoothRand(t, 0.85) * 1.5 - 0.75) * Y_MAX
    );
    vec2 parPolyPoint = rotMtx(smoothRand(t, 0.5) * 2.0 * M_PI) * vec2(
        (smoothRand(t, 0.55) * 1.0 - 0.5) * X_MAX, 
        (smoothRand(t, 0.45) * 1.0 - 0.5) * Y_MAX
    );
    vec4 parTfSecOrd = vec4(
        (smoothRand(t, 0.43) * 1.5 - 0.75) * X_MAX, 
        (smoothRand(t, 0.98) * 1.5 - 0.75) * Y_MAX, 
        cos(-smoothRand(t, 0.57) * 2.0 * M_PI), 
        sin(-smoothRand(t, 0.57) * 2.0 * M_PI)
    );
    vec2 parBaseSecOrd = vec2(
        (smoothRand(t, 0.21) * 2.0 - 1.0) * AXIS_MAX, 
        (smoothRand(t, 0.06) * 2.0 - 1.0) * AXIS_MAX
    );
    if ((parBaseSecOrd.x < 0.0) && (parBaseSecOrd.y < 0.0)){
        parBaseSecOrd = -parBaseSecOrd;
    }
    vec3 parSecOrdHigh = vec3(
        parBaseSecOrd.x * parTfSecOrd.z * parTfSecOrd.z + \
            parBaseSecOrd.y * parTfSecOrd.w * parTfSecOrd.w, 
        parBaseSecOrd.x * parTfSecOrd.w * parTfSecOrd.w + \
            parBaseSecOrd.y * parTfSecOrd.z * parTfSecOrd.z, 
        2.0 * parTfSecOrd.z * parTfSecOrd.w * (parBaseSecOrd.y - parBaseSecOrd.x)
    );
    vec3 parSecOrdLow = vec3(
        -2.0 * parTfSecOrd.x * parSecOrdHigh.x - parTfSecOrd.y * parSecOrdHigh.z, 
        -2.0 * parTfSecOrd.y * parSecOrdHigh.y - parTfSecOrd.x * parSecOrdHigh.z, 
        + parTfSecOrd.x * parTfSecOrd.x * parSecOrdHigh.x + \
            parTfSecOrd.y * parTfSecOrd.y * parSecOrdHigh.y + \
            parTfSecOrd.x * parTfSecOrd.y * parSecOrdHigh.z - \
            1.0
    );
    vec2 parSineDir = vec2(
        cos(smoothRand(t, 0.9) * 2.0 * M_PI), 
        sin(smoothRand(t, 0.9) * 2.0 * M_PI)
    );
    vec2 parSinePoint = vec2(
        (smoothRand(t, 0.6) * 2.0 - 1.0) * X_MAX, 
        (smoothRand(t, 0.3) * 2.0 - 1.0) * Y_MAX
    );
    vec4 parSineParam = vec4(
        (smoothRand(t, 0.20) * 0.4 + 0.2) * XY_MAX, 
        (smoothRand(t, 0.45) * 8.0 + 8.0) * XY_MAX, 
        t, 
        1.0
    );
    
    vec3 colCirc = vec3(1.0, 0.1, 0.1) * 
        valueCirc(uv, parCirc, lineW);
    vec3 colLine = vec3(1.0, 0.6, 0.1) * 
        valueLine(uv, parLine, lineW);
    vec3 colPoly = vec3(1.0, 1.0, 0.1) * 
        valuePoly(uv, 5, parPolyCenter, parPolyPoint, lineW);
    vec3 colSecOrd = vec3(0.5, 1.0, 0.1) * 
        valueSecOrd(uv, parSecOrdHigh, parSecOrdLow, lineW);
    vec3 colSine = vec3(1.0, 0.1, 1.0) * 
        valueSine(uv, parSineDir, parSinePoint, parSineParam, lineW);
    vec3 col = colCirc + colLine + colPoly + colSecOrd + colSine;
    // ^ having many shapes hides issues near circle center
    return col;
}

vec3 getInvCircCol(vec2 uv, vec3 par, float t, vec3 steps){
    float lineW = 0.04 * (1.0 + 5.0 * sin(fract(steps.y) * M_PI));
    vec3 col = vec3(0.1, 1.0, 1.0) * pow(valueCirc(uv, par, lineW), 3.0);
    float baseAng = atan(uv.y - par.y, uv.x - par.x) / M_PI * 0.5 + 0.5;
    float effRotSpd = 2.0 * (1.0 + 3.0 * sin(fract(steps.x) * M_PI));
    float colMul = smoothRand(mod(baseAng + effRotSpd * t, 1.0) * 400.0, 0.25);
    colMul += (smoothRand(mod(baseAng - 1.71 * effRotSpd * t, 1.0) * 300.0, 0.75) * 0.5 - 0.25);
    col *= max(colMul, 0.0);
    return col;
}

vec3 threeStep(float t, vec3 st){
    vec3 s = vec3(st.x) + vec3(0.0, vec2(st.y)) + vec3(vec2(0.0), st.z);
    float base = floor(t / s.z);
    float ex = mod(t, s.z);
    vec3 res = (ex - vec3(0.0, s.xy)) / st;
    return (base + clamp(res, 0.0, 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / max(iResolution.x, iResolution.y);
    
    float t = iTime / 10.0;
    vec3 steps = threeStep(t, vec3(0.3, 0.1, 0.6));
    
    vec3 invCircParams = vec3(
        (smoothRand(steps.x, 0.000) * 2.0 - 1.0) * X_MAX, 
        (smoothRand(steps.x, 0.333) * 2.0 - 1.0) * Y_MAX, 
        (smoothRand(steps.y, 0.667) * 0.6 + 0.4) * XY_MAX
    );
    
    vec3 col = getColor(uv, steps.z);
    vec3 invCircCol = getInvCircCol(uv, invCircParams, t, steps);
    uv = invert(uv, invCircParams);
    vec3 invCol = getColor(uv, steps.z);
    
    col = 0.33 * col + 1.0 * invCol + 1.0 * invCircCol;
    col += 0.33 * pow(col, vec3(0.5)); // "glow"
    fragColor = vec4(col, 1.0);
}
