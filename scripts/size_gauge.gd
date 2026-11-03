class_name SizeGauge
extends CanvasLayer














const MIN_RADIUS := SizeController.MIN_RADIUS
const MAX_RADIUS := SizeController.MAX_RADIUS
const BASE_RADIUS := SizeController.VISUAL_BASE_RADIUS

const COIN_SHADER := "res://shaders/gauge_ball.gdshader"

const RING_SHADOW := Color(0.05, 0.07, 0.12, 0.80)




const BADGE := 70.0

const PAD := 6.0


const APPARENT_MIN := 0.40
const APPARENT_MAX := 0.72

const PULSE_ZOOM := 0.10


const EYE := Vector3(0.6124, 0.5, 0.6124)

var pip: PipController

var _halo: Control
var _ring: Control

var _ball: Node3D
var _camera: Camera3D
var _ball_rect: TextureRect
var _viewport: SubViewport

var _time := 0.0
var _pulse := 0.0
var _last_radius := -1.0

var _center: Vector2
var _ring_radius: float


func _ready() -> void:
	layer = 4

	var diameter := BADGE + PAD * 2.0
	_center = Vector2(PAD + BADGE * 0.5, PAD + BADGE * 0.5)
	# Keep the arc inside the coin. At `+3` the ring and its ticks sat outside
	# the coin radius and read as a floating hoop instead of part of the badge.
	_ring_radius = BADGE * 0.5 - 4.0

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(diameter), int(diameter))
	_viewport.transparent_bg = true
	# Own world: sharing the game World3D made the environment's opaque sky
	# background fill the gauge's square. The replica gets its own light rig so
	# the snowball still matches Pip's warm key / cool ambient exactly.
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C4D9E8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.basis = Basis.looking_at(Vector3(0.60, -0.56, -0.34).normalized(), Vector3.UP)
	key.light_color = Color("#FFF1D6")
	key.light_energy = 1.05
	_viewport.add_child(key)

	_ball = Node3D.new()
	_viewport.add_child(_ball)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 2.0
	_camera.position = EYE * 6.0
	_camera.near = 0.1
	_camera.far = 20.0
	# Add first: look_at() requires the node to be inside the tree.
	_viewport.add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	var view_size := get_viewport().get_visible_rect().size
	var x := PAD
	var y := view_size.y - diameter - PAD

	# Soft cool halo behind the coin: the dark badge needs a transition to snow
	# or it reads as a hole punched in the diorama.
	_halo = Control.new()
	_halo.custom_minimum_size = Vector2(diameter, diameter)
	_halo.size = Vector2(diameter, diameter)
	_halo.position = Vector2(x, y)
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.draw.connect(_draw_halo)
	add_child(_halo)

	_ball_rect = TextureRect.new()
	_ball_rect.texture = _viewport.get_texture()
	_ball_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_rect.custom_minimum_size = Vector2(diameter, diameter)
	_ball_rect.size = Vector2(diameter, diameter)
	_ball_rect.material = _coin_material(diameter)
	_ball_rect.position = Vector2(x, y)
	_ball_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ball_rect)

	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(diameter, diameter)
	_ring.size = Vector2(diameter, diameter)
	_ring.position = Vector2(x, y)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)




func _coin_material(diameter: float) -> ShaderMaterial:
	var coin := ShaderMaterial.new()
	var shader := load(COIN_SHADER) as Shader
	if shader != null:
		coin.shader = shader
		coin.set_shader_parameter("coin_radius", BADGE / diameter)
	return coin



func bind(player: PipController) -> void:
	pip = player
	if _ball == null:
		return
	for child in _ball.get_children():
		_ball.remove_child(child)
		child.queue_free()
	if pip == null:
		return
	var art := pip.get_node_or_null("Visual/Art")
	if art == null:
		return
	var replica := art.duplicate() as Node3D
	replica.name = "Replica"
	replica.rotation = Vector3.ZERO
	_ball.add_child(replica)
	_last_radius = -1.0




func _fitted_size(radius: float) -> float:
	var progress := clampf((radius - MIN_RADIUS) / (MAX_RADIUS - MIN_RADIUS), 0.0, 1.0)
	var apparent := lerpf(APPARENT_MIN, APPARENT_MAX, progress)
	var zoom := 1.0 + _pulse * PULSE_ZOOM / 0.22
	return 2.0 * radius / (apparent * zoom)


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(pip) or pip.size == null:
		return

	var radius := pip.size.radius
	if _last_radius >= 0.0:
		# A size change kicks a spring; growth and melt feel different.
		var change := radius - _last_radius
		if absf(change) > 0.0004:
			_pulse = clampf(_pulse + change * 2.2, -0.22, 0.22)
	_last_radius = radius
	_pulse = lerpf(_pulse, 0.0, 1.0 - exp(-delta / 0.11))

	if _ball != null and _ball.get_child_count() > 0:
		var replica := _ball.get_child(0) as Node3D
		replica.scale = Vector3.ONE * (radius / BASE_RADIUS)
		replica.rotation.y = sin(_time * 0.35) * 0.35
	if _camera != null:
		_camera.size = _fitted_size(radius)

	if _ring != null:
		_ring.queue_redraw()


