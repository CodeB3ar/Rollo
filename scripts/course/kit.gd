class_name CourseKit
extends Node3D
const TOON := "res://shaders/toon.gdshader"
const ALONG := Vector3(-0.70710678, 0.0, -0.70710678)
const ACROSS := Vector3(0.70710678, 0.0, -0.70710678)
const YAW := PI * 0.25
const TILE := 1.2
const SLAB := 1.0
const SNOW_GROUP := "snow_patch"
const FIRE_GROUP := "campfire"
const TUNNEL_GROUP := "tunnel"
const FIT_MARGIN := 0.02
const GAP_CRACK := 0.6
const GAP_STEP := 1.2
const GAP_LONG := 1.8
const GAP_WIDE := 2.0
const FALL_DEPTH := 0.9
var gaps: Array[Dictionary] = []
var _toon: Shader
var _mats := {}
func at(along: float, across: float, height: float) -> Vector3:
	return ALONG * along + ACROSS * across + Vector3(0.0, height, 0.0)
func tile(u: float, v: float, height: float) -> Vector3:
	return at(u * TILE, v * TILE, height)
func along_of(point: Vector3) -> float:
	return point.x * ALONG.x + point.z * ALONG.z
func across_of(point: Vector3) -> float:
	return point.x * ACROSS.x + point.z * ACROSS.z
static func fits(radius: float, clearance: float) -> bool:
	return radius * 2.0 <= clearance - FIT_MARGIN
func fallen_into(point: Vector3) -> Dictionary:
	var u := along_of(point)
	var v := across_of(point)
	for gap_data in gaps:
		if u < float(gap_data.along_min) or u > float(gap_data.along_max):
			continue
		if v < float(gap_data.across_min) or v > float(gap_data.across_max):
			continue
		if point.y < float(gap_data.height) - FALL_DEPTH:
			return gap_data
	return {}
func toon() -> Shader:
	if _toon == null:
		_toon = load(TOON)
	return _toon
func mat(colour: Color, opts := {}) -> ShaderMaterial:
	var key := "%s|%s" % [colour.to_html(), var_to_str(opts)]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = toon()
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("flat_shade", float(opts.get("flat", 0.0)))
	m.set_shader_parameter("band_count", float(opts.get("bands", 3.0)))
	m.set_shader_parameter("rim_strength", float(opts.get("rim", 0.16)))
	m.set_shader_parameter("specular_strength", float(opts.get("spec", 0.0)))
	m.set_shader_parameter("emission_color", opts.get("emit", Color.BLACK))
	m.set_shader_parameter("emission_energy", float(opts.get("emit_energy", 0.0)))
	_mats[key] = m
	return m
func _mesh_on(parent: Node3D, mesh: Mesh, colour: Color, centre: Vector3, basis := Basis.IDENTITY, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(colour, opts)
	mi.transform = Transform3D(basis, centre)
	parent.add_child(mi)
	return mi
func _box_on(parent: Node3D, size: Vector3, colour: Color, centre: Vector3, basis := Basis.IDENTITY, opts := {}) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh_on(parent, box, colour, centre, basis, opts)
func _cyl_on(parent: Node3D, radius: float, height: float, colour: Color, centre: Vector3, segs := 18, opts := {}) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = segs
	cyl.rings = 1
	return _mesh_on(parent, cyl, colour, centre, Basis.IDENTITY, opts)
func _cone_on(parent: Node3D, radius: float, height: float, colour: Color, centre: Vector3, segs := 7, opts := {}) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = segs
	cone.rings = 1
	var mi := _mesh_on(parent, cone, colour, centre, Basis.IDENTITY, opts)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
func _add_box(size: Vector3, colour: Color, centre: Vector3, basis := Basis.IDENTITY, opts := {}) -> MeshInstance3D:
	return _box_on(self, size, colour, centre, basis, opts)
func _body(centre: Vector3, basis: Basis, surface := Surfaces.Surf.NEUTRAL) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, centre)
	body.set_meta("surface", surface)
	add_child(body)
	return body
