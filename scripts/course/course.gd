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

	# One checkpoint per hazard, always on the pad that holds the snow or the
	# fire for the thing ahead, so a retry starts with the answer in reach.
	_checkpoints = [
		at(1.0, 0.0, DECK),		# start
		at(3.0, 0.0, DECK),		# on the first drift
		at(5.0, 0.0, DECK),		# before the first crack
		at(9.2, 0.0, DECK),		# on the patch before the second crack
		at(13.0, 0.0, DECK),	# past the fire, at the long drift
		at(17.0, 0.0, DECK),	# on the field before the 1.8 m chasm
		at(21.0, 0.0, DECK),	# past it, before the wide gate
		at(27.0, 0.0, DECK),	# before the fire that shrinks you
		at(32.0, 0.0, DECK),	# before the narrow gate
		at(35.2, 0.0, DECK),	# on the patch past the gate
		at(40.4, 0.0, DECK),	# on the field before the chasm
		at(45.2, 0.0, DECK),	# at the foot of the ramp
		at(52.0, 0.0, HIGH),	# in the slot, on the snow
		at(58.6, 0.0, DECK),	# after the drop, on the long field
		at(69.0, 0.0, DECK),	# on the island between the twin chasms
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


# ------------------------------------------------------------------- per frame


func _process(delta: float) -> void:
	_time += delta
	# The toon shader's cloud shadows ride on this global; without it the whole
	# course sits under one static cloud.
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


# ------------------------------------------------------------------- world look


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

	# No fog: an iso course is read at a glance, and distance haze is the
	# fastest way to turn four stage colours into one grey one.
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

	# Soften the cloud shadows the toon shader draws on the decks: they are a
	# nice bit of life, but at full strength they mottle the stage colours.
	RenderingServer.global_shader_parameter_set("cloud_strength", 0.05)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Light from the camera side. The sun used to travel away from the eye, which
	# put every face the camera can see just past the terminator: deck sides, gate
	# fronts and ledges all shaded to near-black while the tops stayed lit, and the
	# course read as a stack of dark shelves. From this side, tops sit in the lit
	# band and forward faces in the mid band, and shadows fall out of the way.
	var travel := Vector3(-0.42, -0.70, -0.34).normalized()
	sun.basis = Basis.looking_at(travel, Vector3.UP)
	sun.light_color = Color("#FFF6E0")
	# The toon shader scales LIGHT_COLOR by 0.62 without dividing out the PI that
	# Godot pre-applies to a directional light, so 1.18 of energy lands near 2.3x
	# exposure: every mid-tone clamped to white and snow was invisible against
	# the deck. 0.52 puts a mid-tone at about 1.0.
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
	# Pushed out of the play frame: the outline pass traces any hard silhouette
	# against the sky, so a puff inside the frame got a black rim and read as a
	# grey donut hanging in the level.
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
	# Full-frustum sky card parented to the camera, so the sky never slides or
	# scales as the camera follows Pip. Five colour stops, nothing drawn on top.
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


# ------------------------------------------------------------------ the course



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
	# The spawn is on bare tiles and the first drift starts a metre and a half up
	# the lane: a ball that grows the instant it appears reads as a bug.
	_pad(0.0, 4.5, -5.0, 5.0, DECK, 0)
	# Drifts live on the left, fires on the right, and neither reaches the middle
	# of the lane. Growing and melting are choices you steer into, not something
	# that happens to you because the hazard happens to be in the way, and the
	# racing line stays open between them.
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

	# The fire is on the landing *before* both gates, not after the first one. A
	# gate you are too big for with the only fire behind it is a dead end, and a
	# fire tucked right up against a gate is worse: the gate's piers are 1.8 m deep
	# on each side of the opening, so a fire that close ends up inside the wall and
	# a fat ball wedges against the pier trying to stand in it.
	campfire(22.0, 3.0, DECK, 1.0)

	# 1.9 m of clearance: a 0.55 m ball is 1.10 m across and rolls straight
	# through, so this one teaches that the gate itself is not the wall.
	tunnel(25.8, 0.0, DECK, 1.9, 3.6, 4.6, LANE, _tint(1)[0], COL.cream)
	_pad(30.0, 34.0, -5.0, 5.0, DECK, 1)
	tunnel(31.6, 0.0, DECK, 1.2, 3.2, 4.4, LANE, _tint(1)[0], COL.cream)

	# A drift on the far side of the gate: the ball squeezed through at almost
	# minimum width and has a crack to bridge next.
	_pad(34.0, 38.0, -5.0, 5.0, DECK, 1)
	# Fire then snow, in that order, on the long stretch out of the narrow gate:
	# melt, grow, cross. The fire is 2 m clear of the gate's far face, because a
	# fire pressed against a gate buries itself in the piers again.
	campfire(34.6, 3.0, DECK, 1.0)
	snow_patch(35.4, -2.9, DECK, 1.05)

	gap(38.0, 39.0, -5.0, 5.0, DECK)

	_pad(39.0, 43.0, -5.0, 5.0, DECK, 1)
	snow_field(39.7, 42.9, -4.5, -1.7, DECK, 1.4)

	# The widest hole before the finale: 2.0 m, which a Drift cannot bridge. It
	# takes a ball grown past every tier the course used to need.
	gap(43.0, 43.0 + GAP_WIDE / TILE, -5.0, 5.0, DECK)

	_pad(43.0 + GAP_WIDE / TILE, 47.0, -5.0, 5.0, DECK, 1)
	snow_patch(46.0, -2.7, DECK, 1.0)




func _the_chimney() -> void:
	ramp(47.0, 50.5, -5.0, 5.0, DECK, HIGH, _tint(2)[0], COL.cream, _tint(2)[1])

	# The slot floor is six tiles wide; the two decks either side of it are 2.8 m
	# higher, so the walls are just decks and need no new vocabulary.
	_pad(50.5, 58.0, -3.0, 3.0, HIGH, 2)
	_pad(50.5, 58.0, -5.0, -3.0, HIGH + 2.8, 2)
	_pad(50.5, 58.0, 3.0, 5.0, HIGH + 2.8, 2)
	snow_patch(51.4, -2.1, HIGH, 0.9)
	campfire(52.9, 2.0, HIGH, 0.9)
	tunnel(55.8, 0.0, HIGH, 1.2, 3.2, 4.4, 3.6, _tint(2)[0], COL.cream)

	# Out of the slot and down onto the floor. A 2.4 m drop with no hazard in it:
	# the run has to hand the player a moment where nothing can kill them.
	_pad(58.0, 61.0, -5.0, 5.0, DECK, 2)




func _the_thaw() -> void:
	_pad(61.0, 66.5, -5.0, 5.0, DECK, 3)
	flag(61.0, 4.2, DECK, COL.lemon)
	snow_field(61.6, 65.4, -4.5, -1.7, DECK, 1.5)

	gap(66.5, 68.0, -5.0, 5.0, DECK)

	_pad(68.0, 71.0, -5.0, 5.0, DECK, 3)
	snow_patch(69.2, -2.8, DECK, 1.25)

	# The last hole is the widest in the course, so the run ends on the biggest
	# ball the snow can make rather than on another 1.8 m step.
	gap(71.0, 71.0 + GAP_WIDE / TILE, -5.0, 5.0, DECK)

	_pad(71.0 + GAP_WIDE / TILE, 79.0, -5.0, 5.0, DECK, 3)
	goal(75.8, 0.0, DECK)


# ------------------------------------------------------------------------- Pip


func _build_player() -> void:
	var pip_node := PipController.new()
	pip_node.name = "Pip"
	pip_node.position = at(1.0, 0.0, DECK) + Vector3(0.0, SizeController.START_RADIUS + 0.2, 0.0)

	# Children are built BEFORE Pip enters the tree: PipController's @onready
	# lookups run the moment it is added to a live scene.
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

	# Face: big oval eyes with catchlights and a curved smile, aimed at the
	# camera diagonal.
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

	# Smile: a shallow arc of four short bars, ends lifted.
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

	# Soft contact shadow lying flat on the deck.
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


# ---------------------------------------------------------------------- camera


func _build_camera() -> void:
	var cam := PixelSnapCamera.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# 37.5 px/m at 640x360. The lane is 12 m (450 px) and 9.6 m of world runs
	# up the screen, which is 16.6 m of course: most of the lane and the next
	# hazard, with a start ball 41 px across.
	cam.size = 9.6
	cam.near = 0.5
	cam.far = 300.0
	cam.target_path = NodePath("../Pip")
	cam.framing_offset = Vector3(0.0, 1.0, 0.0)
	cam.back_distance = 46.0
	cam.follow_speed = 6.0
	cam.deadzone = 0.12
	cam.look_ahead = 0.16
	# Isometric, and specifically the kind where a block shows three faces.
	#
	# A deck's sides face straight along the course axes, so a camera pointed
	# down the lane looks *along* one pair of them: that face fills the silhouette
	# and the other pair is edge-on, which is why every pad read as a top and a
	# single skirt. The eye has to sit off the face, so the view is swung 20 deg
	# across the lane. The ball still rolls along the lane because the input is
	# mapped to the course axes (see `PipController._wish_direction`), not to the
	# camera: W is up the course, even though up the course is a little diagonal
	# on screen now.
	#
	# 30 deg of pitch on top of that, so tiles are 2:1 and the side faces carry
	# enough height to read the depth of a chasm.
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


# ------------------------------------------------------------------------- HUD


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
