class_name SizeController
extends Node
signal tier_changed(tier: int, tier_name: String)
const TIERS := [
	{"name": "Bit", "radius": 0.35, "accel": 24.0, "speed": 6.0, "friction": 20.0},
	{"name": "Roll", "radius": 0.55, "accel": 20.0, "speed": 6.5, "friction": 16.0},
	{"name": "Boulder", "radius": 0.80, "accel": 16.0, "speed": 7.0, "friction": 12.0},
	{"name": "Drift", "radius": 1.10, "accel": 12.0, "speed": 7.5, "friction": 8.0},
]
const MIN_RADIUS := 0.25
const MAX_RADIUS := 1.70
var max_radius := MAX_RADIUS
const HYSTERESIS := 0.03
const START_RADIUS := 0.55
const VISUAL_BASE_RADIUS := 0.68
const VISUAL_LAG := 0.08
const COLLISION_STEP := 0.10
const COLLISION_SCALE := 0.96
var radius := START_RADIUS
var tier := 1
var collision_radius := START_RADIUS * COLLISION_SCALE
var _art: Node3D
var _shape: SphereShape3D
var _applied_visual := START_RADIUS
func setup(art: Node3D, shape: SphereShape3D) -> void:
	_art = art
	_shape = shape
	_applied_visual = radius
	_update_collision()
	_apply_visual()
func stats() -> Dictionary:
	return TIERS[tier]
func tier_name() -> String:
	return str(TIERS[tier].name)
func set_radius(value: float) -> void:
	radius = clampf(value, MIN_RADIUS, max_radius)
	_update_tier()
	_update_collision()
func add_radius(delta: float) -> void:
	set_radius(radius + delta)
func reset(value := START_RADIUS) -> void:
	radius = clampf(value, MIN_RADIUS, max_radius)
	var previous := tier
	tier = _tier_for(radius)
	_update_collision()
	_applied_visual = radius
	_apply_visual()
	if tier != previous:
		tier_changed.emit(tier, tier_name())
func _process(delta: float) -> void:
	if _art == null:
		return
	_applied_visual = lerpf(_applied_visual, radius, 1.0 - exp(-delta / VISUAL_LAG))
	_apply_visual()
func _apply_visual() -> void:
	if _art != null:
		_art.scale = Vector3.ONE * (_applied_visual / VISUAL_BASE_RADIUS)
func _tier_for(value: float) -> int:
	var found := 0
	for i in range(1, TIERS.size()):
		if value >= float(TIERS[i].radius):
			found = i
	return found
func _update_tier() -> void:
	var previous := tier
	while tier < TIERS.size() - 1 and radius > float(TIERS[tier + 1].radius) + HYSTERESIS:
		tier += 1
	while tier > 0 and radius < float(TIERS[tier].radius) - HYSTERESIS:
		tier -= 1
	if tier != previous:
		tier_changed.emit(tier, tier_name())
func _update_collision() -> void:
	if _shape == null:
		return
	var target := roundf(radius * COLLISION_SCALE / COLLISION_STEP) * COLLISION_STEP
	if absf(target - _shape.radius) < COLLISION_STEP * 0.5:
		return
	_shape.radius = maxf(target, COLLISION_STEP)
	collision_radius = _shape.radius
