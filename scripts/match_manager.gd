class_name MatchManager
extends Node
## Spawns the two companies, runs the sergeants, keeps the score. The sergeant of a side is
## simply the steadiest man still standing (highest discipline + nerve); what he "orders" is a
## blend of his own traits and the line's, and his men follow it only as far as their own
## traits take them - see soldier.gd.

signal match_started(match_index: int)
signal match_ended(result: Dictionary)

const MAX_SIZE := 20
const TEAM_NAMES := ["Red", "Blue"]
const TEAM_COLORS := [Color(0.8, 0.22, 0.2), Color(0.2, 0.35, 0.8)]
const SERGEANT_TICK := 0.5
const VOLLEY_COOLDOWN := 2.5

static var TEAM_SIZE := 20

var world: Node3D
var field: Field
var headless := false
var team_personalities: Array[Personality] = [Personality.preset("Regulars"), Personality.preset("Skirmishers")]
var team_preset_names: Array[String] = ["Regulars", "Skirmishers"]
var team_types: Array[SoldierType] = [SoldierType.preset("Even"), SoldierType.preset("Even")]
var team_type_names: Array[String] = ["Even", "Even"]
var team_sizes := [TEAM_SIZE, TEAM_SIZE]

var soldiers: Array[Soldier] = []
var orders: Array[Dictionary] = [{}, {}]
var sergeants: Array = [null, null]
var elapsed := 0.0
var time_limit := -1.0
var running := false
var match_index := 0
var rng := RandomNumberGenerator.new()
var stats := {}
var _tick := 0.0
var _spot_claims := {}   # "x,z" -> soldier
var _last_volley_t := [-100.0, -100.0]
var _volley_ids := [0, 0]
var _charge_since := [-1.0, -1.0]
var _fallback_since := [-1.0, -1.0]
var _alive_cache: Array[Soldier] = []
var _cache_frame := -1
var _hist_frame := -1


func home_z(team: int) -> float:
	return -(Field.HALF_Z - 6.0) if team == 0 else (Field.HALF_Z - 6.0)


func start_match(seed_value: int = -1) -> void:
	clear()
	match_index += 1
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	elapsed = 0.0
	stats = _fresh_stats()
	for t in 2:
		var n: int = clampi(int(team_sizes[t]), 1, MAX_SIZE)
		var spacing := 1.0
		var order := _blank_order(t, n)
		order["spacing"] = spacing
		orders[t] = order
		for i in n:
			var s := Soldier.new()
			s.team = t
			s.team_color = TEAM_COLORS[t]
			s.soldier_name = "%s %d" % [TEAM_NAMES[t][0], i + 1]
			s.personality = team_personalities[t].jittered(rng, 0.1)
			s.soldier_type = team_types[t].jittered(rng, 0.02)
			s.manager = self
			s.field = field
			s.slot = i
			s.rng = RandomNumberGenerator.new()
			s.rng.seed = rng.randi()
			var x := (float(i) - float(n - 1) * 0.5) * spacing
			s.position = Vector3(x, 0, home_z(t) + (0.0 if t == 0 else 0.0))
			s.rotation.y = PI if t == 0 else 0.0
			s.fired.connect(_on_fired)
			s.damaged.connect(_on_damaged)
			s.died.connect(_on_died)
			s.routed.connect(_on_routed)
			s.fled.connect(_on_fled)
			s.thrust.connect(_on_thrust)
			world.add_child(s)
			soldiers.append(s)
		# face the enemy
		for s in soldiers:
			if s.team == t:
				s.rotation.y = 0.0 if t == 0 else PI
	running = true
	match_started.emit(match_index)


func _blank_order(t: int, n: int) -> Dictionary:
	return {"mode": "advance", "line_z": home_z(t), "rally_z": home_z(t), "center_x": 0.0, "spacing": 1.0,
		"count": n, "volley_id": 0, "volley_age": 999.0, "alone": false, "sergeant": ""}


func clear() -> void:
	for s in soldiers:
		if is_instance_valid(s):
			if s.ragdoll != null and is_instance_valid(s.ragdoll):
				s.ragdoll.queue_free()
			s.queue_free()
	soldiers.clear()
	_spot_claims.clear()
	_last_volley_t = [-100.0, -100.0]
	_charge_since = [-1.0, -1.0]
	_fallback_since = [-1.0, -1.0]
	running = false
	_cache_frame = -1


