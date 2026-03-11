// Shader "Aurora128" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A shader for an approximate visual recreation of a 128B ASM Intro 
// I made a few years ago. Also sizecoded, of course.
// Link to repo: https://github.com/Chromaney/DosAsm

void mainImage(out vec4 o, vec2 c){ // 213 chars | -9 from coyote
    vec4 d, i;
    // making vec4(0, 1, 0, 1) - xyz for palette, zw for noise indexing
    d.yw ++;
    // "noise" for mountains in init (o.zw), "waves" on aurora (with base shift)
    for (o = fract(1e4 * sin(ceil(c /= iResolution.y * .1).x + d)); i++.x < 3.; 
        d -= .2 / i * sin(c.x * exp(i) + iTime * i) + .8 - abs(c.y * .2 - .7));
    // blank below mountain contour; Y-symmetric palette above, "indexed" by height
    o = c.y < mix(o.z, o.w, fract(c.x)) + 2. ? o - o : 1. - .6 * abs(d);
}

/*
void mainImage(out vec4 o, vec2 c){ // 222 chars
    c /= iResolution.y * .1;
    float i;
    vec4 d;
    // making vec4(0, 1, 0, 1) - xyz for palette, zw for noise indexing
    d.w = ++ d.y;
    // "noise" for mountains in init (o.zw), "waves" on aurora (with base shift)
    for (o = fract(1e4 * sin(ceil(c.x) + d)); i++ < 3.; 
        d -= .2 / i * sin(c.x * exp(i) + iTime * i) + .8 - abs(c.y * .2 - .7));
    // blank below mountain contour; Y-symmetric palette above, "indexed" by height
    o = c.y < mix(o.z, o.w, fract(c.x)) + 2. ? o - o : 1. - .6 * abs(d);
}
*/
