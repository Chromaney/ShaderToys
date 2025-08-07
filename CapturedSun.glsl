// Shader "Captured Sun" by Chromaney.
// Licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Shader that started as a way to put to use a cool smooth noise texture that I stumbled upon 
// while making https://www.shadertoy.com/view/XXyBzy.
// Uses some pseudo-3D visuals.

#define T (2.0 * 3.1415926536)
#define R iResolution.xy
#define EPS (1.0 / max(R.x, R.y))

// "random" value function
#define rand(v) (fract(sin(dot(v, vec3(113.5, 271.9, 124.6))) * 43758.5453123))

mat2 rotMtx(float ang){
    // rotation matrix
    float c = cos(ang), s = sin(ang);
    return mat2(c, s, -s, c);
}

vec3 palette(vec2 t){
    vec3 baseCol = mix(vec3(0.9, 0.3, 0.1), vec3(1.0, 0.7, 0.2), t.x);
    vec3 col = pow(baseCol, vec3(t.y * 5.0));
    return col;
}

vec3 getBaseColor(vec2 uv){
    // smooth noise + palette on it
    float scale = 1.15; // domain scaling factor
    float n = 9.0; // number of iteration with lessening scale
    vec2 e = vec2(0.0); // first noise variable
    vec2 d = vec2(0.0); // second noise variable
    uv *= 3.0;
    for(float i = 1.0; i <= n; i ++){
        uv = scale * (rotMtx(T * 0.427) * uv + vec2(2.27, -4.58)); // domain transformation
        e += cos(T * uv + 0.5 * iTime + d.xy);
        d += cos(1.0 * uv + 0.5 * iTime + e.yx);
    }
    d = d / n * 0.5 + 0.5; // value scaling
    //e = e / n * 0.5 + 0.5;
    return palette(d);
}

vec3 triang(in vec2 p, out vec2 v1, out vec2 v2, out vec2 v3){
    // calculates vertices of triangle where p lies and its barycentric coordinates
    // triangle orientation is variable
    vec2 b1 = vec2(0.0, 1.0); // base triangle axes (as coefficients in ax + by = 0)
    vec2 b2 = vec2(sqrt(3.0), -1.0);
    vec2 b3 = vec2(sqrt(3.0), 1.0);
    float d1 = dot(p, b1) / length(b1); // trilinear coordinates
    float d2 = dot(p, b2) / length(b2);
    float d3 = dot(p, b3) / length(b3); // == d1 + d2
    vec3 c = vec3(d1, d2, d3);
    
    float type = mod(dot(floor(c), vec3(1.0)), 2.0); // triangle orientation (^ or v)
    
    c = fract(c);
    c.z = 1.0 - c.z;
    
    mat2 forw = transpose(mat2(normalize(b1), normalize(b2))); // coordinate transform
    mat2 backw = inverse(forw); // same, from trilinear to cartesian
    v1 = vec2(ceil(d1), floor(d2)); // vertices in trilinear coordinates (first two are sufficient)
    v2 = vec2(floor(d1), ceil(d2));
    v3 = vec2(floor(d1), floor(d2));
    
    if (type > 0.5){
        c = 1.0 - c;
        v1 = vec2(floor(d1), ceil(d2));
        v2 = vec2(ceil(d1), floor(d2));
        v3 = vec2(ceil(d1), ceil(d2));
    }
    
    v1 = backw * v1;
    v2 = backw * v2;
    v3 = backw * v3;
    
    return c;
}

