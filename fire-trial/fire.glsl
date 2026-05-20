// Heat shimmer distortion shader.
// Applied to the tile canvas while drawing it.
// Samples fireMap (the live fire image) to distort tile UVs,
// creating a heat-shimmer effect proportional to local fire intensity.

uniform float time;
uniform Image fireMap;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;

    // Sample fire heat at this tile position (r channel = heat 0..1)
    float heat = Texel(fireMap, uv).r;

    // Below shimmer threshold: draw tile pixel as-is
    if (heat < 0.05) {
        return Texel(texture, uv) * color;
    }

    // Shimmer strength scales with heat
    float s = heat * 0.02;

    // Two sine waves at different frequencies for organic look
    float xOff = sin(uv.y * 30.0 + time * 4.0) * s
               + sin(uv.y * 17.0 - time * 6.5 + rand(vec2(uv.y, time)) * 0.5) * s * 0.5;
    float yOff = sin(uv.x * 20.0 + time * 3.0) * s * 0.3;

    vec2 distUV = clamp(uv + vec2(xOff, yOff), 0.0, 1.0);
    vec4 col = Texel(texture, distUV);

    // Warm tint on the tile surface proportional to heat
    col.rgb = clamp(col.rgb + vec3(heat * 0.25, heat * 0.06, 0.0), 0.0, 1.0);

    return col * color;
}