func _fresh_stats() -> Dictionary:
	return {
		"shots": [0, 0], "hits": [0, 0], "kills": [[0, 0], [0, 0]],   # kills[t] = [rifle, bayonet]
		"volleys": [0, 0], "charges": [0, 0], "fallbacks": [0, 0], "routed": [0, 0], "fled": [0, 0],
		"friendly": [0, 0], "thrusts": [0, 0], "thrust_hits": [0, 0], "wounds": [0, 0],
	}


# ---------------------------------------------------------------- queries the men use

func alive_soldiers() -> Array[Soldier]:
	var f := Engine.get_physics_frames()
	if f == _cache_frame:
		return _alive_cache
	_cache_frame = f
	_alive_cache = []
	for s in soldiers:
		if s.alive and not s.gone:
			_alive_cache.append(s)
	return _alive_cache


## Men still in the fight: alive, on the field, and not running for the rear.
func fighting(team: int) -> Array[Soldier]:
	var out: Array[Soldier] = []
	for s in alive_soldiers():
		if s.team == team and not s.is_routed:
			out.append(s)
	return out


func alive_count(team: int) -> int:
	var n := 0
	for s in alive_soldiers():
		if s.team == team:
			n += 1
	return n


func loss_fraction(team: int) -> float:
	var n: int = team_sizes[team]
	return 1.0 - float(alive_count(team)) / maxf(float(n), 1.0)


func strength_ratio(team: int) -> float:
	var mine := fighting(team).size()
	var theirs := fighting(1 - team).size()
	return float(mine) / maxf(float(theirs), 1.0)


func nearest_enemy(s: Soldier) -> Soldier:
	var best: Soldier = null
	var best_d := INF
	for o in alive_soldiers():
		if o.team == s.team:
			continue
		var d := o.global_position.distance_squared_to(s.global_position)
		# a man who has broken is a poorer target than one still fighting, unless he is close
		if o.is_routed:
			d *= 1.6
		if d < best_d:
			best_d = d
			best = o
	return best


## A friend standing within a shoulder of the line of fire, closer than the target.
func friend_in_line(s: Soldier, enemy: Soldier) -> Soldier:
	var a := s.global_position
	var b := enemy.global_position
	var ab := b - a
	ab.y = 0.0
	var len := ab.length()
	if len < 0.5:
		return null
	var dir := ab / len
	for o in alive_soldiers():
		if o == s or o.team != s.team:
			continue
		var ao := o.global_position - a
		ao.y = 0.0
		var along := ao.dot(dir)
		if along < 0.6 or along > len - 0.5:
			continue
		var side := (ao - dir * along).length()
		if side < 0.55 and not o.kneeling:
			return o
		if side < 0.3:
			return o
	return null


## The first man - either side - standing near the ball's path beyond the target.
func stray_victim(s: Soldier, from: Vector3, to: Vector3) -> Soldier:
	var dir := to - from
	dir.y = 0.0
	var len := dir.length()
	if len < 0.5:
		return null
	dir /= len
	var best: Soldier = null
	var best_along := INF
	for o in alive_soldiers():
		if o == s:
			continue
		var ao := o.global_position - from
		ao.y = 0.0
		var along := ao.dot(dir)
		if along < len + 0.5 or along > Soldier.MAX_RANGE + 10.0:
			continue
		var side := (ao - dir * along).length()
		if side < 0.7 and along < best_along:
			best_along = along
			best = o
	return best


## Push away from men standing too close (both sides), so a line keeps its interval and a
## melee is a scrum rather than a stack.
func separation(s: Soldier) -> Vector3:
	var push := Vector3.ZERO
	var p := s.global_position
	for o in alive_soldiers():
		if o == s:
			continue
		var d := p - o.global_position
		d.y = 0.0
		var l := d.length()
		if l < 0.75 and l > 0.001:
			push += d / l * (0.75 - l) * 2.5
	return push


## How far this man is ahead (toward the enemy) of the mean of his fighting mates.
func ahead_of_line(s: Soldier) -> float:
	var men := fighting(s.team)
	if men.size() < 2:
		return 0.0
	var z := 0.0
	for m in men:
		z += m.global_position.z
	z /= men.size()
	return (s.global_position.z - z) * signf(-home_z(s.team))


