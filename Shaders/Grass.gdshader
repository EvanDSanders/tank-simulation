shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 grass_dark : source_color = vec3(0.12, 0.32, 0.1);
uniform vec3 grass_mid : source_color = vec3(0.22, 0.48, 0.16);
uniform vec3 grass_light : source_color = vec3(0.35, 0.58, 0.22);
uniform vec3 grass_tip : source_color = vec3(0.5, 0.62, 0.28);
uniform vec3 patch_dry : source_color = vec3(0.28, 0.24, 0.14);

uniform float patch_scale : hint_range(0.0001, 0.02, 0.0001) = 0.0018;
uniform float detail_scale : hint_range(0.001, 0.2, 0.0001) = 0.045;
uniform float dry_amount : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float roughness_base : hint_range(0.0, 1.0, 0.01) = 0.88;
uniform float roughness_var : hint_range(0.0, 0.3, 0.01) = 0.08;
uniform float wind_strength : hint_range(0.0, 1.5, 0.01) = 0.1;
uniform float wind_speed : hint_range(0.0, 5.0, 0.01) = 0.65;
uniform float rim_power : hint_range(0.5, 8.0, 0.1) = 3.2;
uniform float rim_strength : hint_range(0.0, 0.5, 0.01) = 0.07;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.02 + shift;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	if (wind_strength > 0.0001) {
		vec2 w = wp.xz;
		float t = TIME * wind_speed;
		float n1 = sin(w.x * 0.08 + w.y * 0.05 + t * 1.7);
		float n2 = sin(w.x * 0.05 - w.y * 0.09 + t * 1.1);
		vec3 wdelta = vec3((n1 * 0.55 + n2 * 0.45) * wind_strength, 0.0, (n2 * 0.5 - n1 * 0.35) * wind_strength);
		VERTEX += (inverse(MODEL_MATRIX) * vec4(wdelta, 0.0)).xyz;
	}

	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * patch_scale;
	vec2 d = world_pos.xz * detail_scale + vec2(TIME * 0.003, TIME * 0.0021);

	float large = fbm(p);
	float medium = fbm(p * 2.3 + vec2(17.3, 9.1));
	float fine = fbm(d) * 0.35 + vnoise(d * 3.7) * 0.25;

	float dry_mask = smoothstep(0.62, 0.92, large * 0.7 + medium * 0.3);
	float dry = dry_mask * dry_amount;

	vec3 base = mix(grass_dark, grass_mid, large);
	base = mix(base, grass_light, medium * 0.55 + fine * 0.45);
	base = mix(base, grass_tip, fine * fine * 0.35);
	base = mix(base, patch_dry, dry);

	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = clamp(roughness_base + (vnoise(d * 1.8) - 0.5) * 2.0 * roughness_var, 0.04, 1.0);

	vec3 n_vs = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	float ndv = clamp(abs(dot(n_vs, normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - ndv, rim_power) * rim_strength;
	ALBEDO += rim * grass_tip;

	AO = mix(1.0, 0.92, large * 0.25);
}
