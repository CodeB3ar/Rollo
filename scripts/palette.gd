class_name Palette
extends RefCounted
















static var COL := {
	# Interactive white. The brightest value in the palette, by design: if it is
	# white and it is chunky, it is snow and it will grow the ball.
	"deep_snow": Color("#FFFFFF"),
	"snow": Color("#F2FAFF"),
	"snow_shade": Color("#BFDDF5"),
	"crystal": Color("#E4F5FF"),
	"water": Color("#63CBE8"),
	# Fire.
	"flame": Color("#FF7A2F"),
	"flame_core": Color("#FFE066"),
	"ember": Color("#FF5C2E"),
	"ash": Color("#4A4257"),
	# Stage tints: (top, dark side). One row per area, in run order. Tops sit in
	# the middle of the range on purpose: under a bright key plus ambient, a pale
	# top clamps to white and the whole course turns into one washed slab, which
	# is also what killed the contrast between snow and deck.
	"frost": Color("#4CB2D2"),
	"frost_dark": Color("#216C8C"),
	"mint": Color("#43BF8A"),
	"mint_dark": Color("#1B7A58"),
	"lilac": Color("#8B70D6"),
	"lilac_dark": Color("#513597"),
	"peach": Color("#F08E4C"),
	"peach_dark": Color("#B4561F"),
	# Banner and arch accent. The one place a colour is allowed to shout.
	"lemon": Color("#FFD84D"),
	# Trim and text. Cream is the rim on every platform and the only highlight
	# the outline pass gets to work with.
	"cream": Color("#FFF7EC"),
	"ink": Color("#241F3A"),
	"sky_floor": Color("#E9F6FF"),
	# Prop wood and stone.
	"wood": Color("#B4794E"),
	"wood_dark": Color("#6B4A34"),
	"stone": Color("#9AA6C9"),
	# Character.
	"eye": Color("#1B2234"),
}
