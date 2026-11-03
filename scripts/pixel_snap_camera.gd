extends Camera3D
class_name PixelSnapCamera
@export var target_path: NodePath
@export var framing_offset := Vector3(0.0, 1.3, 0.0)
@export var back_distance := 40.0
@export var follow_speed := 5.0
@export var deadzone := 0.15
@export var reference_height := 360.0
@export var snap_enabled := true
@export var look_ahead := 0.0
const MAX_LOOK_AHEAD := 4.0
var shake := 0.0
var _focus := Vector3.ZERO
var _initialised := false
var _shake_time := 0.0
func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	_focus = _desired_focus()
	_initialised = true
	_apply()
func _desired_focus() -> Vector3:
	var n := get_node_or_null(target_path)
	if n is Node3D:
		var focus := (n as Node3D).global_position + framing_offset
		if look_ahead > 0.0:
			var v: Variant = n.get("velocity")
			if v is Vector3:
				var lead := (v as Vector3) * look_ahead
				lead.y = 0.0
				focus += lead.limit_length(MAX_LOOK_AHEAD)
		return focus
	return _focus
func _process(delta: float) -> void:
	shake = maxf(shake - delta * 1.9, 0.0)
	_shake_time += delta
	var goal := _desired_focus()
	var diff := goal - _focus
	if diff.length() > deadzone:
		var t := 1.0 - exp(-follow_speed * delta)
		_focus = _focus.lerp(goal, clampf(t, 0.0, 1.0))
	_apply()
func _apply() -> void:
	var b := global_transform.basis
	var right := b.x
	var up := b.y
	var fwd := b.z
	var focus := _focus
	if snap_enabled:
		var texel := size / reference_height
		var px := focus.dot(right)
		var py := focus.dot(up)
		var pz := focus.dot(fwd)
		px = roundf(px / texel) * texel
		py = roundf(py / texel) * texel
		focus = right * px + up * py + fwd * pz
	if shake > 0.0:
		focus += right * (cos(_shake_time * 57.0) * shake) + up * (sin(_shake_time * 43.0) * shake)
	global_position = focus + fwd * back_distance
func world_units_per_pixel() -> float:
	return size / reference_height