func _shape(box: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = box
	return s
func _add_shape(body: StaticBody3D, shape: Shape3D, centre: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = centre
	body.add_child(cs)
func tile_deck(u0: float, u1: float, v0: float, v1: float, height: float, top: Color, rim: Color, side: Color) -> StaticBody3D:
	var span_u := absf(u1 - u0) * TILE
	var span_v := absf(v1 - v0) * TILE
	var along := (u0 + u1) * 0.5 * TILE
	var across := (v0 + v1) * 0.5 * TILE
	var basis := Basis(Vector3.UP, YAW)
	var body := _body(at(along, across, height - SLAB * 0.5), basis)
	_add_shape(body, _shape(Vector3(span_v, SLAB, span_u)), Vector3.ZERO)
	_add_box(Vector3(span_v, SLAB, span_u), side.lightened(0.34), at(along, across, height - SLAB * 0.5 - 0.02), basis)
	_add_box(Vector3(span_v - 0.06, SLAB * 0.40, span_u - 0.06), side.darkened(0.14), at(along, across, height - SLAB * 0.76), basis)
	_add_box(Vector3(span_v + 0.26, 0.30, span_u + 0.26), rim, at(along, across, height - 0.20), basis)
	_add_box(Vector3(span_v - 0.04, 0.16, span_u - 0.04), top, at(along, across, height - 0.09), basis)
	_tile_skin(u0, u1, v0, v1, height, top)
	return body
func _tile_skin(u0: float, u1: float, v0: float, v1: float, height: float, top: Color) -> void:
	var lo_u := minf(u0, u1)
	var hi_u := maxf(u0, u1)
	var lo_v := minf(v0, v1)
	var hi_v := maxf(v0, v1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for i in range(int(floor(lo_u)), int(ceil(hi_u))):
		for j in range(int(floor(lo_v)), int(ceil(hi_v))):
			var ua := maxf(float(i), lo_u)
			var ub := minf(float(i + 1), hi_u)
			var va := maxf(float(j), lo_v)
			var vb := minf(float(j + 1), hi_v)
			if ub - ua < 0.001 or vb - va < 0.001:
				continue
			var shade := 1.0 if absi(i + j) % 2 == 0 else 0.90
			var p00 := tile(ua, va, height)
			var p01 := tile(ua, vb, height)
			var p11 := tile(ub, vb, height)
			var p10 := tile(ub, va, height)
			for point in [p00, p01, p11, p00, p11, p10]:
				verts.append(point)
				normals.append(Vector3.UP)
				colours.append(Color(shade, shade, shade))
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Tiles"
	mi.mesh = mesh
	mi.material_override = mat(top)
	add_child(mi)
func gap(u0: float, u1: float, v0: float, v1: float, height: float) -> void:
	var span_u := absf(u1 - u0) * TILE
	var span_v := absf(v1 - v0) * TILE
	gaps.append({
		"width": span_u,
		"height": height,
		"along_min": minf(u0, u1) * TILE,
		"along_max": maxf(u0, u1) * TILE,
		"across_min": minf(v0, v1) * TILE,
		"across_max": maxf(v0, v1) * TILE,
	})
	var basis := Basis(Vector3.UP, YAW)
	var lo_u := minf(u0, u1) * TILE
	var hi_u := maxf(u0, u1) * TILE
	var lo_v := minf(v0, v1) * TILE
	var hi_v := maxf(v0, v1) * TILE
	var drop := 2.6
	var wall: Color = Palette.COL.ink.lightened(0.12)
	var side := 0.16
	_add_box(
		Vector3(span_v - side, 0.16, span_u - side),
		Palette.COL.ink.darkened(0.25),
		at((lo_u + hi_u) * 0.5, (lo_v + hi_v) * 0.5, height - drop),
		basis,
		{"flat": 1.0}
	)
	_add_box(
		Vector3(span_v - side, drop, side),
		wall,
		at(hi_u - side * 0.5, (lo_v + hi_v) * 0.5, height - drop * 0.5),
		basis,
		{"flat": 1.0}
	)
	_add_box(
		Vector3(side, drop, span_u - side),
		wall.lightened(0.06),
		at((lo_u + hi_u) * 0.5, hi_v - side * 0.5, height - drop * 0.5),
		basis,
		{"flat": 1.0}
	)
func ramp(u0: float, u1: float, v0: float, v1: float, from_height: float, to_height: float, top: Color, rim: Color, side: Color) -> StaticBody3D:
	var across := (v0 + v1) * 0.5 * TILE
	var width := absf(v1 - v0) * TILE
	var a := at(u0 * TILE, across, from_height)
	var b := at(u1 * TILE, across, to_height)
	var forward := (b - a).normalized()
	var up := (Vector3.UP - forward * forward.dot(Vector3.UP)).normalized()
	var basis := Basis(ACROSS, up, ACROSS.cross(up))
	var length := a.distance_to(b)
	var centre := (a + b) * 0.5 - up * (SLAB * 0.5)
	var body := _body(centre, basis)
	_add_shape(body, _shape(Vector3(width, SLAB, length)), Vector3.ZERO)
	_add_box(Vector3(width, SLAB, length), side, centre - up * 0.02, basis)
	_add_box(Vector3(width - 0.06, SLAB * 0.42, length - 0.06), side.darkened(0.52), centre - up * (SLAB * 0.24), basis)
	_add_box(Vector3(width + 0.26, 0.30, length), rim, centre + up * (SLAB * 0.5 - 0.20), basis)
	_add_box(Vector3(width, 0.16, length), top, centre + up * (SLAB * 0.5 - 0.09), basis)
	_ramp_ribs(centre, basis, width, length, top)
	return body
func _ramp_ribs(centre: Vector3, basis: Basis, width: float, length: float, top: Color) -> void:
	var ribs := int(maxf(floor(length / TILE), 1.0))
	for k in range(ribs):
		var t := (float(k) + 0.5) / float(ribs)
		var at_local := basis.z * (t - 0.5) * length + basis.y * (SLAB * 0.5 - 0.06)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width - 1.4, 0.02, 0.16)
		mi.mesh = box
		mi.material_override = mat(top.darkened(0.18))
		mi.transform = Transform3D(basis, centre + at_local)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
func tunnel(u: float, v: float, height: float, clearance: float, depth: float, width: float, lane_half: float, wall: Color, trim: Color) -> StaticBody3D:
	var along := u * TILE
	var across := v * TILE
	var basis := Basis(Vector3.UP, YAW)
	var body := _body(at(along, across, height), basis)
	body.add_to_group(TUNNEL_GROUP)
	body.set_meta("clearance", clearance)
	body.set_meta("opening", width)
	var roof_t := 0.8
	var roof_width := width + 0.4
	var tall := clearance + roof_t + 0.22
	var edge := width * 0.5
	var outer := maxf(lane_half, edge + 0.4)
	var pier := outer - edge
	var pier_centre := (edge + outer) * 0.5
	for side_sign: float in [-1.0, 1.0]:
		_add_shape(body, _shape(Vector3(pier, tall, depth)), Vector3(side_sign * pier_centre, tall * 0.5, 0.0))
		_add_box(Vector3(pier, tall, depth), wall, at(along, across + side_sign * pier_centre, height + tall * 0.5), basis)
	var lintel_h := tall - clearance
	_add_shape(body, _shape(Vector3(roof_width, lintel_h, depth)), Vector3(0.0, clearance + lintel_h * 0.5, 0.0))
	_add_box(
		Vector3(roof_width, lintel_h, depth),
		wall,
		at(along, across, height + clearance + lintel_h * 0.5),
		basis
	)
	var face := along - depth * 0.5 - 0.03
	for side_sign: float in [-1.0, 1.0]:
		_add_box(
			Vector3(0.22, clearance + 0.22, 0.12),
			trim,
			at(face, across + side_sign * (edge + 0.05), height + (clearance + 0.22) * 0.5),
			basis
		)
	_add_box(
		Vector3(width + 0.54, 0.22, 0.12),
		trim,
		at(face, across, height + clearance + 0.11),
		basis
	)
	return body
func snow_field(u0: float, u1: float, v0: float, v1: float, height: float, radius := 1.7) -> Node3D:
	var span_u := absf(u1 - u0) * TILE
	var span_v := absf(v1 - v0) * TILE
	var root := Node3D.new()
	root.name = "SnowField"
	root.position = tile((u0 + u1) * 0.5, (v0 + v1) * 0.5, height)
	root.add_to_group(SNOW_GROUP)
	root.set_meta("radius", maxf(span_u, span_v) * 0.5)
	root.set_meta("rect", Vector2(span_u * 0.5, span_v * 0.5))
	add_child(root)
	_bed(root, span_u, span_v, 0.16)
	return root
func _bed(root: Node3D, span_u: float, span_v: float, depth: float) -> void:
	var half_u := span_u * 0.5
	var half_v := span_v * 0.5
	var shoulder := minf(minf(0.20, half_u * 0.4), half_v * 0.4)
	var nu := clampi(int(ceil(span_u / 0.34)), 4, 48)
	var nv := clampi(int(ceil(span_v / 0.34)), 4, 48)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for i in range(nu):
		var a0 := -half_u + span_u * float(i) / float(nu)
		var a1 := -half_u + span_u * float(i + 1) / float(nu)
		for j in range(nv):
			var b0 := -half_v + span_v * float(j) / float(nv)
			var b1 := -half_v + span_v * float(j + 1) / float(nv)
			var quad := [
				Vector2(a0, b0), Vector2(a0, b1), Vector2(a1, b1),
				Vector2(a0, b0), Vector2(a1, b1), Vector2(a1, b0),
			]
			for corner: Vector2 in quad:
				var lift := _bed_lift(corner, half_u, half_v, shoulder, depth)
				verts.append(ALONG * corner.x + ACROSS * corner.y + Vector3.UP * lift)
				normals.append(_bed_normal(corner, half_u, half_v, shoulder, depth))
				colours.append(Color(1.0, 1.0, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Bed"
	mi.mesh = mesh
	mi.material_override = mat(Palette.COL.deep_snow, {"rim": 0.10, "bands": 3.0})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
func _bed_lift(p: Vector2, half_u: float, half_v: float, shoulder: float, depth: float) -> float:
	var edge := minf(half_u - absf(p.x), half_v - absf(p.y))
	var t := clampf(edge / maxf(shoulder, 0.01), 0.0, 1.0)
	var swell := 0.88 + 0.12 * sin(p.x * 1.9 + 0.7) * cos(p.y * 2.3)
	return 0.005 + depth * smoothstep(0.0, 1.0, t) * swell
func _bed_normal(p: Vector2, half_u: float, half_v: float, shoulder: float, depth: float) -> Vector3:
	var e := 0.06
	var du := _bed_lift(p + Vector2(e, 0.0), half_u, half_v, shoulder, depth) - _bed_lift(p - Vector2(e, 0.0), half_u, half_v, shoulder, depth)
	var dv := _bed_lift(p + Vector2(0.0, e), half_u, half_v, shoulder, depth) - _bed_lift(p - Vector2(0.0, e), half_u, half_v, shoulder, depth)
	var tangent_u := ALONG + Vector3.UP * (du / (2.0 * e))
	var tangent_v := ACROSS + Vector3.UP * (dv / (2.0 * e))
	return tangent_v.cross(tangent_u).normalized()
func snow_patch(u: float, v: float, height: float, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "SnowPatch"
	root.position = tile(u, v, height)
	root.set_meta("radius", radius)
	root.add_to_group(SNOW_GROUP)
	add_child(root)
	_disc(root, radius, 0.18)
	return root
func _disc(root: Node3D, radius: float, depth: float) -> void:
	var segs := 28
	var rings := 5
	var shoulder := minf(0.24, radius * 0.36)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for i in range(rings):
		var r0 := radius * float(i) / float(rings)
		var r1 := radius * float(i + 1) / float(rings)
		for j in range(segs):
			var a0 := TAU * float(j) / float(segs)
			var a1 := TAU * float(j + 1) / float(segs)
			var corners := [Vector2(r0, a0), Vector2(r0, a1), Vector2(r1, a1), Vector2(r1, a0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var corner: Vector2 = corners[idx]
				var radial := ALONG * cos(corner.y) + ACROSS * sin(corner.y)
				verts.append(radial * corner.x + Vector3.UP * _disc_lift(corner.x, radius, shoulder, depth, corner.y))
				normals.append(_disc_normal(corner.x, radius, shoulder, depth, corner.y))
				colours.append(Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Bed"
	mi.mesh = mesh
	mi.material_override = mat(Palette.COL.deep_snow, {"rim": 0.10, "bands": 3.0})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
func _disc_lift(r: float, radius: float, shoulder: float, depth: float, angle: float) -> float:
	var t := clampf((radius - r) / maxf(shoulder, 0.01), 0.0, 1.0)
	var swell := 0.88 + 0.12 * sin(angle * 3.0 + 0.7)
	return 0.005 + depth * smoothstep(0.0, 1.0, t) * swell
func _disc_normal(r: float, radius: float, shoulder: float, depth: float, angle: float) -> Vector3:
	var e := 0.03
	var slope := (
		_disc_lift(r + e, radius, shoulder, depth, angle) - _disc_lift(r - e, radius, shoulder, depth, angle)
	) / (2.0 * e)
	var radial := ALONG * cos(angle) + ACROSS * sin(angle)
	return (Vector3.UP - radial * slope).normalized()
func campfire(u: float, v: float, height: float, radius := 1.9) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	root.position = tile(u, v, height)
	root.set_meta("radius", radius)
	root.add_to_group(FIRE_GROUP)
	add_child(root)
	_cyl_on(root, radius * 0.62, 0.10, Color("#8A6B5E"), Vector3(0.0, 0.01, 0.0), 20, {"flat": 1.0})
	_cyl_on(root, radius * 0.44, 0.11, Palette.COL.ash, Vector3(0.0, 0.02, 0.0), 18, {"flat": 1.0})
	for k in range(9):
		var angle := TAU * float(k) / 9.0 + 0.25
		var d := radius * 0.66
		var s := 0.115 + 0.025 * float(k % 3)
		var stone := _cyl_on(root, s, s * 1.5, Palette.COL.stone.darkened(0.18 + 0.06 * float(k % 2)), Vector3(cos(angle) * d, s * 0.5, sin(angle) * d), 6, {"flat": 1.0})
		stone.rotation = Vector3(0.0, angle * 1.7, 0.0)
	for k in range(3):
		var angle := TAU * float(k) / 3.0
		_box_on(
			root,
			Vector3(0.16, 0.16, 1.15),
			Palette.COL.wood,
			Vector3(cos(angle) * 0.16, 0.16, sin(angle) * 0.16),
			Basis(Vector3.UP, angle + 0.5) * Basis(Vector3.RIGHT, 0.10)
		)
	_cone_on(root, 0.50, 1.55, Palette.COL.flame, Vector3(0.0, 0.82, 0.0), 7, {"flat": 1.0, "emit": Palette.COL.flame, "emit_energy": 1.3, "bands": 2.0})
	_cone_on(root, 0.30, 1.85, Palette.COL.flame_core, Vector3(0.05, 1.05, 0.02), 6, {"flat": 1.0, "emit": Palette.COL.flame_core, "emit_energy": 1.6, "bands": 2.0})
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#FFB070")
	lamp.light_energy = 2.2
	lamp.omni_range = 8.5
	lamp.omni_attenuation = 1.4
	lamp.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(lamp)
	return root
func signboard(u: float, v: float, height: float, text: String, colour: Color, px := 0.006) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = px
	label.modulate = colour
	label.outline_size = 22
	label.outline_modulate = Palette.COL.ink
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.position = tile(u, v, height)
	add_child(label)
	return label
func flag(u: float, v: float, height: float, colour: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Flag"
	root.position = tile(u, v, height)
	add_child(root)
	_cyl_on(root, 0.075, 2.7, Palette.COL.cream, Vector3(0.0, 1.35, 0.0), 8)
	_cyl_on(root, 0.26, 0.16, Palette.COL.cream, Vector3(0.0, 0.08, 0.0), 10)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.05, 0.60)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat(colour, {"flat": 1.0, "rim": 0.0})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.looking_at(-ALONG, Vector3.UP), ACROSS * 0.56 + Vector3.UP * 2.30)
	root.add_child(mi)
	return root
func goal(u: float, v: float, height: float) -> void:
	var along := u * TILE
	var across := v * TILE
	var basis := Basis(Vector3.UP, YAW)
	for side_sign: float in [-1.0, 1.0]:
		var post := _body(at(along, across + side_sign * 3.4, height + 2.0), basis)
		_add_shape(post, _shape(Vector3(0.9, 4.0, 0.9)), Vector3.ZERO)
		_add_box(Vector3(0.9, 4.0, 0.9), Palette.COL.lemon, at(along, across + side_sign * 3.4, height + 2.0), basis)
	_add_box(Vector3(7.7, 0.9, 0.9), Palette.COL.lemon, at(along, across, height + 4.45), basis)
	_add_box(Vector3(7.9, 0.24, 1.1), Palette.COL.cream, at(along, across, height + 4.0), basis)
	signboard(u, v, height + 5.2, "FINISH", Palette.COL.lemon, 0.010)
