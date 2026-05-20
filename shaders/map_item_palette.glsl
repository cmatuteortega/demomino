vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);

    // Skip fully transparent pixels
    if (pixel.a < 0.01) {
        return vec4(0.0);
    }

    // Find closest palette color via squared Euclidean distance in RGB space
    // Palette: #191e23 #1f2545 #412c35 #63374a #a43838 #e95050 #ff8d99 #ffd7d7
    vec3 rgb = pixel.rgb;
    vec3 closest = vec3(0.09804, 0.11765, 0.13725);
    float minDist = 1e10;
    float d;
    vec3 c;

    c = vec3(0.09804, 0.11765, 0.13725); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }
    c = vec3(0.12157, 0.14510, 0.27059); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }
    c = vec3(0.25490, 0.17255, 0.20784); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }
    c = vec3(0.38824, 0.21569, 0.29020); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }
    c = vec3(0.64314, 0.21961, 0.21961); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }
    c = vec3(0.91373, 0.31373, 0.31373); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }
    c = vec3(1.00000, 0.55294, 0.60000); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }
    c = vec3(1.00000, 0.84314, 0.84314); d = dot(rgb - c, rgb - c); if (d < minDist) { minDist = d; closest = c; }

    // Preserve original alpha; multiply by Love2D draw color for tinting
    return vec4(closest, pixel.a) * color;
}