func claim_spot(s: Soldier, spot: Dictionary) -> bool:
	var key := "%.1f,%.1f" % [(spot["pos"] as Vector3).x, (spot["pos"] as Vector3).z]
	var holder = _spot_claims.get(key)
	if holder == null or not is_instance_valid(holder) or not holder.alive or holder.gone or holder == s:
		# drop this man's old claim
		for k in _spot_claims.keys():
			if _spot_claims[k] == s:
				_spot_claims.erase(k)
		_spot_claims[key] = s
		return true
	return false


# ---------------------------------------------------------------- the sergeants

func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	for t in 2:
		orders[t]["volley_age"] = elapsed - _last_volley_t[t]
	_tick -= delta
	if _tick <= 0.0:
		_tick = SERGEANT_TICK
		for t in 2:
			_run_sergeant(t)
	# the fight is over when one side has nobody left standing on the field
	var f0 := fighting(0).size()
	var f1 := fighting(1).size()
	if f0 == 0 and f1 == 0:
		end_match("mutual rout")
	elif f0 == 0:
		end_match("Red broken")
	elif f1 == 0:
		end_match("Blue broken")
	elif time_limit > 0.0 and elapsed >= time_limit:
		end_match("time")


## The line's mind. Traits are the sergeant's own blended half-and-half with his men's mean,
## so a company of cowards with one iron sergeant still holds better than one without him.
func _run_sergeant(t: int) -> void:
	var men := fighting(t)
	var order := orders[t]
	order["count"] = maxi(men.size(), 1)
	order["alone"] = men.size() <= 2
	if men.is_empty():
		return
	# pick the sergeant and hand out slots left-to-right by current x, so the line doesn't cross
	var sgt: Soldier = null
	var best := -1.0
	for m in men:
		var v := m.p("discipline") + m.p("nerve")
		if v > best:
			best = v
			sgt = m
	if sergeants[t] != sgt:
		sergeants[t] = sgt
		order["sergeant"] = sgt.soldier_name
	var sorted := men.duplicate()
	sorted.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	for i in sorted.size():
		sorted[i].slot = i
	var mix := {}
	for tr in Personality.TRAITS:
		var mean := 0.0
		for m in men:
			mean += m.p(tr)
		mean /= men.size()
		mix[tr] = 0.5 * sgt.p(tr) + 0.5 * mean
	var enemies := fighting(1 - t)
	if enemies.is_empty():
		enemies = []
		for s in alive_soldiers():
			if s.team != t:
				enemies.append(s)
	var centre := Vector3.ZERO
	for m in men:
		centre += m.global_position
	centre /= men.size()
	var enemy_centre := Vector3.ZERO
	var nearest_d := INF
	for e in enemies:
		enemy_centre += e.global_position
		nearest_d = minf(nearest_d, e.global_position.distance_to(centre))
	if not enemies.is_empty():
		enemy_centre /= enemies.size()
	var toward := signf(-home_z(t))   # +1 for red (marching +z), -1 for blue
	var loaded_frac := 0.0
	var in_range := 0
	var engage: float = 68.0 - 42.0 * float(mix["patience"])
	for m in men:
		if m.loaded:
			loaded_frac += 1.0
		if not enemies.is_empty() and m.global_position.distance_to(enemy_centre) <= engage:
			in_range += 1
	loaded_frac /= men.size()

	order["spacing"] = 0.8 + (1.0 - mix["cohesion"]) * 3.0
	# the line's centre creeps toward the enemy's, a sergeant with cohesion keeps it together
	order["center_x"] = lerpf(order["center_x"], clampf(enemy_centre.x if not enemies.is_empty() else 0.0, -18.0, 18.0), 0.06)

	var mean_courage := 0.0
	for m in men:
		mean_courage += m.courage
	mean_courage /= men.size()
	var losses := loss_fraction(t)

	# --- mode
	var mode: String = order["mode"]
	if mode == "charge":
		# the charge runs until the enemy is broken off or the blood cools
		if enemies.is_empty() or nearest_d > 40.0 or (elapsed - _charge_since[t] > 25.0 and nearest_d > 6.0):
			mode = "advance"
	elif mode == "fallback":
		var rallied := absf(centre.z - order["rally_z"]) < 6.0
		if rallied and (loaded_frac > 0.6 or elapsed - _fallback_since[t] > 20.0):
			mode = "hold"
	if mode != "charge" and mode != "fallback":
		# fall back: losses or a bad exchange, and a sergeant with the nerve to admit it
		var break_point: float = 0.25 + 0.5 * float(mix["nerve"])
		if losses > break_point and mean_courage < 0.45 and mix["aggression"] < 0.75 and nearest_d < 40.0:
			mode = "fallback"
			order["rally_z"] = clampf(centre.z - toward * 22.0, -Field.HALF_Z + 4.0, Field.HALF_Z - 4.0)
			_fallback_since[t] = elapsed
			stats["fallbacks"][t] += 1
		else:
			# the charge: close enough, and either the volley is just gone or the fight is going our way
			var charge_range: float = 12.0 + 32.0 * float(mix["aggression"])
			var just_volleyed: bool = elapsed - float(_last_volley_t[t]) < 4.0
			var ratio := strength_ratio(t)
			if not enemies.is_empty() and nearest_d < charge_range and mix["aggression"] > 0.35 \
				and (just_volleyed or loaded_frac < 0.35 or mix["aggression"] > 0.85) \
				and ratio > 0.5 + (1.0 - mix["aggression"]) * 0.6:
				mode = "charge"
				_charge_since[t] = elapsed
				stats["charges"][t] += 1
			elif not enemies.is_empty() and nearest_d <= engage:
				mode = "hold"
			else:
				mode = "advance"
	order["mode"] = mode
	if mode == "charge":
		# a line coming on with the bayonet is a fearful thing before it ever arrives
		for e in enemies:
			var close := 0
			for m in men:
				if m.charging and m.global_position.distance_to(e.global_position) < 15.0:
					close += 1
			if close >= 3:
				e.fear = minf(e.fear + 0.03 * (1.0 - 0.5 * e.p("nerve")), 0.6)

	# --- where the line stands
	match mode:
		"advance":
			var step: float = 1.4 * SERGEANT_TICK * (0.6 + 0.8 * float(mix["aggression"]))
			var target_z: float = order["line_z"] + toward * step
			# a cover-minded sergeant halts the line on a wall he can reach before the enemy does
			if mix["cover"] > 0.45:
				var wall_z := _cover_row_ahead(t, order["line_z"], engage, enemy_centre)
				if not is_nan(wall_z) and (target_z - wall_z) * toward > 0.0:
					target_z = wall_z
			order["line_z"] = clampf(target_z, -Field.HALF_Z + 3.0, Field.HALF_Z - 3.0)
		"hold":
			# keep the range: if the enemy pulls back out of reach, follow at the walk
			if not enemies.is_empty() and nearest_d > engage + 8.0:
				order["line_z"] += toward * 1.0 * SERGEANT_TICK
			# ... and a hot-blooded sergeant still edges in
			elif mix["aggression"] > 0.6 and nearest_d > 20.0:
				order["line_z"] += toward * 0.5 * SERGEANT_TICK
		"fallback":
			order["line_z"] = order["rally_z"]
		"charge":
			order["line_z"] = centre.z

	# --- the volley: enough men loaded and in range, and it's been a moment since the last
	if mode != "charge" and mode != "fallback" and not enemies.is_empty():
		var ready := 0
		for m in men:
			if m.loaded and m.global_position.distance_to(enemy_centre) <= engage + 10.0:
				ready += 1
		var need: float = 0.45 + 0.4 * float(mix["discipline"])
		if float(ready) / men.size() >= need and elapsed - _last_volley_t[t] > VOLLEY_COOLDOWN + 4.0 * mix["patience"]:
			_call_volley(t)
		elif mix["discipline"] < 0.35:
			order["mode"] = "at_will" if mode == "hold" else mode


