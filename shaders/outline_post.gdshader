shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// 1px depth outlines + soft vignette.
// Drawn by a camera-aligned card placed just in front of the near plane, so the
// transparent pass composites it over the finished frame. It only writes alpha
// where an edge is detected, which keeps the untouched pixels bit-identical.
//
// Depth only, and deliberately so. The normal-roughness texture this used to
// sample is a Forward+ feature; on the Compatibility renderer — the only backend
// a web export has — the shader failed to compile and the whole pass vanished.
// Since its strength was 0, the normal term never drew anything anyway: every
// outline in the game is a depth edge.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.058, 0.078, 0.129, 1.0);
uniform float depth_threshold : hint_range(0.0, 0.05) = 0.0014;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.92;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.12;
float raw_depth(vec2 uv) {
	return texture(depth_tex, uv).r;
}
void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d = raw_depth(uv);
	float depth_edge = 0.0;
	vec2 offsets[4] = vec2[4](
		vec2(texel.x, 0.0),
		vec2(-texel.x, 0.0),
		vec2(0.0, texel.y),
		vec2(0.0, -texel.y)
	);
	for (int i = 0; i < 4; i++) {
		depth_edge = max(depth_edge, abs(raw_depth(uv + offsets[i]) - d));
	}
	float edge = step(depth_threshold, depth_edge) * outline_strength;
	vec2 v = uv - vec2(0.5);
	float vig = clamp(vignette_strength * clamp(dot(v, v) * 3.4, 0.0, 1.0), 0.0, 1.0);
	if (vig > edge) {
		ALBEDO = vec3(0.10, 0.10, 0.16);
		ALPHA = vig;
	} else {
		ALBEDO = outline_color.rgb;
		ALPHA = edge;
	}
}
