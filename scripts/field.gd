class_name Field
extends Node3D
## A farm field, 100 m long (z) by 56 m wide (x), built in code. Red forms at the north end
## (-z), Blue at the south (+z). Cover is a handful of stone walls, rail fences, boulders, a
## ruined cottage and a few trees; a low piece is fired over, a tall piece stops the ball.

const HALF_X := 28.0
const HALF_Z := 50.0
const LAYER_WORLD := 1

## The layouts a campaign rotates through. Each is a list of x, z, size_x, size_z, height, kind.
const LAYOUTS := {
	"Walled Farm": [
		[-14.0, -22.0, 12.0, 0.6, 1.0, "wall"],
		[12.0, -18.0, 9.0, 0.6, 1.0, "wall"],
		[0.0, -8.0, 0.6, 10.0, 1.0, "wall"],
		[-18.0, 4.0, 10.0, 0.4, 1.1, "fence"],
		[16.0, 8.0, 0.4, 9.0, 1.1, "fence"],
		[-8.0, 20.0, 11.0, 0.6, 1.0, "wall"],
		[13.0, 24.0, 9.0, 0.6, 1.0, "wall"],
		[5.0, 2.0, 5.0, 4.0, 2.6, "house"],
		[-22.0, -10.0, 2.2, 2.0, 1.6, "boulder"],
		[22.0, 14.0, 2.4, 2.0, 1.5, "boulder"],
		[-6.0, -30.0, 1.0, 1.0, 5.0, "tree"],
		[20.0, -32.0, 1.0, 1.0, 5.0, "tree"],
		[-20.0, 30.0, 1.0, 1.0, 5.0, "tree"],
		[9.0, 34.0, 1.0, 1.0, 5.0, "tree"],
		[-11.0, 9.0, 1.0, 1.0, 5.0, "tree"],
	],
	"Open Plain": [
		[-16.0, -6.0, 2.0, 1.8, 1.4, "boulder"],
		[14.0, 5.0, 2.2, 2.0, 1.5, "boulder"],
		[2.0, -26.0, 1.0, 1.0, 5.0, "tree"],
		[-8.0, 28.0, 1.0, 1.0, 5.0, "tree"],
		[22.0, -1.0, 0.4, 8.0, 1.1, "fence"],
	],
	"Woodland": [
		[-18.0, -20.0, 1.0, 1.0, 5.0, "tree"], [-6.0, -16.0, 1.0, 1.0, 5.0, "tree"], [8.0, -22.0, 1.0, 1.0, 5.0, "tree"],
		[18.0, -12.0, 1.0, 1.0, 5.0, "tree"], [-12.0, -4.0, 1.0, 1.0, 5.0, "tree"], [3.0, -2.0, 1.0, 1.0, 5.0, "tree"],
		[15.0, 2.0, 1.0, 1.0, 5.0, "tree"], [-20.0, 8.0, 1.0, 1.0, 5.0, "tree"], [-4.0, 12.0, 1.0, 1.0, 5.0, "tree"],
		[10.0, 16.0, 1.0, 1.0, 5.0, "tree"], [22.0, 20.0, 1.0, 1.0, 5.0, "tree"], [-14.0, 24.0, 1.0, 1.0, 5.0, "tree"],
		[2.0, 28.0, 1.0, 1.0, 5.0, "tree"], [-9.0, -28.0, 1.0, 1.0, 5.0, "tree"], [17.0, 30.0, 1.0, 1.0, 5.0, "tree"],
		[-22.0, -2.0, 2.0, 1.8, 1.4, "boulder"], [6.0, 7.0, 2.4, 2.0, 1.6, "boulder"], [20.0, -30.0, 2.0, 1.8, 1.4, "boulder"],
		[-3.0, 20.0, 8.0, 0.6, 1.0, "wall"],
	],
	"Village": [
		[-12.0, -6.0, 5.0, 4.0, 2.6, "house"], [8.0, -10.0, 4.5, 4.0, 2.6, "house"], [14.0, 6.0, 5.0, 4.0, 2.6, "house"],
		[-6.0, 10.0, 4.5, 4.0, 2.6, "house"], [0.0, -24.0, 4.0, 3.5, 2.6, "house"], [2.0, 24.0, 4.0, 3.5, 2.6, "house"],
		[-20.0, -14.0, 10.0, 0.6, 1.0, "wall"], [20.0, 16.0, 10.0, 0.6, 1.0, "wall"],
		[-1.0, 0.0, 0.6, 9.0, 1.0, "wall"], [-18.0, 18.0, 0.4, 8.0, 1.1, "fence"], [18.0, -20.0, 0.4, 8.0, 1.1, "fence"],
		[-22.0, 30.0, 1.0, 1.0, 5.0, "tree"], [22.0, -32.0, 1.0, 1.0, 5.0, "tree"],
	],
	"Sunken Road": [
		[-14.0, -3.0, 24.0, 0.6, 1.0, "wall"], [16.0, -3.0, 16.0, 0.6, 1.0, "wall"],
		[-16.0, 3.0, 16.0, 0.6, 1.0, "wall"], [14.0, 3.0, 24.0, 0.6, 1.0, "wall"],
		[-10.0, -24.0, 10.0, 0.4, 1.1, "fence"], [10.0, 24.0, 10.0, 0.4, 1.1, "fence"],
		[-22.0, -16.0, 2.0, 1.8, 1.4, "boulder"], [22.0, 16.0, 2.0, 1.8, 1.4, "boulder"],
		[4.0, -34.0, 1.0, 1.0, 5.0, "tree"], [-4.0, 34.0, 1.0, 1.0, 5.0, "tree"], [24.0, -30.0, 1.0, 1.0, 5.0, "tree"],
	],
}
const LAYOUT_ORDER: Array[String] = ["Open Plain", "Walled Farm", "Woodland", "Village", "Sunken Road"]