## The z of the nearest low wall or fence row between the line and the engagement distance,
## on the near side of it; NAN if there is none.
func _cover_row_ahead(t: int, line_z: float, engage: float, enemy_centre: Vector3) -> float:
	var toward := signf(-home_z(t))
	var best := NAN
	var best_d := INF
	for pc in field.pieces:
		if pc["tall"]:
			continue
		var r: Rect2 = pc["rect"]
		if r.size.x < 4.0:
			continue   # only long rows can hold a line
		var z := r.get_center().y - toward * (r.size.y * 0.5 + 0.9)
		var ahead := (z - line_z) * toward
		if ahead < -1.0:
			continue
		if absf(enemy_centre.z - z) < 12.0:
			continue   # the enemy is already on it
		if absf(enemy_centre.z - z) > engage + 6.0:
			continue   # too far back to fire from; the line would stand there for nothing
		if ahead < best_d:
			best_d = ahead
			best = z
	return best


func _call_volley(t: int) -> void:
	_last_volley_t[t] = elapsed
	_volley_ids[t] += 1
	orders[t]["volley_id"] = _volley_ids[t]
	orders[t]["volley_age"] = 0.0
	stats["volleys"][t] += 1


# ---------------------------------------------------------------- events

## The shock of a volley: balls arriving together frighten the men around the mark, hit or
## miss, far more than the same balls one at a time. Only shots fired on the word count.
func volley_pressure(shooter: Soldier, mark: Vector3, hit: bool) -> void:
	var o: Dictionary = orders[shooter.team]
	if float(o.get("volley_age", 999.0)) > 1.2:
		return
	for s in alive_soldiers():
		if s.team == shooter.team:
			continue
		var d := s.global_position.distance_to(mark)
		if d < 5.0:
			s.fear = minf(s.fear + (0.05 if hit else 0.025) * (1.0 - d / 5.0) + 0.01, 0.6)


