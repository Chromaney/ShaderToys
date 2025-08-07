// Shader "Facets of Unreality" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Another sizecoding thing, this time it started as such. Currently 184 chars.
// Still feels like there's room for improvement, but any modification 
// I managed to find makes the effect way worse.

/*
void mainImage(out vec4 c, in vec2 p){ // 185 chars
    p /= iResolution.x;
    float n = 3., i, q = .03 * iTime;
    for(c = vec4(0); i++ < n; c += p.xyxy * p.xyyx)
        p += mod(p * p + cos((q = n * sin(i + q)) * p.yx + .1 * iTime), \
            p.x * cos(q) + p.y * sin(q));
}
*/

// update; sometimes extra variables are useful
void mainImage(out vec4 c, in vec2 p){ // 184 chars
    p /= iResolution.x;
    float n = 3., i, t = .1 * iTime, q = .3 * t;
    for(c = vec4(0); i++ < n; c += p.xyxy * p.xyyx)
        p += mod(p * p + cos((q = n * sin(i + q)) * p.yx + t), \
            p.x * cos(q) + p.y * sin(q));
}