vec3 getSceneCol(vec2 fragCoord){
    // function to get scene color from position
    float uvSc = 2.5; // uv scaling for foreground
    vec2 uv00 = (fragCoord - 0.5 * R) * EPS; // default uv
    vec2 uv0 = (fragCoord - 0.5 * R) * EPS * uvSc; // modified uv
    
    float rn = length(uv00) / sqrt(1.0 - dot(uv00, uv00));
    float an = atan(uv00.y, uv00.x);
    uv0 = rn * vec2(cos(an), sin(an)) * uvSc; // add "spherical" effect
    
    vec2 duv = vec2(iTime * 0.07);
    uv0 += duv; // move uv (looks like rotation)
    
    float scale = 1.5; // grid scale factor
    float n = 2.0; // number of grids
    vec2 uv = uv0; // iteration uv
    float z = 0.0; // "height" of triangular-hexagonal cell pattern
    float edge = 1.0; // cell edge flag (reversed)
    float edgeW = 0.01; // edge width
    for(float i = 1.0; i <= n; i ++){
        uv = scale * (rotMtx(T * 0.0) * uv + vec2(0.0, 0.0)); // simple domain transformation
        edgeW *= scale; // correct edge width
        
        vec2 v1, v2, v3;
        vec3 c = triang(uv, v1, v2, v3); // get barycentric coordinates and vertex positions
        float n1 = rand(vec3(v1, i)); // get heights in triangle vertices
        float n2 = rand(vec3(v2, i));
        float n3 = rand(vec3(v3, i));
        z += dot(c, vec3(n1, n2, n3)); // interpolate within triangle
        
        edge *= step(edgeW, c.x) * step(edgeW, c.y) * step(edgeW, c.z); // update edge flag
    }
    
    z *= 0.3 / n; // scale height values
    z += sqrt(1.0 - dot(uv00, uv00)); // add "spherical" effect on heights
    
    vec2 grad = -vec2(dFdx(z), dFdy(z)) / EPS; // height gradient
    float l = length(grad); // height gradient length
    
    uv0 -= duv; // undo uv move for calculations based on screen position
    
    float uvDistort = sqrt(1.0 - dot(uv00, uv00)); // "spherical" effect for edges
    vec2 gradEdge = -vec2(dFdx(uvDistort), dFdy(uvDistort)) / EPS; // "spherical" gradient for edges
    
    vec3 norm = normalize(vec3(grad, 1.0)); // normals for transparent parts and edges
    vec3 normEdge = normalize(vec3(gradEdge, 1.0));
    
    float str = 0.03 * z; // strength of "refraction" effect
    
    vec3 lightPos = vec3(0.0, 0.0, 5.0); // vectors for 3D lighting calculations
    vec3 lightVec = lightPos - vec3(uv0, z);
    vec3 viewVec = vec3(0.0, 0.0, 2.0) - vec3(uv0, z);
    
    vec3 lightCol = vec3(0.3, 0.3, 1.0) * 40.0; // lighting color
    float lightScaling = 1.0 / dot(lightVec, lightVec);
    
    vec3 color = vec3(0.0);
    if (edge > 0.5){ // transparent / glassy part
        vec2 uv2 = uv00 + step(0.5, edge) * grad * str; // "refracted" uv to sample smooth noise
        color = getBaseColor(uv2); // get sun color
    } else { // metallic edge
        // keep color black
        norm = normEdge;
    }
    
    float diffLight = dot(norm, lightVec); // diffuse light intensity
    float reflLightBase = max(dot(norm, normalize(viewVec + lightVec)) * \
        smoothstep(-0.1, 0.0, diffLight), 0.0); // reflective light base value
    
    vec3 addCol = vec3(0.0);
    if (edge > 0.5){ // same condition as above, lighting calculation
        addCol = lightCol * (0.02 * max(diffLight, 0.0) + 1.0 * pow(reflLightBase, 50.0));
    } else {
        addCol = lightCol * (0.03 * max(diffLight, 0.0) + 1.0 * pow(reflLightBase, 20.0));
    }
    color += addCol * lightScaling;
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    float n = 1.0; // one-sides anti-aliasing step count
    float dCoord = 0.3; // AA step size
    vec3 col = vec3(0.0);
    for(float i = -n; i <= n; i += 1.0)
        for(float j = -n; j <= n; j += 1.0)
            col += getSceneCol(fragCoord + dCoord * vec2(i, j));
    col /= pow(2.0 * n + 1.0, 2.0);
    
    col = pow(col, vec3(1.0 / 2.2));
    fragColor = vec4(col, 1.0);
}
