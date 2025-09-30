// Background CRT Shader for Tile Game
// Creates retro CRT effects with colors from the game palette

uniform float time;
uniform vec2 resolution;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    
    // ====== DISTORTION (horizontal wave) ======
    float wave = sin((uv.y + time * 1.0) * 20.0) * 0.00035;
    uv.x += wave;

    // Sample the original texture
    vec4 baseColor = Texel(texture, uv);
    
    // ====== CHROMATIC ABERRATION (RGB shift) ======
    float caOffset = 0.001;
    vec4 colR = Texel(texture, uv + vec2(caOffset, 0.0));
    vec4 colG = Texel(texture, uv);
    vec4 colB = Texel(texture, uv - vec2(caOffset, 0.0));
    vec4 colorCA = vec4(colR.r, colG.g, colB.b, baseColor.a);

    // ====== SCANLINES ======
    float scanline = sin(uv.y * resolution.y * 1.2) * 0.03;
    float brightness = 1.0 - scanline;

    // ====== FLICKER ======
    float flicker = 0.98 + 0.02 * sin(time * 100.0);

    // ====== VIGNETTE ======
    vec2 vPos = (uv - 0.5) * 0.8;
    float vignette = 1.0 - dot(vPos, vPos);
    vignette = clamp(vignette, 0.0, 1.0);
    vignette = pow(vignette, 2.0);

    // ====== NOISE ======
    float noise = rand(uv * resolution + time * 50.0) * 0.02 - 0.01;

    // ====== COLOR TINTING (match game palette) ======
    // Add subtle warm tint to match the game's color scheme
    vec3 tint = vec3(1.05, 1.0, 0.95); // Slight warm tint
    
    // ====== FINAL COLOR ======
    colorCA.rgb *= tint;
    colorCA.rgb *= brightness * flicker * vignette;
    colorCA.rgb += noise;

    return colorCA * color;
}