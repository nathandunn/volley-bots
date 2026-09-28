extends Node3D
## Entry point. Builds the field, wires the HUD, runs battles; supports a headless batch:
##   godot --headless --path . -- --sim=20 [--red=Regulars --blue=Shock] [--redtype=Marksman]
##         [--size=20] [--seed=1] [--cap=400]
## In the browser the same keys go on the query string: ?red=Shock&blue=Militia&size=12

var manager: MatchManager
var field: Field
var cam: CameraRig
var hud: Hud
var headless := false
var batch_left := 0
var batch_results: Array[Dictionary] = []
var _restart_timer := -1.0
var _base_seed := -1


func _ready() -> void:
	field = Field.new()
	add_child(field)
	_build_lighting()
	manager = MatchManager.new()
	manager.world = self
	manager.field = field
	manager.match_ended.connect(_on_match_ended)
	add_child(manager)

	var args := _parse_args(OS.get_cmdline_user_args())
	headless = (DisplayServer.get_name() == "headless" or args.has("sim")) and not args.has("ui")
	manager.headless = headless
	if args.has("size"):
		var n := clampi(int(args["size"]), 1, MatchManager.MAX_SIZE)
		manager.team_sizes = [n, n]
	if args.has("redsize"):
		manager.team_sizes[0] = clampi(int(args["redsize"]), 1, MatchManager.MAX_SIZE)
	if args.has("bluesize"):
		manager.team_sizes[1] = clampi(int(args["bluesize"]), 1, MatchManager.MAX_SIZE)
	for t in 2:
		var key: String = ["red", "blue"][t]
		if args.has(key):
			manager.team_personalities[t] = Personality.preset(args[key])
			manager.team_preset_names[t] = String(args[key])
		if args.has(key + "type"):
			manager.team_types[t] = SoldierType.preset(args[key + "type"])
			manager.team_type_names[t] = String(args[key + "type"])
	if args.has("seed"):
		_base_seed = int(args["seed"])

	if headless:
		manager.time_limit = float(args.get("cap", "400"))
		set_sim_speed(20.0)
		batch_left = maxi(int(args.get("sim", "5")), 1)
		print("Volley Bots headless sim: %d battles, Red %s/%s (%d) vs Blue %s/%s (%d)" % [batch_left,
			manager.team_preset_names[0], manager.team_type_names[0], manager.team_sizes[0],
			manager.team_preset_names[1], manager.team_type_names[1], manager.team_sizes[1]])
		_start_next()
		return

	_setup_ui_scale()
	cam = CameraRig.new()
	add_child(cam)
	hud = Hud.new()
	add_child(hud)
	hud.setup(manager)
	hud.new_match_requested.connect(func(): batch_left = 0; batch_results.clear(); _start_next())
	hud.batch_requested.connect(_run_batch)
	hud.speed_changed.connect(set_sim_speed)
	hud.pause_toggled.connect(func(p: bool): get_tree().paused = p)
	hud.fit_requested.connect(func(): cam.refit())
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	_start_next()


func _setup_ui_scale() -> void:
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var dpi := DisplayServer.screen_get_dpi()
	root.content_scale_factor = clampf(float(dpi) / 96.0, 1.0, 2.0)


## Speed up game time without coarsening physics: raise the tick rate to match.
func set_sim_speed(s: float) -> void:
	Engine.time_scale = s
	Engine.physics_ticks_per_second = int(round(60.0 * s))
	Engine.max_physics_steps_per_frame = maxi(8, int(s * 4.0))


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = not headless
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.72, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.8)
	e.ambient_light_energy = 0.75
	e.fog_enabled = true
	e.fog_light_color = Color(0.75, 0.8, 0.85)
	e.fog_density = 0.0004
	env.environment = e
	add_child(env)


