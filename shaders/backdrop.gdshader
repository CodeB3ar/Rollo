shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// Screen-locked sky backdrop.
// A full-frustum quad parented to the orthographic camera. UV.y == 0 is the top
// of the screen, so the vertical mapping is unambiguous (QuadMesh packs its UVs
// top-left origin).
//
// Deliberately just the colour ramp: five vertical stops and nothing drawn on
// top of them. Clouds, the sun disc and the atmospheric bloom all read as
// clutter behind a platformer's play space, and they fight the flat silhouettes
// the art direction is built on. If a level wants weather, it belongs in the
// scene, not baked into the sky card.
uniform vec4 top_col : source_color = vec4(0.13, 0.25, 0.42, 1.0);
uniform vec4 upper_col : source_color = vec4(0.31, 0.49, 0.70, 1.0);
uniform vec4 mid_col : source_color = vec4(0.62, 0.75, 0.87, 1.0);
uniform vec4 horizon_col : source_color = vec4(1.0, 0.83, 0.62, 1.0);
uniform vec4 haze_col : source_color = vec4(0.96, 0.80, 0.66, 1.0);
void fragment() {
	float y = UV.y;
	vec3 col = mix(top_col.rgb, upper_col.rgb, smoothstep(0.0, 0.24, y));
	col = mix(col, mid_col.rgb, smoothstep(0.16, 0.50, y));
	col = mix(col, horizon_col.rgb, smoothstep(0.42, 0.74, y));
	col = mix(col, haze_col.rgb, smoothstep(0.70, 1.0, y));
	ALBEDO = col;
}
