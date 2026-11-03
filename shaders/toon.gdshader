shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Shadow tone. It was a deep blue, which turned every side face away from the
// sun into a near-black band and made the course read as a stack of dark
// shelves. A pale sky blue keeps shaded faces inside the stage's own colour.
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.76, 0.98, 1.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.98, 0.93, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.15;
uniform float band_count : hint_range(2.0, 5.0) = 3.0;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.0;
uniform float flat_shade : hint_range(0.0, 1.0) = 1.0;
uniform float occlude_dither_scale : hint_range(0.25, 4.0) = 1.0;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float occlude_fade : hint_range(0.0, 1.0) = 1.0;
// Global cloud shadows (plan §8.3). Registered in project.godot under
// [shader_globals] and advanced by the dev scene each frame.
global uniform float cloud_time;
global uniform float cloud_coverage;
global uniform float cloud_strength;
uniform float cloud_scale : hint_range(0.01, 0.3) = 0.09;
// fragment() has no world-space position built-in (VERTEX there is view space),
// so carry one over from the vertex stage.
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
// Two drifting octaves over world XZ, thresholded by coverage. No texture
// binding: the pattern is entirely procedural.
float cloud_mask(vec3 wp) {
	vec2 p = wp.xz * cloud_scale + vec2(cloud_time * 0.010, cloud_time * 0.006);
	float n = value_noise(p) * 0.63 + value_noise(p * 2.35 + 17.0) * 0.37;
	float threshold = mix(0.80, 0.34, clamp(cloud_coverage, 0.0, 1.0));
	return smoothstep(threshold, threshold + 0.16, n);
}
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int index = x + y * 4;
	float m[16] = float[16](
		0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);
	return m[index] / 16.0;
}
void fragment() {
	if (occlude_fade < 0.999) {
		float d = bayer4(FRAGCOORD.xy * occlude_dither_scale);
		if (d > occlude_fade) {
			discard;
		}
	}
	if (flat_shade > 0.5) {
		vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(n, VIEW) < 0.0) {
			n = -n;
		}
		NORMAL = n;
	}
	// Fine world-space grain keeps big snow planes from reading as flat fills.
	float grain = hash21(floor(world_pos.xz * 9.0) + floor(world_pos.y * 9.0) * 0.73);
	ALBEDO = albedo.rgb * tint.rgb * COLOR.rgb * (0.975 + 0.05 * grain);
	ROUGHNESS = 0.94;
	SPECULAR = specular_strength;
	EMISSION = emission_color.rgb * emission_energy;
}
void light() {
	float ndl = clamp(-dot(NORMAL, LIGHT), 0.0, 1.0);
	// Three-stop cel ramp: cool shadow -> pale blue mid -> warm sunlit.
	vec3 lit_tone = light_tint.rgb;
	vec3 mid_tone = mix(shadow_tint.rgb, vec3(1.0), 0.62);
	vec3 shade_tone = shadow_tint.rgb * 0.88;
	float b1 = smoothstep(0.24, 0.285, ndl);
	float b2 = smoothstep(0.52, 0.565, ndl);
	vec3 tone = mix(shade_tone, mid_tone, b1);
	tone = mix(tone, lit_tone, b2);
	// Cloud shadows ride on the sun only; lantern light stays local and warm.
	float cloud = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		cloud = 1.0 - cloud_strength * cloud_mask(world_pos);
	}
	// LIGHT_COLOR is pre-scaled by PI in Godot 4; divide back out so cel
	// bands land where the ramp says they should.
	DIFFUSE_LIGHT += 0.80 * tone * ATTENUATION * LIGHT_COLOR * cloud;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += fres * rim_strength * lit_tone * ATTENUATION * LIGHT_COLOR * cloud;
	if (specular_strength > 0.0) {
		vec3 half_vec = normalize(LIGHT + VIEW);
		float spec = pow(max(dot(NORMAL, half_vec), 0.0), 36.0);
		spec = step(0.35, spec) * spec;
		SPECULAR_LIGHT += spec * specular_strength * ATTENUATION * LIGHT_COLOR * cloud;
	}
}
