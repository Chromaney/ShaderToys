// Shader "Squiral" by Chromaney.
// Code and resulting images are licensed under a 
// Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Just a square spiral.
// Originally had an idea to do sizecoded four-color spiral with st_assert, 
// but RGB turned out to be shorter.

// Apparently, % doesn't count as a character in code size (and following one as well?).
// It also sometimes behaves weirdly, so changed to &.


void mainImage(out vec4 o, vec2 c){ // 182 chars
    // coordinate preparation, can be / 8. or sth, but too annoying to look at
    c = ceil((c + c - iResolution.y) / 32.);
    // quadrant selection (init with correction on diagonals), 
    // o.xy - signs of difference and sum of coords with a shift
    int q = dot(c, o.xy = sign(mat2(1, 1, -1, 1) * c + 1.)) > 0. ? 1 : 0;
    // proper quadrant selection (R = 0, T = 1, L = 2, B = 3)
    q += (o.x > 0. ? 2 : 1) ^ int(o.y > 0.);
    // reset out variable
    o -= o;
    // select appropriate axis, then shift value on it and index by it (RGBA) into output
    o[(ivec4(c, -c)[q & 3] - q) & 3] ++;
}


/*
void mainImage(out vec4 o, vec2 c){ // another tested approach, rough version
    c = floor((c + c - iResolution.xy) / 32.);
    o.xy = abs(c);
    float l = max(o.x, o.y);
    int q, f = 2 * int(l == c.x) + int(l == -c.y);
    if (l == c.x)
        q = 0;
    if (l == c.y)
        q = 1;
    if (l == -c.x)
        q = 2;
    if (l == -c.y)
        q = 3;
    //if ((o.x == o.y) && !((c.x > 0.) && (c.y < 0.)))
    //    q --;
    if (o.x == o.y)
        q = ivec4(1, 2, 0, 3)[f]; // 00 -> 01, 01 -> 10, 10 -> 00, 11 -> 11
    o -= o;
    o[(1 * q - 1 * int(l)) & 3] ++;
    //o = vec4(.5 - floor(c.x / l) * .5);
}
*/

/*
void mainImage(out vec4 o, vec2 c){ // failed attempt
    c = ((c + c - iResolution.xy) / 32.);
    c = mix(ceil(c), floor(c), sign(c) * .5 + .5);
    int q = (c.x > c.y) ? 1 : 0;
    q += (c.x > -c.y) ? 2 : 0; // R - 3, T - 2, L - 0, B - 1
    o -= o;
    o[(ivec4(-c, c.yx)[q] - q + ((q == 3) ? 1 : 0) + ((q == 2) ? -1 : 0)) & 3] ++;
    //o[q & 3] ++;
}
*/

/*
void mainImage(out vec4 o, vec2 c){ // base version, 226 chars
    c = (c - iResolution.xy / 2.) / 8.;
    o = vec4(ceil(c), c.x - c.y, c.x + c.y);
    int q = (o.z > 0.) ? 0 : 1;
    q = (o.w > 0.) ? q : (3 - q);
    if (((o.z > 0.) ? o.x : (1. - o.x)) + ((o.w > 0.) ? o.y : (1. - o.y)) <= 1.) q --;
    o -= o; o[(ivec4(c, -c)[q % 4] - q + 4) % 4] ++;
    //st_assert(1 < 0, ivec4(0, 2, 1, 3)[(ivec4(c, -c)[q % 4] - q + 4) % 4]); // alt
}
*/
