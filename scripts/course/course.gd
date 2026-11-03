extends CourseKit
const OUTLINE_SHADER := "res://shaders/outline_post.gdshader"
const BACKDROP_SHADER := "res://shaders/backdrop.gdshader"
const DECK := 4.0
const HIGH := 6.4
const LANE := 6.0
const ISO_PITCH := deg_to_rad(30.0)
const ISO_SWING := deg_to_rad(20.0)
const FINISH_ALONG := 91.0
const AREAS := [
	{"name": "POWDER BOWL", "along": 0.0},
	{"name": "THE LEDGES", "along": 26.4},
	{"name": "THE CHIMNEY", "along": 56.4},
	{"name": "THE THAW", "along": 72.0},
]
var COL := Palette.COL
var finished := false
var area := 0
var pip: PipController
var _camera: PixelSnapCamera
var _env: Environment
var _sun: DirectionalLight3D
var _outline: ShaderMaterial
var _hud: DevHud
var _gauge: SizeGauge
var _fires: Array = []
var _checkpoints: Array[Vector3] = []
var _checkpoint_along: Array[float] = []
var _next_checkpoint := 1
var _time := 0.0
func _ready() -> void:
	_build_environment()
	_build_sun()
	_build_cloud_sea()
	_build_course()
	_build_player()
	_build_camera()
	_build_hud()
	_checkpoints = [
		at(1.0, 0.0, DECK),
		at(3.0, 0.0, DECK),
		at(5.0, 0.0, DECK),
		at(9.2, 0.0, DECK),
		at(13.0, 0.0, DECK),
		at(17.0, 0.0, DECK),
		at(21.0, 0.0, DECK),
		at(27.0, 0.0, DECK),
		at(32.0, 0.0, DECK),
		at(35.2, 0.0, DECK),
		at(40.4, 0.0, DECK),
		at(45.2, 0.0, DECK),
		at(52.0, 0.0, HIGH),
		at(58.6, 0.0, DECK),
		at(69.0, 0.0, DECK),
	]
	_checkpoint_along = []
	for point in _checkpoints:
		_checkpoint_along.append(along_of(point))
	pip.set_checkpoint(_checkpoints[0])
	_fires = get_tree().get_nodes_in_group(FIRE_GROUP)
	print("[Course] %d areas, %.0f m, %d gaps, %d doors, Pip at %.2f m" % [
		AREAS.size(), FINISH_ALONG, gaps.size(),
		get_tree().get_nodes_in_group(TUNNEL_GROUP).size(), SizeController.START_RADIUS,
	])
func area_count() -> int:
	return AREAS.size()
func area_names() -> Array:
	var names: Array = []
	for entry in AREAS:
		names.append(str(entry.name))
	return names
func section_shots() -> Array:
	return [
		Vector3(2.6, 0.0, DECK), Vector3(7.6, 1.6, DECK), Vector3(15.0, 0.0, DECK),
		Vector3(19.6, 0.0, DECK), Vector3(29.4, 0.0, DECK), Vector3(38.0, 0.0, DECK),
		Vector3(48.0, 0.0, 4.6), Vector3(54.0, 0.0, HIGH), Vector3(63.0, 0.0, DECK),
		Vector3(70.0, 0.0, DECK), Vector3(78.0, 0.0, DECK),
	]
func tuning() -> Dictionary:
	return {
		"camera": _camera,
		"environment": _env,
		"sun": _sun,
		"outline": _outline,
		"pip": pip,
	}
func _process(delta: float) -> void:
	_time += delta
	RenderingServer.global_shader_parameter_set("cloud_time", _time)
	_flicker_fires()
	_track_area()
	_track_checkpoint()
	_track_finish()
	_catch_falls()
func _flicker_fires() -> void:
	for node in _fires:
		var fire := node as Node3D
		if fire == null:
			continue
		var phase := fire.global_position.x * 1.7 + fire.global_position.z
		for child in fire.get_children():
			if child is OmniLight3D:
				var lamp := child as OmniLight3D
				lamp.light_energy = 2.0 + sin(_time * 9.0 + phase) * 0.30 + sin(_time * 23.0 + phase) * 0.12
