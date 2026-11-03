class_name PipController
extends CharacterBody3D


















const GRAVITY_FALLBACK := 22.0
const MAX_SLOPE_DEGREES := 45.0
const FLOOR_SNAP := 0.35
const AIR_CONTROL := 0.25


const SLOPE_ASSIST := 0.55
const DOWNHILL_SPEED_BOOST := 1.6
const MOVE_DEADZONE := 0.28
const MOVING_SPEED := 0.4
const LEAN := 0.16



const VOID_Y := -12.0

var size: SizeController
var sensor: SurfaceSensor
var checkpoint := Vector3.ZERO



var respawn_radius := SizeController.START_RADIUS


var _landing := 0.0
var _fall_speed := 0.0
var _was_on_floor := true

@onready var _visual: Node3D = $Visual
@onready var _art: Node3D = $Visual/Art
@onready var _shape: CollisionShape3D = $Collision
@onready var _shadow: MeshInstance3D = $BlobShadow


func _ready() -> void:
	up_direction = Vector3.UP
	floor_max_angle = deg_to_rad(MAX_SLOPE_DEGREES)
	floor_snap_length = FLOOR_SNAP

	size = SizeController.new()
	size.name = "Size"
	add_child(size)
	size.setup(_art, _shape.shape as SphereShape3D)

	sensor = SurfaceSensor.new()
	sensor.name = "Sensor"
	add_child(sensor)

	checkpoint = global_position
	_update_shadow()


func _physics_process(delta: float) -> void:
	var stats := size.stats()
	var top_speed := float(stats.speed)
	var accel := float(stats.accel)
	var grounded := is_on_floor()

	var horizontal := _horizontal_speed(delta, grounded, top_speed, accel, float(stats.friction))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if grounded:
		if velocity.y < 0.0:
			velocity.y = -1.0
	else:
		velocity.y -= _gravity() * delta

	move_and_slide()

	if not _was_on_floor and is_on_floor():
		_landing = clampf(absf(_fall_speed) / 8.0, 0.0, 0.7)
	_fall_speed = velocity.y if not is_on_floor() else 0.0
	_was_on_floor = is_on_floor()

	_update_surface(delta)
	_update_feedback(delta)
	_update_shadow()

	if Input.is_action_just_pressed("respawn"):
		respawn()
	elif global_position.y < VOID_Y:
		respawn()


func _horizontal_speed(delta: float, grounded: bool, top_speed: float, accel: float, friction: float) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var wish := _wish_direction()
	if wish != Vector3.ZERO:
		var control := accel if grounded else accel * AIR_CONTROL
		horizontal = horizontal.move_toward(Vector3(wish.x, 0.0, wish.z) * top_speed, control * delta)
	elif grounded:
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)

	if grounded:
		var normal := get_floor_normal()
		var gravity := Vector3.DOWN * _gravity()
		var downhill := gravity - normal * gravity.dot(normal)
		horizontal += downhill * delta * SLOPE_ASSIST
		horizontal = horizontal.limit_length(top_speed * DOWNHILL_SPEED_BOOST)
	return horizontal






func _wish_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var strength := input.length()
	if strength < MOVE_DEADZONE:
		return Vector3.ZERO
	var wish := CourseKit.ACROSS * input.x - CourseKit.ALONG * input.y
	if wish.length_squared() < 0.0001:
		return Vector3.ZERO
	return wish.normalized() * minf(strength, 1.0)


func _update_surface(delta: float) -> void:
	if sensor == null:
		return
	# The sensor casts through Pip's radius from the centre, so it reports the
	# deck, the snow patch or the campfire directly under the contact point.
	sensor.probe(size.radius)
	if not is_on_floor():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var rate := sensor.rate(speed > MOVING_SPEED)
	if is_zero_approx(rate):
		return
	size.add_radius(rate * delta)


func _update_feedback(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var speed_factor := clampf(speed / maxf(float(size.stats().speed), 0.01), 0.0, 1.0)
	var cam := get_viewport().get_camera_3d()
	var lean := Vector3.ZERO
	if cam != null and speed > 0.15:
		var local := cam.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
		lean = Vector3(local.z, 0.0, -local.x) * (LEAN * speed_factor / speed)
	_visual.rotation.x = lerpf(_visual.rotation.x, lean.x, 1.0 - exp(-delta / 0.12))
	_visual.rotation.z = lerpf(_visual.rotation.z, lean.z, 1.0 - exp(-delta / 0.12))

	_landing = maxf(_landing - delta * 4.0, 0.0)
	var squash := 1.0 - 0.12 * _landing
	_visual.scale = Vector3(2.0 - squash, squash, 2.0 - squash)


func _update_shadow() -> void:
	if _shadow == null or size == null:
		return
	# No ground under Pip means no shadow: over a gap the blob has to vanish
	# rather than hang on an invisible floor.
	_shadow.visible = sensor != null and sensor.has_ground
	if not _shadow.visible:
		return
	_shadow.global_position = Vector3(global_position.x, sensor.ground_y + 0.03, global_position.z)
	var s := size.radius / SizeController.START_RADIUS
	_shadow.scale = Vector3(s, s, s)


func set_checkpoint(point: Vector3, radius := -1.0) -> void:
	checkpoint = point
	respawn_radius = size.radius if radius < 0.0 and size != null else radius
	if respawn_radius < SizeController.MIN_RADIUS:
		respawn_radius = SizeController.START_RADIUS


func respawn() -> void:
	velocity = Vector3.ZERO
	# `checkpoint` is a ground point on a deck, so the ball is placed a radius
	# above it, at the size it held when the checkpoint was set.
	global_position = checkpoint + Vector3(0.0, respawn_radius + 0.15, 0.0)
	size.reset(respawn_radius)
	_landing = 0.0
	_was_on_floor = false


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", GRAVITY_FALLBACK))


func surface_label() -> String:
	return SurfaceSensor.label(sensor.surface) if sensor != null else "-"