var layout_name := "Walled Farm"

## x, z, size_x, size_z, height, kind
const PIECES: Array = [
	[-14.0, -22.0, 12.0, 0.6, 1.0, "wall"],
	[12.0, -18.0, 9.0, 0.6, 1.0, "wall"],
	[0.0, -8.0, 0.6, 10.0, 1.0, "wall"],
	[-18.0, 4.0, 10.0, 0.4, 1.1, "fence"],
	[16.0, 8.0, 0.4, 9.0, 1.1, "fence"],
	[-8.0, 20.0, 11.0, 0.6, 1.0, "wall"],
	[13.0, 24.0, 9.0, 0.6, 1.0, "wall"],
	[5.0, 2.0, 5.0, 4.0, 2.6, "house"],
	[-22.0, -10.0, 2.2, 2.0, 1.6, "boulder"],
	[22.0, 14.0, 2.4, 2.0, 1.5, "boulder"],
	[-6.0, -30.0, 1.0, 1.0, 5.0, "tree"],
	[20.0, -32.0, 1.0, 1.0, 5.0, "tree"],
	[-20.0, 30.0, 1.0, 1.0, 5.0, "tree"],
	[9.0, 34.0, 1.0, 1.0, 5.0, "tree"],
	[-11.0, 9.0, 1.0, 1.0, 5.0, "tree"],
]

var pieces: Array[Dictionary] = []   # {rect: Rect2 (x,z), h: float, kind: String, tall: bool}
var spots: Array[Dictionary] = []    # {pos: Vector3, piece: int, normal: Vector3}