func _track_area() -> void:
	if pip == null:
		return
	var here := along_of(pip.global_position)
	for i in range(AREAS.size() - 1, -1, -1):
		if here >= float(AREAS[i].along) and i > area:
			area = i
			_hud.section = str(AREAS[i].name)
			_hud.flash(str(AREAS[i].name))
func _track_checkpoint() -> void:
	if pip == null or finished or _next_checkpoint >= _checkpoints.size():
		return
	if along_of(pip.global_position) >= _checkpoint_along[_next_checkpoint]:
		pip.set_checkpoint(_checkpoints[_next_checkpoint])
		_next_checkpoint += 1
func _track_finish() -> void:
	if pip == null or finished:
		return
	if along_of(pip.global_position) >= FINISH_ALONG:
		finished = true
		_hud.finish()
func _catch_falls() -> void:
	if pip == null or finished:
		return
	if not fallen_into(pip.global_position).is_empty():
		pip.respawn()
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#BFEFFF")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#CDEAFF")
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.04
	env.tonemap_white = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.ssao_power = 1.6
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.06
	_env = env
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	RenderingServer.global_shader_parameter_set("cloud_strength", 0.05)
func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var travel := Vector3(-0.42, -0.70, -0.34).normalized()
	sun.basis = Basis.looking_at(travel, Vector3.UP)
	sun.light_color = Color("#FFF6E0")
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	_sun = sun
	add_child(sun)
