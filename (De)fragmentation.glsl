// Shader "(De)fragmentation" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// A sizecoding / codegolfing exercise for a neat randomly discovered visual effect.
// Currently 240 characters, according to Shadertoy.
// Name is because of visual similarity to Windows defragmentation tool icon 
// and to the process itself.

void mainImage(out vec4 c, in vec2 p){
    p /= iResolution.x;
    float i, v, n = 8., h = .5;
    // ^ n - number of iterations and a random constant, h - .5 shorthand.
    for(c = vec4(0); i++ < n; \
        c += (h + cos(i * n + v * n + vec4(0, 4, 2, 0))) * pow(v, n) / sqrt(i)){
        // ^ stripped down "hue to color", with variations by layer and position 
        // in pattern; intensity also depends on position in pattern and layer number
        v = i * iTime / n; // time-dependent value
        p += h * vec2(-p.y, p.x) + n + h * sin(p + v / n);
        // ^ coordinate transform (scaling + rotation imitation + shift + "random" part)
        v = fract(p.x + (fract(p.y - p.x) - h) * (h + h * sin(v)));
        // ^ split-merge pattern
    }
}
