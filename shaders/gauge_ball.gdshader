shader_type canvas_item;
// Circular badge for the size gauge. The replica renders in its own SubViewport
// with a transparent background; this composites it over a dark coin so the ball
// reads on bright snow and the square viewport edge never shows.
uniform vec4 backing : source_color = vec4(0.10, 0.15, 0.23, 0.82);
uniform vec4 rim_color : source_color = vec4(0.04, 0.06, 0.10, 1.0);
// Fraction of the half-viewport occupied by the coin. The SubViewport is
// BADGE + 2 * PAD square so the pulse has room; the ring lives in that padding.
uniform float coin_radius : hint_range(0.5, 1.0) = 0.8667;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > coin_radius) {
		discard;
	}
	vec4 tex = texture(TEXTURE, UV);
	float edge = smoothstep(coin_radius, coin_radius - 0.07, d);
	vec3 rgb = mix(backing.rgb, tex.rgb, tex.a);
	float a = mix(backing.a, 1.0, tex.a) * edge;
	// Dark rim so the badge has a readable edge over bright snow.
	rgb = mix(rgb, rim_color.rgb, smoothstep(coin_radius - 0.14, coin_radius, d) * 0.8);
	// Faint cool highlight just inside the rim, so the coin reads as a plate
	// sitting on the snow rather than a hole cut through it.
	float hl = smoothstep(coin_radius - 0.22, coin_radius - 0.10, d)
		* (1.0 - smoothstep(coin_radius - 0.10, coin_radius - 0.02, d));
	rgb += vec3(0.55, 0.72, 0.95) * hl * 0.16;
	COLOR = vec4(rgb, a);
}
