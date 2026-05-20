uniform float time;

vec3 rgb2hsl(vec3 c) {
    float maxC = max(c.r, max(c.g, c.b));
    float minC = min(c.r, min(c.g, c.b));
    float l = (maxC + minC) * 0.5;
    if (maxC == minC) return vec3(0.0, 0.0, l);
    float d = maxC - minC;
    float s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC);
    float h;
    if (maxC == c.r)      h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
    else if (maxC == c.g) h = (c.b - c.r) / d + 2.0;
    else                  h = (c.r - c.g) / d + 4.0;
    return vec3(h / 6.0, s, l);
}

float hue2rgb(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 0.5)     return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}

vec3 hsl2rgb(vec3 c) {
    if (c.y == 0.0) return vec3(c.z);
    float q = c.z < 0.5 ? c.z * (1.0 + c.y) : c.z + c.y - c.z * c.y;
    float p = 2.0 * c.z - q;
    return vec3(hue2rgb(p, q, c.x + 1.0/3.0),
                hue2rgb(p, q, c.x),
                hue2rgb(p, q, c.x - 1.0/3.0));
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv  = texture_coords;

    // === Part 1: HSL inversion + teal-gray tint ===
    vec3 hsl = rgb2hsl(tex.rgb);
    hsl.z = 1.0 - hsl.z;
    hsl.x = fract(-hsl.x + 0.2);
    tex.rgb = hsl2rgb(hsl) + vec3(79.0/255.0, 99.0/255.0, 103.0/255.0);
    tex.rgb = clamp(tex.rgb, 0.0, 1.0);
    if (tex.a < 0.7) tex.a = tex.a / 3.0;

    // === Part 2: Iridescent shine ===
    tex.rgb = tex.rgb * 0.5 + vec3(0.4, 0.4, 0.8);

    float low   = min(tex.r, min(tex.g, tex.b));
    float high  = max(tex.r, max(tex.g, tex.b));
    float delta = high - low - 0.1;

    float fac  = sin(uv.x * 10.0 + time * 2.0)          * 0.5;
    float fac2 = cos(uv.y * 8.0  + time * 1.5)          * 0.5;
    float fac3 = sin((uv.x + uv.y) * 6.0 + time * 1.0) * 0.5;
    float fac4 = cos(uv.x * uv.y  * 20.0 + time * 0.8) * 0.5;
    float fac5 = sin(uv.y * 12.0  + time * 3.0)         * 0.5;
    float maxfac = 0.7 * max(max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.0);

    tex.r = tex.r - delta + delta * maxfac * (0.7 + fac5 * 0.27) - 0.1;
    tex.g = tex.g - delta + delta * maxfac * (0.7 - fac5 * 0.27) - 0.1;
    tex.b = tex.b - delta + delta * maxfac * 0.7                  - 0.1;
    // alpha left as-is — Part 1 already handles semi-transparent pixels

    return tex * color;
}
