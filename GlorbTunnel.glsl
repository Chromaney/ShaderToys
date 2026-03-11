// Shader "Glorb Tunnel" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Glorb = glow orb :p
// A sizecoding thing I had an idea for while working on the previous shader.

// Version 2. 232 chars.
// diff_01: moved i to o.w, t & s to c.x & c.y, removed float definitions -> -1 char
// diff_02: changed color exp, now softer (hopefully compensates for tonemapping as well) 
// and with shorter code -> -3 chars (after diff_01)
// diff_03: corrected variable sign weirdness from earlier experimentation

void mainImage(out vec4 o, vec2 c){
    // o.w is raymarching loop iteration, c.xy is distance to tunnel and to spheres
    vec3 p, r = iResolution, b; // position, marching direction, sphere position(s)
    // raymarching loop with initialization (z step is 1 as iResolution.z)
    for (o -= o, p.z = iTime, r.xy = (c + c - r.xy) / r.x; o.w ++ < 2e2; 
        // stepping a (scaled) minimal distance to tunnel and spheres
        p += r * .1 * min(c.x = 1. - length(p.xy), c.y = length(p - b) - .5), 
        // adding position-based color with "volume density", only inside tunnel
        o.xyz += c.x * (sin(p) + 1.) / exp(c.y + 5.)
    )
        // partitioning tunnel sections and getting sphere positions
        b = round(p), b.xy = cos(4. * b.z + vec2(5, 0));
}

// Version 1. 236 chars.
/*
void mainImage(out vec4 o, vec2 c){
    float i, t, s; // raymarching loop iteration, distance to tunnel and to spheres
    vec3 p, r = iResolution, b; // position, marching direction, sphere position(s)
    // raymarching loop with initialization (z step is 1 as iResolution.z)
    for (o *= i, p.z = iTime, r.xy = (c + c - r.xy) / r.x; i++ < 2e2; 
        // stepping a (scaled) minimal distance to tunnel and spheres
        p -= r * .1 * max(t = length(p.xy) - 1., s = .4 - length(p - b)), 
        // adding position-based color with "volume density", only inside tunnel
        o.xyz -= t * (sin(p) + 1.) * exp(s + s - 4.)
    )
        // partitioning tunnel sections and getting sphere positions
        b = round(p), b.xy = cos(4. * b.z + vec2(5, 0));
}
*/

// "Reference" version, already optimized, but closer to original idea. 334 chars.
/*
#define K(t) vec2(sin(t), cos(t))

void mainImage(out vec4 o, in vec2 c){
    float i, r, b, f, t = iTime;
    vec2 R = iResolution.xy;
    vec4 p = vec4(.5 * K(t), t, t);
    for (o *= i; i++ < 2e2; \
        p += vec4((c + c - R) / R.x, 1., 0.) * max(abs(.1 * min(r, f)), 3e-3)){
            r = 1. - length(p.xy - .5 * K(p.z));
            b = floor(p.z + .5);
            f = length(p - vec4(.5 * K(b) - 1. * K(b * 4.), b, t)) - .4;
            if (r > 0.)
                o += (sin(p) + 1.) * exp(-f / .4 - 5.);
    }
}
*/