func _build_cloud_sea() -> void:
	var root := Node3D.new()
	root.name = "CloudSea"
	add_child(root)
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 1.0
	puff_mesh.height = 1.4
	puff_mesh.radial_segments = 16
	puff_mesh.rings = 8
	var puff_mat := mat(Color("#EAF6FF"), {"rim": 0.0, "flat": 1.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	for i in range(18):
		var puff := MeshInstance3D.new()
		puff.mesh = puff_mesh
		puff.material_override = puff_mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulk := rng.randf_range(7.0, 14.0)
		var side := 1.0 if i % 2 == 0 else -1.0
		puff.position = at(
			rng.randf_range(-30.0, 120.0),
			side * rng.randf_range(26.0, 64.0),
			rng.randf_range(-26.0, -18.0)
		)
		puff.scale = Vector3(bulk, bulk * 0.30, bulk)
		root.add_child(puff)
func _build_backdrop(cam: Camera3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	var quad := QuadMesh.new()
	var aspect := 16.0 / 9.0
	quad.size = Vector2(cam.size * aspect, cam.size) * 1.01
	mi.mesh = quad
	var m := ShaderMaterial.new()
	m.shader = load(BACKDROP_SHADER)
	m.set_shader_parameter("top_col", Color("#5FC6F0"))
	m.set_shader_parameter("upper_col", Color("#8ADEF8"))
	m.set_shader_parameter("mid_col", Color("#C7F1FF"))
	m.set_shader_parameter("horizon_col", Color("#FFF1D6"))
	m.set_shader_parameter("haze_col", Color("#FFE4BE"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.position = Vector3(0, 0, -200.0)
	cam.add_child(mi)
func _tint(index: int) -> Array:
	match index:
		1:
			return [COL.mint, COL.mint_dark]
		2:
			return [COL.lilac, COL.lilac_dark]
		3:
			return [COL.peach, COL.peach_dark]
	return [COL.frost, COL.frost_dark]
func _pad(u0: float, u1: float, v0: float, v1: float, height: float, stage: int) -> StaticBody3D:
	var tint := _tint(stage)
	return tile_deck(u0, u1, v0, v1, height, tint[0], COL.cream, tint[1])
func _build_course() -> void:
	_powder_bowl()
	_the_ledges()
	_the_chimney()
	_the_thaw()
func _powder_bowl() -> void:
	_pad(0.0, 4.5, -5.0, 5.0, DECK, 0)
	snow_patch(2.9, -2.9, DECK, 1.7)
	gap(4.5, 5.5, -5.0, 5.0, DECK)
	_pad(5.5, 11.0, -5.0, 5.0, DECK, 0)
	campfire(7.4, 3.0, DECK, 1.0)
	snow_patch(9.4, -2.9, DECK, 1.0)
	gap(11.0, 12.0, -5.0, 5.0, DECK)
	_pad(12.0, 18.0, -5.0, 5.0, DECK, 0)
	snow_field(13.0, 16.6, -4.5, -1.7, DECK, 1.4)
	gap(18.0, 19.5, -5.0, 5.0, DECK)
	_pad(19.5, 23.0, -5.0, 5.0, DECK, 0)
	snow_patch(20.8, -2.8, DECK, 1.0)
func _the_ledges() -> void:
	_pad(23.0, 30.0, -5.0, 5.0, DECK, 1)
	flag(23.6, 4.2, DECK, COL.lemon)
	campfire(22.0, 3.0, DECK, 1.0)
	tunnel(25.8, 0.0, DECK, 1.9, 3.6, 4.6, LANE, _tint(1)[0], COL.cream)
	_pad(30.0, 34.0, -5.0, 5.0, DECK, 1)
	tunnel(31.6, 0.0, DECK, 1.2, 3.2, 4.4, LANE, _tint(1)[0], COL.cream)
	_pad(34.0, 38.0, -5.0, 5.0, DECK, 1)
	campfire(34.6, 3.0, DECK, 1.0)
	snow_patch(35.4, -2.9, DECK, 1.05)
	gap(38.0, 39.0, -5.0, 5.0, DECK)
	_pad(39.0, 43.0, -5.0, 5.0, DECK, 1)
	snow_field(39.7, 42.9, -4.5, -1.7, DECK, 1.4)
	gap(43.0, 43.0 + GAP_WIDE / TILE, -5.0, 5.0, DECK)
	_pad(43.0 + GAP_WIDE / TILE, 47.0, -5.0, 5.0, DECK, 1)
	snow_patch(46.0, -2.7, DECK, 1.0)
func _the_chimney() -> void:
	ramp(47.0, 50.5, -5.0, 5.0, DECK, HIGH, _tint(2)[0], COL.cream, _tint(2)[1])
	_pad(50.5, 58.0, -3.0, 3.0, HIGH, 2)
	_pad(50.5, 58.0, -5.0, -3.0, HIGH + 2.8, 2)
	_pad(50.5, 58.0, 3.0, 5.0, HIGH + 2.8, 2)
	snow_patch(51.4, -2.1, HIGH, 0.9)
	campfire(52.9, 2.0, HIGH, 0.9)
	tunnel(55.8, 0.0, HIGH, 1.2, 3.2, 4.4, 3.6, _tint(2)[0], COL.cream)
	_pad(58.0, 61.0, -5.0, 5.0, DECK, 2)
func _the_thaw() -> void:
	_pad(61.0, 66.5, -5.0, 5.0, DECK, 3)
	flag(61.0, 4.2, DECK, COL.lemon)
	snow_field(61.6, 65.4, -4.5, -1.7, DECK, 1.5)
	gap(66.5, 68.0, -5.0, 5.0, DECK)
	_pad(68.0, 71.0, -5.0, 5.0, DECK, 3)
	snow_patch(69.2, -2.8, DECK, 1.25)
	gap(71.0, 71.0 + GAP_WIDE / TILE, -5.0, 5.0, DECK)
	_pad(71.0 + GAP_WIDE / TILE, 79.0, -5.0, 5.0, DECK, 3)
	goal(75.8, 0.0, DECK)
func _build_player() -> void:
	var pip_node := PipController.new()
	pip_node.name = "Pip"
	pip_node.position = at(1.0, 0.0, DECK) + Vector3(0.0, SizeController.START_RADIUS + 0.2, 0.0)
	var visual := Node3D.new()
	visual.name = "Visual"
	pip_node.add_child(visual)
	var art := Node3D.new()
	art.name = "Art"
	visual.add_child(art)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.material_override = mat(Color("#F4FAFF"), {"flat": 0.0, "rim": 0.30, "spec": 0.0, "bands": 4.0})
	body.mesh = _sphere(0.68, 24, 14)
	art.add_child(body)
	var face := Vector3(1.0, 0.15, 1.0).normalized()
	var right := Vector3(1.0, 0.0, -1.0).normalized()
	var up_face := face.cross(right).normalized()
	var face_basis := Basis(right, up_face, face)
	var eye_mat := mat(COL.eye, {"flat": 0.0, "bands": 2.0, "emit": COL.eye, "emit_energy": 0.35})
	var shine_mat := mat(Color.WHITE, {"flat": 0.0, "bands": 1.0, "emit": Color.WHITE, "emit_energy": 1.0})
	for sign_x: float in [-1.0, 1.0]:
		var eye_pos := face * 0.610 + right * 0.175 * sign_x + up_face * 0.215
		_sphere_mesh(art, _sphere(0.078, 12, 8), eye_mat, eye_pos, Vector3(1.0, 1.12, 1.0))
		var shine := eye_pos + face * 0.058 + up_face * 0.028 - right * 0.020 * sign_x
		_sphere_mesh(art, _sphere(0.021, 6, 4), shine_mat, shine, Vector3.ONE)
	var mouth_center := face * 0.664 + up_face * 0.062
	var mouth_half := 0.068
	var mouth_lift := 0.030
	var prev := Vector2(-mouth_half, mouth_lift)
	for i in range(1, 5):
		var x := lerpf(-mouth_half, mouth_half, float(i) / 4.0)
		var p := Vector2(x, mouth_lift * pow(x / mouth_half, 2.0))
		var span := p - prev
		_box_on(
			art,
			Vector3(span.length() + 0.010, 0.026, 0.048),
			COL.eye,
			mouth_center + right * (prev.x + span.x * 0.5) + up_face * (prev.y + span.y * 0.5),
			face_basis * Basis(Vector3.BACK, span.angle())
		).material_override = eye_mat
		prev = p
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = SizeController.START_RADIUS * SizeController.COLLISION_SCALE
	shape.shape = sphere_shape
	pip_node.add_child(shape)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.35, 1.35)
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	shadow.mesh = quad
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = _radial_texture()
	sm.albedo_color = Color(0.18, 0.24, 0.48, 0.11)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.disable_receive_shadows = true
	shadow.material_override = sm
	shadow.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	shadow.position = Vector3(0, -SizeController.START_RADIUS, 0)
	pip_node.add_child(shadow)
	pip = pip_node
	add_child(pip_node)
func _sphere(radius: float, segs := 16, rings := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segs
	s.rings = rings
	return s
func _sphere_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scl: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
func _build_camera() -> void:
	var cam := PixelSnapCamera.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.6
	cam.near = 0.5
	cam.far = 300.0
	cam.target_path = NodePath("../Pip")
	cam.framing_offset = Vector3(0.0, 1.0, 0.0)
	cam.back_distance = 46.0
	cam.follow_speed = 6.0
	cam.deadzone = 0.12
	cam.look_ahead = 0.16
	var view := (ALONG * cos(ISO_SWING) + ACROSS * sin(ISO_SWING)).normalized()
	var iso_dir := view * cos(ISO_PITCH) - Vector3.UP * sin(ISO_PITCH)
	cam.basis = Basis.looking_at(iso_dir, Vector3.UP)
	add_child(cam)
	_camera = cam
	var post := MeshInstance3D.new()
	post.name = "OutlinePost"
	var quad := QuadMesh.new()
	quad.size = Vector2(90, 60)
	post.mesh = quad
	var m := ShaderMaterial.new()
	m.shader = load(OUTLINE_SHADER)
	m.render_priority = 100
	_outline = m
	post.material_override = m
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post.extra_cull_margin = 16384.0
	post.position = Vector3(0, 0, -2)
	cam.add_child(post)
	_build_backdrop(cam)
func _build_hud() -> void:
	_hud = DevHud.new()
	_hud.name = "HUD"
	_hud.pip = pip
	_hud.section = str(AREAS[0].name)
	add_child(_hud)
	_gauge = SizeGauge.new()
	_gauge.name = "SizeGauge"
	add_child(_gauge)
	_gauge.bind(pip)
func _radial_texture() -> Texture2D:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length() / half
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
