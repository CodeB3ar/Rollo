class_name SurfaceSensor
extends Node3D













const PROBE_PAD := 0.9





const RATES := {
	Surfaces.Surf.NEUTRAL: 0.0,
	Surfaces.Surf.DEEP_SNOW: 0.90,
	Surfaces.Surf.FIRE: -1.00,
	Surfaces.Surf.WATER: -0.90,
}




const IDLE_GROW := 0.30

var surface: int = Surfaces.Surf.NEUTRAL

var ground_y := 0.0
var has_ground := false

var _exclude: Array[RID] = []
var _snow: Array = []
var _fire: Array = []
var _zones_ready := false


func _ready() -> void:
	var body := get_parent() as CollisionObject3D
	if body != null:
		_exclude = [body.get_rid()]




func refresh_zones() -> void:
	_snow = get_tree().get_nodes_in_group("snow_patch")
	_fire = get_tree().get_nodes_in_group("campfire")
	_zones_ready = true




func probe(radius: float) -> int:
	if not _zones_ready:
		refresh_zones()
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * (radius + PROBE_PAD),
		1,
		_exclude
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	has_ground = not hit.is_empty()
	if has_ground:
		ground_y = (hit["position"] as Vector3).y
		var collider: Object = hit["collider"]
		surface = int(collider.get_meta("surface", Surfaces.Surf.NEUTRAL)) if collider != null else Surfaces.Surf.NEUTRAL
	else:
		surface = Surfaces.Surf.NEUTRAL

	# Zones win over the collider: they are the only things that grow or melt,
	# and fire wins over snow where the two overlap.
	if _inside(_snow):
		surface = Surfaces.Surf.DEEP_SNOW
	if _inside(_fire):
		surface = Surfaces.Surf.FIRE
	return surface






func _inside(zones: Array) -> bool:
	for node in zones:
		var zone := node as Node3D
		if zone == null:
			continue
		var offset := global_position - zone.global_position
		var along := offset.x * CourseKit.ALONG.x + offset.z * CourseKit.ALONG.z
		var across := offset.x * CourseKit.ACROSS.x + offset.z * CourseKit.ACROSS.z
		if zone.has_meta("rect"):
			var rect: Vector2 = zone.get_meta("rect")
			if absf(along) < rect.x and absf(across) < rect.y:
				return true
			continue
		var radius := float(zone.get_meta("radius", 1.0))
		if along * along + across * across < radius * radius:
			return true
	return false



func rate(moving: bool) -> float:
	var value := float(RATES.get(surface, 0.0))
	if value > 0.0 and not moving:
		return IDLE_GROW
	return value


static func label(value: int) -> String:
	return Surfaces.label(value)
