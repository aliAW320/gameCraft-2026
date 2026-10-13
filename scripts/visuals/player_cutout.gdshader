shader_type canvas_item;

// Isolate the generated player atlas's white gutters without altering its source.
void fragment() {
    vec3 sampled = texture(TEXTURE, UV).rgb;
    float white = min(sampled.r, min(sampled.g, sampled.b));
    COLOR.a *= 1.0 - smoothstep(0.96, 0.995, white);
}
