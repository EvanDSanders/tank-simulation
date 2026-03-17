float inv_lerp(float a, float b, float v) {
    return (v - a) / (b - a);
}

float remap(float i_min, float i_max, float o_min, float o_max, float v) {
    return mix(o_min, o_max, inv_lerp(i_min, i_max, v));
}