func _draw_halo() -> void:
	var coin := BADGE * 0.5
	for i in range(16):
		var t := float(i) / 15.0
		var radius := lerpf(coin, coin + 17.0, t)
		_halo.draw_circle(_center, radius, Color(0.76, 0.88, 1.0, 0.055 * (1.0 - t)))


func _draw_ring() -> void:
	var tier_index := pip.size.tier if is_instance_valid(pip) and pip.size != null else 0
	var progress := 0.0
	var rate := 0.0
	if is_instance_valid(pip) and pip.size != null:
		progress = clampf((pip.size.radius - MIN_RADIUS) / (MAX_RADIUS - MIN_RADIUS), 0.0, 1.0)
		# Match the sensor's real state: a ball standing still should not show the
		# rolling-growth sparkle, and shade affects the rate the player feels.
		var moving := pip.is_on_floor() and Vector2(pip.velocity.x, pip.velocity.z).length() > 0.4
		rate = pip.sensor.rate(moving) if pip.sensor != null else 0.0

	var start := -PI * 0.5
	var end := start + TAU * progress

	# Empty track: with only the filled arc drawn, a Bit ball looked like a
	# partial ring rather than a gauge.
	_ring.draw_arc(_center, _ring_radius, 0.0, TAU, 64, Color(0.78, 0.87, 1.0, 0.32), 2.0, true)

	# Filled arc: how far through the full size range Pip is. A dark under-stroke
	# keeps it readable over both snow and the coin's backing.
	var tier_color := Color("#9FE3FF").lerp(Color("#FFCB7A"), progress)
	_ring.draw_arc(_center, _ring_radius, start, end, 48, RING_SHADOW, 4.0, true)
	_ring.draw_arc(_center, _ring_radius, start, end, 48, tier_color, 2.0, true)

	# Tier ticks: four notches at the ring's quarters — top, right, bottom,
	# left, i.e. 0 / 90 / 180 / 270 degrees clockwise from the top. Spacing
	# them by tier radius bunched them into the upper arc (the radii are 0.35,
	# 0.55, 0.80, 1.10 over a 1.13 m range) and the gauge read lopsided.
	for i in range(SizeController.TIERS.size()):
		var angle := start + TAU * float(i) / float(SizeController.TIERS.size())
		var lit := i <= tier_index
		var inner := _center + Vector2(cos(angle), sin(angle)) * (_ring_radius - 4.0)
		var outer := _center + Vector2(cos(angle), sin(angle)) * (_ring_radius + 3.0)
		_ring.draw_line(inner, outer, RING_SHADOW, 3.0, true)
		_ring.draw_line(inner, outer, Color("#FFD98C") if lit else Color(0.85, 0.92, 1.0, 0.55), 1.5, true)

	if rate < 0.0:
		# Heat: pulsing ember rim plus flecks rising off the ball.
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		_ring.draw_arc(_center, _ring_radius + 2.0, PI * 0.15, PI * 0.85, 24, Color(1.0, 0.55, 0.25, 0.25 + 0.35 * pulse), 3.0, true)
		for i in range(4):
			var phase := fmod(_time * 0.8 + float(i) * 0.25, 1.0)
			var x := _center.x + sin(float(i) * 2.3 + _time) * 16.0
			var y := _center.y - 30.0 - phase * 36.0
			_ring.draw_circle(Vector2(x, y), 1.6 * (1.0 - phase) + 0.6, Color(1.0, 0.6, 0.3, 0.55 * (1.0 - phase)))
	elif rate > 0.0:
		# Growth: small snow specks settling onto the ball.
		for i in range(5):
			var phase := fmod(_time * 0.6 + float(i) * 0.2, 1.0)
			var x := _center.x + sin(float(i) * 1.7) * 24.0
			var y := _center.y - 28.0 + phase * 42.0
			_ring.draw_circle(Vector2(x, y), 1.4, Color(0.95, 0.98, 1.0, 0.65 * (1.0 - absf(phase * 2.0 - 1.0))))