func _on_fired(s: Soldier, victim: Soldier, hit: bool) -> void:
	stats["shots"][s.team] += 1
	if hit and victim.team != s.team:
		stats["hits"][s.team] += 1
	elif hit:
		stats["friendly"][s.team] += 1


func _on_damaged(s: Soldier, amount: float, _source: String, _attacker: Soldier) -> void:
	if amount < Soldier.MAX_HP and s.alive:
		stats["wounds"][s.team] += 1


func _on_died(s: Soldier, source: String, attacker: Soldier) -> void:
	if attacker != null and attacker.team != s.team:
		stats["kills"][attacker.team][1 if source == "bayonet" else 0] += 1
	for o in alive_soldiers():
		if o.team == s.team:
			o.notice_death(s.global_position)
	for k in _spot_claims.keys():
		if _spot_claims[k] == s:
			_spot_claims.erase(k)


func _on_routed(s: Soldier) -> void:
	stats["routed"][s.team] += 1


func _on_fled(s: Soldier) -> void:
	stats["fled"][s.team] += 1


func _on_thrust(s: Soldier, landed: bool) -> void:
	stats["thrusts"][s.team] += 1
	if landed:
		stats["thrust_hits"][s.team] += 1


func end_match(reason: String) -> void:
	if not running:
		return
	running = false
	var f := [fighting(0).size(), fighting(1).size()]
	var a := [alive_count(0), alive_count(1)]
	var winner := -1
	if f[0] > 0 and f[1] == 0:
		winner = 0
	elif f[1] > 0 and f[0] == 0:
		winner = 1
	elif reason == "time":
		# on the clock, the side that has done more harm
		var s0: int = stats["kills"][0][0] + stats["kills"][0][1]
		var s1: int = stats["kills"][1][0] + stats["kills"][1][1]
		if s0 != s1:
			winner = 0 if s0 > s1 else 1
	var per := []
	for s in soldiers:
		per.append({"name": s.soldier_name, "team": s.team, "alive": s.alive, "routed": s.is_routed, "gone": s.gone,
			"shots": s.shots, "hits": s.hits, "kills": s.kills, "bayonet_kills": s.bayonet_kills,
			"thrusts": s.thrusts, "thrust_hits": s.thrust_hits, "dmg": s.dmg_done, "hp": s.hp,
			"persona": s.personality.label(), "type": s.soldier_type.label()})
	var result := {"match": match_index, "winner": winner, "winner_name": TEAM_NAMES[winner] if winner >= 0 else "Draw",
		"reason": reason, "duration": elapsed, "alive": a, "fighting": f, "stats": stats.duplicate(true),
		"sizes": team_sizes.duplicate(), "soldiers": per,
		"presets": team_preset_names.duplicate(), "types": team_type_names.duplicate()}
	match_ended.emit(result)
