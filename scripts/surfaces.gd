class_name Surfaces
extends RefCounted
enum Surf { NEUTRAL, DEEP_SNOW, FIRE, WATER }
static func label(value: int) -> String:
	match value:
		Surf.DEEP_SNOW:
			return "snow patch"
		Surf.FIRE:
			return "campfire"
		Surf.WATER:
			return "meltwater"
	return "platform"