func _parse_args(list: PackedStringArray) -> Dictionary:
	var d := {}
	for a in list:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if OS.has_feature("web"):
		var q: String = str(JavaScriptBridge.eval("window.location.search", true))
		if q.begins_with("?"):
			for part in q.substr(1).split("&"):
				var kv2: PackedStringArray = String(part).split("=", true, 1)
				if kv2[0] != "":
					d[kv2[0]] = kv2[1].uri_decode() if kv2.size() > 1 else "1"
	return d


func _start_next() -> void:
	_restart_timer = -1.0
	if hud != null:
		hud.on_match_started()
	var s := -1
	if _base_seed >= 0:
		s = _base_seed + manager.match_index
	manager.start_match(s)


func _run_batch(n: int) -> void:
	batch_left = n
	batch_results.clear()
	set_sim_speed(8.0)
	if hud != null:
		hud._set_speed(4.0)
	_start_next()


func _process(delta: float) -> void:
	if _restart_timer > 0.0:
		_restart_timer -= delta
		if _restart_timer <= 0.0:
			_start_next()


func _on_match_ended(result: Dictionary) -> void:
	if batch_left > 0:
		batch_left -= 1
		batch_results.append(result)
		if headless:
			print("  battle %d: %s by %s in %ds (standing %d-%d)" % [result["match"], result["winner_name"], result["reason"], int(result["duration"]), result["alive"][0], result["alive"][1]])
		if batch_left > 0:
			if hud != null:
				hud.set_status("Batch: %d done, %d to go..." % [batch_results.size(), batch_left])
			_restart_timer = 0.05
			return
		var summary := _summarize(batch_results)
		if headless:
			print(summary["text"])
			print("SUMMARY " + JSON.stringify(summary["data"]))
			get_tree().quit()
			return
		hud.show_batch(summary)
		set_sim_speed(1.0)
		hud._set_speed(1.0)
		return
	if hud != null:
		hud.set_status("Battle over - %s" % result["winner_name"])
		get_tree().create_timer(2.0).timeout.connect(func(): hud.show_result(result))
	elif headless:
		print(JSON.stringify(result))


func _summarize(results: Array[Dictionary]) -> Dictionary:
	var wins := [0, 0]
	var draws := 0
	var dur := 0.0
	var keys := ["shots", "hits", "volleys", "charges", "fallbacks", "routed", "friendly", "thrusts", "thrust_hits"]
	var tot := {}
	for k in keys:
		tot[k] = [0, 0]
	var kills := [[0, 0], [0, 0]]
	for r in results:
		if r["winner"] >= 0:
			wins[r["winner"]] += 1
		else:
			draws += 1
		dur += r["duration"]
		var s: Dictionary = r["stats"]
		for t in 2:
			for k in keys:
				tot[k][t] += s[k][t]
			kills[t][0] += s["kills"][t][0]
			kills[t][1] += s["kills"][t][1]
	var n := maxi(results.size(), 1)
	var txt := "Batch of %d: Red (%s/%s) %d wins, Blue (%s/%s) %d wins, %d draws, avg %ds.  " % [
		results.size(), manager.team_preset_names[0], manager.team_type_names[0], wins[0],
		manager.team_preset_names[1], manager.team_type_names[1], wins[1], draws, int(dur / n)]
	for t in 2:
		var acc := float(tot["hits"][t]) / maxf(float(tot["shots"][t]), 1.0) * 100.0
		txt += "%s per battle: %d shots at %d%%, %d volleys, %d charges, %d fall-backs, %d ran; killed %d by ball, %d by bayonet; %d friendly hits.  " % [
			MatchManager.TEAM_NAMES[t], tot["shots"][t] / n, int(acc), tot["volleys"][t] / n, tot["charges"][t] / n,
			tot["fallbacks"][t] / n, tot["routed"][t] / n, kills[t][0] / n, kills[t][1] / n, tot["friendly"][t] / n]
	return {"text": txt, "data": {"matches": results.size(), "wins": wins, "draws": draws, "avg_duration": dur / n,
		"totals": tot, "kills": kills, "presets": manager.team_preset_names.duplicate(), "types": manager.team_type_names.duplicate()}}
