// Shader "Happy Fouriyear" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Just wanted to try drawing Fourier-decomposed curves for a while.
// Explicit process is already kinda slow for the current year number though...

// --------------------------------

// [Common]

#define PI 3.1415926536
#define TAU (2.0 * PI)

#define R (iResolution.xy)
#define EPS (1.0 / min(R.x, R.y))
#define T (iTime * 1.0)

#define FREQ_LIM 200.0

vec3 colFromHue(float h){
    return clamp(abs(fract(h - vec3(0.0, 1.0, 2.0) / 3.0) - 1.0 / 2.0) * 6.0 - 1.0, \
        0.0, 1.0);
}

/*vec3 HSVtoRGB(vec3 hsv){
    float h = hsv.x, s = hsv.y, v = hsv.z;
    vec3 rgb = colFromHue(h);
    rgb = mix(vec3(v * (1.0 - s)), vec3(v), rgb);
    return rgb;
}*/

vec2 path(float t){
    //t *= TAU;
    //vec2 p = vec2(0.5 + cos(t * 2.0), -sin(t * 3.0));
    //vec2 p = vec2(0.5 * cos(t * 1.0), sin(t * 1.0));
    //vec2 p = vec2(t, t);
    
    t *= 22.0;
    float part = floor(t);
    vec2 base = vec2(0.0);
    float sect = 0.0;
    float segm = 0.0;
    vec4 pts = vec4(0.0);
    float sz = 0.15;
    
    // (-sz, 2 * sz) (sz, 2 * sz)
    //           O-----O
    //           |  :  |
    //           |  :  |
    //           |  :  |
    //           |  :  |
    //  (-sz, 0) O--*--O (sz, 0)
    //           |  :  |
    //           |  :  |
    //           |  :  |
    //           |  :  |
    //           O-----O
    // (-sz, -2 * sz) (sz, -2 * sz)
    
    if (part < 5.0){ // 2
        base = vec2(-0.75, 0.0);
        sect = 0.0;
        segm = part - 0.0;
        vec4 stEnd[5] = vec4[](
            vec4(-sz, 2.0 * sz, sz, 2.0 * sz), 
            vec4(sz, 2.0 * sz, sz, 0.0), 
            vec4(sz, 0.0, -sz, 0.0), 
            vec4(-sz, 0.0, -sz, -2.0 * sz), 
            vec4(-sz, -2.0 * sz, sz, -2.0 * sz)
        );
        pts = stEnd[int(segm + 0.1)];
    } else if (part < 11.0){ // 0
        base = vec2(-0.25, 0.0);
        sect = 1.0;
        segm = part - 5.0;
        vec4 stEnd[6] = vec4[](
            vec4(-sz, 2.0 * sz, sz, 2.0 * sz), 
            vec4(sz, 2.0 * sz, sz, 0.0), 
            vec4(sz, 0.0, sz, -2.0 * sz), 
            vec4(sz, -2.0 * sz, -sz, -2.0 * sz), 
            vec4(-sz, -2.0 * sz, -sz, 0.0), 
            vec4(-sz, 0.0, -sz, 2.0 * sz)
        );
        pts = stEnd[int(segm + 0.1)];
    } else if (part < 16.0){ // 2
        base = vec2(0.25, 0.0);
        sect = 2.0;
        segm = part - 11.0;
        vec4 stEnd[5] = vec4[](
            vec4(-sz, 2.0 * sz, sz, 2.0 * sz), 
            vec4(sz, 2.0 * sz, sz, 0.0), 
            vec4(sz, 0.0, -sz, 0.0), 
            vec4(-sz, 0.0, -sz, -2.0 * sz), 
            vec4(-sz, -2.0 * sz, sz, -2.0 * sz)
        );
        pts = stEnd[int(segm + 0.1)];
    } else { // 6
        base = vec2(0.75, 0.0);
        sect = 3.0;
        segm = part - 16.0;
        vec4 stEnd[6] = vec4[](
            vec4(sz, 2.0 * sz, -sz, 2.0 * sz), 
            vec4(-sz, 2.0 * sz, -sz, 0.0), 
            vec4(-sz, 0.0, -sz, -2.0 * sz), 
            vec4(-sz, -2.0 * sz, sz, -2.0 * sz), 
            vec4(sz, -2.0 * sz, sz, 0.0), 
            vec4(sz, 0.0, -sz, 0.0)
        );
        pts = stEnd[int(segm + 0.1)];
    }
    
    pts += base.xyxy;
    
    vec2 p = mix(pts.xy, pts.zw, fract(t));
    
    return p;
}

vec4 fourier(float w){
    float n = 100.0 * max(w, 1.0); // ?
    float dt = 1.0 / n;
    vec4 res = vec4(0.0);
    for (float i = 0.0; i < n; i += 1.0){
        float tCurr = dt * i;
        float tNext = tCurr + dt;
        vec2 pathCurr = path(tCurr);
        vec2 pathNext = path(tNext);
        
        float sCurr = tCurr * w * TAU;
        float sNext = tNext * w * TAU;
        vec2 baseCurr = vec2(cos(sCurr), sin(sCurr));
        vec2 baseNext = vec2(cos(sNext), sin(sNext));
        
        vec4 fcnValCurr = vec4(pathCurr.x * baseCurr, pathCurr.y * baseCurr);
        vec4 fcnValNext = vec4(pathNext.x * baseNext, pathNext.y * baseNext);
        
        res += (fcnValCurr + fcnValNext) / 2.0 * dt;
    }
    
    res *= 2.0;
    if (w == 0.0){
        res /= 2.0;
    }
    return res;
}

