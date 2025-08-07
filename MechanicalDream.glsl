// Shader "Mechanical Dream" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Tried an approach to generating many objects that relies on 
// combining regular grids of different scale and a lot of randomization.
// With a side of size-coding / code golfing.
// (More like, mechanical nightmare with how none of the gears connect or sync up.)

// With this approach, parallax effects are possible (do not use full UV, then shift object in cell), 
// even if complicated, but changing depth of camera doesn't seem to be.
// Also, wanted to optimize usage of vec4's for size (use mathematical operations on some base ones), 
// but was unable to.

#define F float
#define V vec2
#define W vec4

#define T 6.2832
#define R iResolution.xy

// 4-to-4 "noise"
#define B(v) fract(4273. * v.yzwx * (1. - v.zwxy))
#define N(v) B(B(B(B(fract(v)))))

// cheap smooth "noise"-like function
#define M(x) sin(x * .3 + cos(x) * 2.)

// gear radius limiter (z - point in polar coordinates & rotation angle, l - radius limits)
#define Y(z, l) step(l.x, z.x) * step(z.x, l.y)
// gear angle limiter (z - point in polar coordinates & rotation angle, 
// l - limits (cog number, cog width, base radius))
#define Z(z, l) step(.5 * (1. - l.y * l.z / z.x), abs(fract(ceil(l.x) * (z.y / T + z.z)) - .5))
// gear layer shape (z - same, n - cog number and width, r - inner, middle, outer radii)
#define L(z, n, r) max(Y(z, r.xy), Y(z, r.yz) * Z(z, vec3(n, r.y)))
// full gear shape (z - same, n - cog numbers and widths for two layers, 
// r - radii: inner circle, inner spokes, outer circle, outer cogs)
#define C(z, n, r) max(L(z, n.xz, vec3(0, r.xy)), L(z, n.yw, r.yzw))

W s(V f){ // scene color from pixel coordinates
    F n = 9., v = 1.2, t = iTime + 123.4, H = .5;
    // ^ iteration number, scaling coefficient (and extra non-integer number), 
    // animation time (includes "phase" for cyclic movement and zero shift), .5 shorthand
    V q = (f - H * R) / R.x, w = q * 3.; // base and iteration UV
    W e = W(0), c = e; // fog RG exponent and RG "base" shift, color (RGB) and depth
    // ^ almost no blue, so B component is irrelevant
    c.w = 1.e6;
    
    F b = M(iTime * .02) * 20.; // angular position of "light"
    b = atan(sin(b) - q.y, cos(b) - q.x); // with correction for current position
    
    for(F i = 1.; i < n; i ++){
        w = v * (mat2(.8, .6, -.6, .8) * w + V(2, 5)); // layer UV transformation
        b += atan(.6, .8); // to align with rotational part of UV transformation
        e += (H + H * cos(W(T, T, 1, 1) * w.xyxy * .3 + H * iTime + e.wzyx)) / n; // smooth "noise"
        
        W m = N(W(floor(w) * T + v, (i - v) / n, T)); // 4 random numbers for current cell
        F h = (v + i / n / H) / m.x; // depth
        V p = fract(w) - H; // position in current cell
        W z = W(length(p), atan(p.y, p.x), .2 * m.y * sin(5. * m.z * t) + (m.w * .3 - .15) * t, m.x);
        // ^ polar coordinates, rotaion and extra initial value for random
        // for rotation: .2 * m.y - rotation amplitude, 5. * m.z - rotation frequency, 
        // (m.w * .3 - .15) - constant rotation multiplier
        
        m = N(m); // new random numbers
        W n = W(4, 6, .4, .3) + W(4, 8, .3, .5) * m; // 2 cog counts, 2 cog sizes
        m = N(m);
        
        if (fract(n.y) > .2 && \
            C(z, n, (.4 + .1 * m.w) * W(vec3(.15, .4, .65) + .2 * m.xyz, 1)) > .0 && h < c.w)
            // ^ check "random", gear shape (last parameter - radial tresholds), update if lower depth
            c = W(H * N(z).xxx * pow(abs(cos(z.y - b)), 40.), h);
            // ^ "lighting" with noise; gears are themselves black, colored by fog only
    }
    
    return mix(W(.9, .6, .2, 0), c, exp((.3 + e) * (e.zwxy - c.w))); // variable fog
}

void mainImage(out W c, in V p){
    c = W(0);
    for(int i = 0; i < 9; i ++) // AA loop (3 by 3)
        c += s(p + .5 * V(i / 3, i % 3) - .5) / 9.;
}