func _ready() -> void:
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.33, 0.46, 0.24)
	ground.roughness = 1.0
	_static_box(Vector3(0, -0.5, 0), Vector3(HALF_X * 2 + 8, 1.0, HALF_Z * 2 + 8), ground)
	# a worn track across the middle, and lighter strips so movement reads
	var track := StandardMaterial3D.new()
	track.albedo_color = Color(0.5, 0.42, 0.28)
	var t := MeshInstance3D.new()
	t.mesh = _box_mesh(Vector3(HALF_X * 2, 0.02, 3.0))
	t.material_override = track
	t.position = Vector3(0, 0.005, -1.0)
	add_child(t)
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(0.36, 0.5, 0.26)
	for i in range(-4, 5):
		var s := MeshInstance3D.new()
		s.mesh = _box_mesh(Vector3(HALF_X * 2, 0.015, 4.0))
		s.material_override = stripe
		s.position = Vector3(0, 0.004, i * 11.0)
		add_child(s)
	# deployment lines at each end
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.85, 0.85, 0.8)
	for zz in [-HALF_Z + 6.0, HALF_Z - 6.0]:
		var l := MeshInstance3D.new()
		l.mesh = _box_mesh(Vector3(HALF_X * 2, 0.02, 0.15))
		l.material_override = line_mat
		l.position = Vector3(0, 0.01, zz)
		add_child(l)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.53, 0.48)
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = Color(0.45, 0.32, 0.18)
	var house_mat := StandardMaterial3D.new()
	house_mat.albedo_color = Color(0.62, 0.5, 0.4)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.45, 0.47)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.36, 0.25, 0.14)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.2, 0.4, 0.16)

	var pieces_src: Array = LAYOUTS.get(layout_name, PIECES)
	for i in pieces_src.size():
		var p: Array = pieces_src[i]
		var kind: String = p[5]
		var size := Vector3(p[2], p[4], p[3])
		var pos := Vector3(p[0], p[4] * 0.5, p[1])
		match kind:
			"wall":
				_static_box(pos, size, wall_mat)
			"fence":
				# two rails and posts, one collider
				var body := _static_box(pos, size, fence_mat, false)
				var along_x: bool = p[2] > p[3]
				var length: float = maxf(p[2], p[3])
				for rail_y in [0.45, 0.95]:
					var r := MeshInstance3D.new()
					r.mesh = _box_mesh(Vector3(length, 0.1, 0.1) if along_x else Vector3(0.1, 0.1, length))
					r.material_override = fence_mat
					r.position = Vector3(0, rail_y - pos.y, 0)
					body.add_child(r)
				var n := int(length / 2.0)
				for k in range(n + 1):
					var post := MeshInstance3D.new()
					post.mesh = _box_mesh(Vector3(0.14, 1.1, 0.14))
					post.material_override = fence_mat
					var off := -length * 0.5 + k * (length / n)
					post.position = Vector3(off if along_x else 0.0, 0.55 - pos.y, 0.0 if along_x else off)
					body.add_child(post)
			"house":
				var body := _static_box(pos, size, house_mat)
				var roof := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(size.x + 0.6, 1.4, size.z + 0.6)
				roof.mesh = pm
				var roof_mat := StandardMaterial3D.new()
				roof_mat.albedo_color = Color(0.35, 0.22, 0.18)
				roof.material_override = roof_mat
				roof.position = Vector3(0, size.y * 0.5 + 0.7, 0)
				body.add_child(roof)
			"boulder":
				var body := _static_box(pos, size, rock_mat, false)
				var m := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = maxf(size.x, size.z) * 0.6
				sm.height = size.y * 1.3
				m.mesh = sm
				m.material_override = rock_mat
				body.add_child(m)
			"tree":
				var body := _static_box(Vector3(p[0], 1.5, p[1]), Vector3(0.6, 3.0, 0.6), trunk_mat)
				var crown := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 2.4
				sm.height = 4.0
				crown.mesh = sm
				crown.material_override = leaf_mat
				crown.position = Vector3(0, 3.2, 0)
				body.add_child(crown)
		var rect := Rect2(p[0] - p[2] * 0.5, p[1] - p[3] * 0.5, p[2], p[3])
		var tall: bool = kind == "house" or kind == "tree" or p[4] >= 1.4
		pieces.append({"rect": rect, "h": float(p[4]), "kind": kind, "tall": tall})
		_make_spots(i, rect, kind)