// [BufferA]
// [iChannel0: BufferA, filter = linear, wrap = clamp]

// Fourier values buffer.

void mainImage(out vec4 col, in vec2 pos){
    if (iFrame == 0){
        col = vec4(0.0);
    } else{
        float pxId = (pos.x - 0.5) + (pos.y - 0.5) * iResolution.x;
        if ((abs(pxId - float(iFrame - 1)) < 0.1) && \
            (iFrame - 1 < int(FREQ_LIM + 1.0))){
            col = fourier(pxId);
        } else {
            col = texelFetch(iChannel0, ivec2(pos), 0);
        }
    }
}

// [BufferB]
// [iChannel0: BufferA, filter = linear, wrap = clamp]
// [iChannel1: BufferB, filter = linear, wrap = clamp]

// Image rendering buffer with trace effect.

void mainImage(out vec4 col, in vec2 pos){
    vec2 uv = 2.0 * (pos - R / 2.0) * EPS;
    
    col = vec4(0.0);
    float t = T * 0.1;
    vec2 pathPos = texelFetch(iChannel0, ivec2(0, 0), 0).xz;
    ivec2 ir = ivec2(R);
    float wMax = min(100.0, FREQ_LIM);
    float wColorId = 0.0;
    float circSz = max(0.01, 3.0 * EPS);
    
    for (float w = 1.0; w < wMax; w += 1.0){
        int iw = int(w);
        vec4 fourierCurr = texelFetch(iChannel0, ivec2(iw % ir.x, iw / ir.x), 0);
        float s = t * w * TAU;
        
        vec2 cP = 0.5 * vec2(fourierCurr.x + fourierCurr.w, 
            -fourierCurr.y + fourierCurr.z);
        vec2 cN = 0.5 * vec2(fourierCurr.x - fourierCurr.w, 
            fourierCurr.y + fourierCurr.z);
        
        if (dot(cP, cP) > min(pow(1.0e-2 / max(w, 1.0), 2.0), 1.0e-6)){
            float rP = length(cP);
            float phP = atan(cP.y, cP.x);
            
            //vec3 curCol = colFromHue((w - 1.0) / (wMax - 1.0) * 10.0);
            vec3 curCol = colFromHue(wColorId / 20.0);
            curCol *= min(pow(rP, 0.5), 1.0) * 2.0;
            col.rgb += vec3(smoothstep(circSz * 3.0, 0.0, length(uv - pathPos))) * curCol;
            col.rgb += vec3(smoothstep(circSz, 0.0, abs(length(uv - pathPos) - rP))) * \
                curCol;
            
            pathPos.x += rP * cos(s + phP);
            pathPos.y += rP * sin(s + phP);
            
            wColorId += 1.0;
        }
        if (dot(cN, cN) > min(pow(1.0e-2 / max(w, 1.0), 2.0), 1.0e-6)){
            float rN = length(cN);
            float phN = atan(cN.y, cN.x);
            
            //vec3 curCol = colFromHue((w - 1.0 + 0.5) / (wMax - 1.0) * 10.0);
            vec3 curCol = colFromHue(wColorId / 20.0);
            curCol *= min(pow(rN, 0.5), 1.0) * 2.0;
            col.rgb += vec3(smoothstep(circSz * 3.0, 0.0, length(uv - pathPos))) * curCol;
            col.rgb += vec3(smoothstep(circSz, 0.0, abs(length(uv - pathPos) - rN))) * \
                curCol;
            
            pathPos.x += rN * cos(-s + phN);
            pathPos.y += rN * sin(-s + phN);
            
            wColorId += 1.0;
        }
        
        // faster, but doesn't allow for neat circle visualization
        /*vec2 c = vec2(cos(s), sin(s));
        pathPos.x += dot(c, fourierCurr.xy);
        pathPos.y += dot(c, fourierCurr.zw);*/
        
        /*
        if (iw % int(wMax / 10.0) == 0){
            col.rgb += smoothstep(circSz * 10.0, 0.0, length(uv - pathPos)) * \
                colFromHue(w / wMax) * 0.5;
        }
        */
    }
    
    col.rgb += vec3(smoothstep(circSz * 10.0, 0.0, length(uv - pathPos))) * 0.5;
    
    if (iFrame == 0){
        col.a = 0.0;
    } else {
        col.a += smoothstep(circSz * 10.0, 0.0, length(uv - pathPos));
        col.a = mix(col.a, texelFetch(iChannel1, ivec2(pos), 0).a, \
            exp(-0.10 * iTimeDelta));
    }
}

// [Image]
// [iChannel0: BufferB, filter = linear, wrap = clamp]

// Main image output.

void mainImage(out vec4 col, in vec2 pos){
    vec4 texCol = texelFetch(iChannel0, ivec2(pos), 0);
    vec3 colGlow = 5.0 * vec3(pow(texCol.a, 0.5)) * colFromHue(texCol.a * 80.0);
    col = vec4(texCol.rgb + colGlow, 1.0);
    
    /*vec2 uv = 2.0 * (pos - R / 2.0) * EPS;
    col.r += smoothstep(0.01, 0.0, abs(abs(uv.x) - 1.0));
    col.g += smoothstep(0.01, 0.0, abs(abs(uv.y) - 1.0));
    col.r += smoothstep(0.01, 0.0, abs(abs(uv.x) - 0.0));
    col.g += smoothstep(0.01, 0.0, abs(abs(uv.y) - 0.0));*/
}
