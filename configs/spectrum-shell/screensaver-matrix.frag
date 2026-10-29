#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 fieldSize;
    float elapsed;
    float glyphCell;
    vec4 accentColor;
    vec4 secondaryColor;
    vec4 headColor;
};
layout(binding = 1) uniform sampler2D atlas;
float hash(vec2 value) {
    vec3 p = fract(vec3(value.xyx) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
vec4 rain(vec2 position, float cell, float layer) {
    vec2 grid = position / cell;
    float column = floor(grid.x);
    float seed = hash(vec2(column, layer));
    float speed = mix(5.0, 15.0, hash(vec2(column + 43.0, layer)));
    float length = mix(12.0, 35.0, hash(vec2(column + 17.0, layer)));
    float gap = mix(8.0, 24.0, hash(vec2(column + 71.0, layer)));
    float span = fieldSize.y / cell + length + gap;
    float clock = elapsed * speed / span + seed;
    float organic = clock + 0.045 * sin(clock * 1.41421356 + seed * 13.0)
        + 0.025 * sin(clock * 2.23606798 + seed * 29.0);
    float travel = organic * span;
    float cycle = floor(travel / span);
    float head = mod(travel, span) - gap * 0.5;
    float row = floor(grid.y);
    float distance = head - row;
    if (distance < 0.0 || distance > length) return vec4(0.0);
    float rate = mix(0.8, 4.5, hash(vec2(column * 17.0 + row, layer)));
    float tick = floor(elapsed * rate + seed * 13.0);
    float glyph = floor(hash(vec2(column * 139.0 + row * 37.0, tick + cycle * 19.0 + layer)) * 57.0);
    float leading = 1.0 - smoothstep(0.2, 1.4, distance);
    vec2 local = fract(grid);
    vec2 tile = vec2(mod(glyph, 8.0), 7.0 - floor(glyph / 8.0));
    vec2 uv = (tile + local) / 8.0;
    vec3 sampleValue = texture(atlas, uv).rgb;
    float signedDistance = max(min(sampleValue.r, sampleValue.g), min(max(sampleValue.r, sampleValue.g), sampleValue.b));
    vec2 unitRange = vec2(4.0 / 512.0);
    vec2 screenTextureSize = vec2(1.0) / max(fwidth(uv), vec2(0.00001));
    float pixelRange = max(0.5 * dot(unitRange, screenTextureSize), 1.0);
    float edge = pixelRange * (signedDistance - 0.5);
    float ink = clamp(edge + 0.5, 0.0, 1.0);
    float halo = exp(-max(0.0, -edge) * 1.6) * 0.13 * smoothstep(0.15, 0.48, signedDistance);
    float pulse = elapsed * 3.0 + seed * 17.0 + row * 0.8;
    float flicker = 0.88 + 0.12 * sin(pulse) * sin(pulse * 0.73);
    float tail = pow(max(0.0, 1.0 - distance / length), 1.65);
    float brightness = mix(tail * flicker, 1.35, leading);
    float reveal = smoothstep(-0.1, 0.6, distance);
    vec3 tint = mix(accentColor.rgb, secondaryColor.rgb, seed > 0.8 ? 0.7 : 0.0);
    tint = mix(tint, mix(headColor.rgb, vec3(1.0), 0.25), leading * 0.85);
    float coverage = clamp(ink + halo * (0.35 + leading), 0.0, 1.0);
    float alpha = clamp(coverage * brightness * reveal, 0.0, 1.0);
    return vec4(tint * alpha, alpha);
}
void main() {
    vec2 position = qt_TexCoord0 * fieldSize;
    vec4 back = rain(position + vec2(glyphCell * 0.45, 0.0), glyphCell * 0.72, 8.0) * 0.2;
    vec4 front = rain(position, glyphCell, 1.0);
    fragColor = (front + back * (1.0 - front.a)) * qt_Opacity;
}