## Firing positions along each face of a piece: a man's width back from it, one every 1.3 m.
func _make_spots(idx: int, rect: Rect2, kind: String) -> void:
	var faces: Array = []
	if kind == "tree" or kind == "boulder":
		# corners around a small piece; both sides matter
		for n in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
			var c := Vector3(rect.get_center().x, 0, rect.get_center().y)
			faces.append({"pos": c + n * (maxf(rect.size.x, rect.size.y) * 0.5 + 0.9), "normal": n})
		for f in faces:
			spots.append({"pos": f["pos"], "piece": idx, "normal": f["normal"]})
		return
	var along_x := rect.size.x >= rect.size.y
	var length: float = rect.size.x if along_x else rect.size.y
	var n_spots := maxi(int(length / 1.3), 1)
	for k in range(n_spots):
		var off := -length * 0.5 + (k + 0.5) * (length / n_spots)
		for side in [-1.0, 1.0]:
			var normal := Vector3(0, 0, side) if along_x else Vector3(side, 0, 0)
			var c := rect.get_center()
			var pos := Vector3(c.x + (off if along_x else 0.0), 0.0, c.y + (0.0 if along_x else off))
			pos += normal * ((rect.size.y if along_x else rect.size.x) * 0.5 + 0.9)
			spots.append({"pos": pos, "piece": idx, "normal": normal})


func in_bounds(p: Vector3, margin: float = 0.8) -> bool:
	return absf(p.x) < HALF_X - margin and absf(p.z) < HALF_Z - margin


func clamp_point(p: Vector3, margin: float = 0.8) -> Vector3:
	return Vector3(clampf(p.x, -HALF_X + margin, HALF_X - margin), p.y, clampf(p.z, -HALF_Z + margin, HALF_Z - margin))


## Is the point inside (or hard against) a piece? Used to keep men out of walls.
func blocked(p: Vector3, pad: float = 0.5) -> bool:
	for pc in pieces:
		var r: Rect2 = pc["rect"].grow(pad)
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


## Push a point out of any piece it sits in.
func free_point(p: Vector3, pad: float = 0.6) -> Vector3:
	for pc in pieces:
		var r: Rect2 = pc["rect"].grow(pad)
		if r.has_point(Vector2(p.x, p.z)):
			var c := r.get_center()
			var d := Vector2(p.x, p.z) - c
			if absf(d.x) / r.size.x > absf(d.y) / r.size.y:
				p.x = c.x + signf(d.x if d.x != 0.0 else 1.0) * (r.size.x * 0.5 + 0.05)
			else:
				p.z = c.y + signf(d.y if d.y != 0.0 else 1.0) * (r.size.y * 0.5 + 0.05)
	return clamp_point(p)


## The line of fire from `from` to `to`: 1.0 clear; 0.0 if a tall piece stands in the way;
## otherwise the cover the target gets from a low piece within 2.2 m of him (0.45), or a tall
## piece's edge (0.3) - the shooter aims at what shows above the wall.
func line_of_fire(from: Vector3, to: Vector3) -> float:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var best := 1.0
	for pc in pieces:
		var r: Rect2 = pc["rect"]
		if not _segment_hits_rect(a, b, r):
			continue
		var near_target := _rect_distance(r, b) < 2.2
		if pc["tall"]:
			if near_target:
				best = minf(best, 0.3)
			else:
				return 0.0
		elif near_target:
			best = minf(best, 0.45)
	return best


## Cover spots within `radius` of a point that face the threat, nearest first.
func spots_near(p: Vector3, threat_dir: Vector3, radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in spots:
		var sp: Vector3 = s["pos"]
		if sp.distance_to(p) > radius:
			continue
		# the piece must be between the man and the threat: its normal points away from the threat
		if (s["normal"] as Vector3).dot(threat_dir) > -0.3:
			continue
		out.append(s)
	out.sort_custom(func(x, y): return (x["pos"] as Vector3).distance_squared_to(p) < (y["pos"] as Vector3).distance_squared_to(p))
	return out


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx := maxf(r.position.x - p.x, maxf(0.0, p.x - r.end.x))
	var dy := maxf(r.position.y - p.y, maxf(0.0, p.y - r.end.y))
	return sqrt(dx * dx + dy * dy)


static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	# Liang-Barsky clip
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var p := [-d.x, d.x, -d.y, d.y]
	var q := [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				return false
		else:
			var t: float = q[i] / p[i]
			if p[i] < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
			if t0 > t1:
				return false
	return true


func _static_box(pos: Vector3, size: Vector3, mat: Material, with_mesh: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	if with_mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(size)
		mi.material_override = mat
		body.add_child(mi)
	body.position = pos
	add_child(body)
	return body


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
