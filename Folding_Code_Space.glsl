// Shader "Folding (Code) Space" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A result of playing around with macros and general code weirdness.
// And some sizecode-y stuff as well.

// Current size: 188 chars (but counting in #define seems off).

#define G(t, q, k) t[q % 4] *= t[(q - 1) % 4] - cos(k * t[q % 4])

void mainImage(out vec4 o, vec2 c){
    o = c.yxyx / iResolution.x;
    for(int i; i++ < 15; o += cos(o.wzyx) + sin(o.yzwx - iTime / float(i)))
        G(o, i % 3, G(o, i % 5, o.y));
}
