// Shader "Christmas Forest" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Using sizecoded Truchet pattern for seasonally thematic imagery.


void mainImage(out vec4 o, vec2 c){
    // 285 chars
    // -3 by FabriceNeyret2
    o = vec4(1, -1, fract(c /= iResolution.y / 20.) * 3.14);
    c = ceil(c);
    float p = abs(mod(c.x, 14.) - 7.5), 
          q = c.y - 16.5 + 3. * p, 
          m = o[int(c + c.y) & 1];
    o.zw += o.yx * (o.z *= 
        p < 5. && q == 0. 
        //^^ p < 1. && abs(abs(q) - 2.5) < 1. 
        //^^ p < 1. && abs(abs(q + 8.5) - 2.) < 1. 
        ^^ p < 1. && abs(abs(abs(q + 4.3) - 4.4) - 2.2) < 1. // merged, unstable
        ^^ p == 2.5 && q == -6. 
        ^^ q > 7. 
        ^^ c.y < 2. 
    ? -m : m);
    o *= (cos(o) * cos(o + o)).w * m;
}

/*
void mainImage(out vec4 o, vec2 c){ // 288 chars
    o = vec4(1, -1, fract(c /= iResolution.y / 20.) * 3.14);
    c = ceil(c); // c -= o.zw; causes artifacts (and requires different values later)
    float p = abs(mod(c.x, 14.) - 7.5), 
          q = c.y - 16.5 + 3. * p, 
          m = o[int(c + c.y) & 1];
    o.zw += o.yx * (o.z *= (
        p < 5. && q == 0. 
        //^^ p < 1. && abs(abs(q) - 2.5) < 1. 
        //^^ p < 1. && abs(abs(q + 8.5) - 2.) < 1. 
        ^^ p < 1. && abs(abs(abs(q + 4.3) - 4.4) - 2.2) < 1. // merged, unstable
        ^^ p == 2.5 && q == -6. 
        ^^ q > 7. 
        ^^ c.y < 2. 
    ) ? -m : m);
    o *= cos(o.w) * cos(o.w * 2.) * m;
}
*/
