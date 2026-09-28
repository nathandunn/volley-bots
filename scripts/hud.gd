class_name Hud
extends CanvasLayer
## Controls, the company builder and the results, all built in code and sized for a phone.

signal new_match_requested
signal batch_requested(n: int)
signal speed_changed(scale: float)
signal pause_toggled(paused: bool)
signal fit_requested

const PRESET_LIST := ["Regulars", "Skirmishers", "Shock", "Militia", "Veterans", "Balanced", "Random"]
const TYPE_LIST := ["Even", "Marksman", "Grenadier", "Runner", "Ironside", "Random"]
const BATCH_N := 10

var manager: MatchManager
var status_label: Label
var team_labels: Array[Label] = []
var teams_overlay: Control
var results_overlay: Control
var results_box: VBoxContainer
var results_title: Label
var speed_buttons: Array[Button] = []
var pause_btn: Button
var size_labels: Array[Label] = []
var persona_sliders := [{}, {}]
var persona_vals := [{}, {}]
var type_sliders := [{}, {}]
var type_vals := [{}, {}]
var persona_pick: Array[OptionButton] = []
var type_pick: Array[OptionButton] = []
var _updating := false
var _tick := 0.0
var _root: Control
var _paused := false


func setup(m: MatchManager) -> void:
	manager = m
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 44   # under the back-to-apps pill
	top.offset_left = 8
	top.offset_right = -8
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var row := HFlowContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var teams_btn := _button("Companies")
	teams_btn.pressed.connect(func(): _close_overlays(); teams_overlay.visible = true)
	row.add_child(teams_btn)
	var fight := _button("New battle")
	fight.pressed.connect(func(): _close_overlays(); new_match_requested.emit())
	row.add_child(fight)
	for s in [1.0, 2.0, 4.0]:
		var b := _button("%d×" % int(s))
		b.toggle_mode = true
		b.pressed.connect(func(): _set_speed(s); speed_changed.emit(s))
		speed_buttons.append(b)
		row.add_child(b)
	speed_buttons[0].button_pressed = true
	pause_btn = _button("Pause")
	pause_btn.pressed.connect(func():
		_paused = not _paused
		pause_btn.text = "Resume" if _paused else "Pause"
		pause_toggled.emit(_paused))
	row.add_child(pause_btn)
	var fit := _button("Fit view")
	fit.pressed.connect(func(): fit_requested.emit())
	row.add_child(fit)
	var batch := _button("Sim ×%d" % BATCH_N)
	batch.pressed.connect(func(): _close_overlays(); batch_requested.emit(BATCH_N))
	row.add_child(batch)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("shadow_offset_x", 1)
	status_label.add_theme_constant_override("shadow_offset_y", 1)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(status_label)
	for t in 2:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", MatchManager.TEAM_COLORS[t].lightened(0.35))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(l)
		team_labels.append(l)

	_build_teams_overlay()
	_build_results_overlay()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 15)
	return b


func _overlay(title_text: String) -> Array:
	var ov := PanelContainer.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.offset_top = 40
	ov.offset_left = 6
	ov.offset_right = -6
	ov.offset_bottom = -6
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	ov.add_theme_stylebox_override("panel", sb)
	ov.visible = false
	_root.add_child(ov)
	var vb := VBoxContainer.new()
	ov.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("Close")
	close.pressed.connect(func(): ov.visible = false)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return [ov, box, title]


func _build_teams_overlay() -> void:
	var parts := _overlay("Companies - takes effect at the next battle")
	teams_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	var note := Label.new()
	note.text = "Nobody takes orders. Pick what the men are (four properties that share one budget) and who they are (six traits); formation, cover, volleys, charges and retreats all come out of that."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))
	box.add_child(note)
	var cols := HFlowContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(cols)
	for t in 2:
		cols.add_child(_build_team_panel(t))


func _build_team_panel(t: int) -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := Label.new()
	name_l.text = "%s company" % MatchManager.TEAM_NAMES[t]
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", MatchManager.TEAM_COLORS[t].lightened(0.35))
	panel.add_child(name_l)

	# size
	var size_row := HBoxContainer.new()
	panel.add_child(size_row)
	var sl := Label.new()
	sl.text = "Men: %d" % int(manager.team_sizes[t])
	sl.custom_minimum_size = Vector2(90, 0)
	size_row.add_child(sl)
	size_labels.append(sl)
	var size_slider := HSlider.new()
	size_slider.min_value = 1
	size_slider.max_value = MatchManager.MAX_SIZE
	size_slider.step = 1
	size_slider.value = int(manager.team_sizes[t])
	size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_slider.custom_minimum_size = Vector2(0, 32)
	size_slider.value_changed.connect(func(v: float): manager.team_sizes[t] = int(v); sl.text = "Men: %d" % int(v))
	size_row.add_child(size_slider)

	# type
	var tl := Label.new()
	tl.text = "Type (the four share one budget)"
	tl.add_theme_font_size_override("font_size", 15)
	panel.add_child(tl)
	var tp := OptionButton.new()
	tp.custom_minimum_size = Vector2(0, 38)
	for n in TYPE_LIST:
		tp.add_item(n)
	tp.add_item("Custom")
	tp.select(maxi(TYPE_LIST.find(manager.team_type_names[t]), 0))
	tp.item_selected.connect(func(i: int): _on_type(t, tp.get_item_text(i)))
	panel.add_child(tp)
	type_pick.append(tp)
	var thelp := Label.new()
	thelp.name = "TypeHelp"
	thelp.text = SoldierType.TYPE_HELP.get(manager.team_type_names[t], "")
	thelp.add_theme_font_size_override("font_size", 12)
	thelp.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	thelp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(thelp)
	for p in SoldierType.PROPS:
		panel.add_child(_slider_row(t, p, SoldierType.PROP_HELP[p], true))

	# personality
	var pl := Label.new()
	pl.text = "Personality"
	pl.add_theme_font_size_override("font_size", 15)
	panel.add_child(pl)
	var pp := OptionButton.new()
	pp.custom_minimum_size = Vector2(0, 38)
	for n in PRESET_LIST:
		pp.add_item(n)
	pp.add_item("Custom")
	pp.select(maxi(PRESET_LIST.find(manager.team_preset_names[t]), 0))
	pp.item_selected.connect(func(i: int): _on_preset(t, pp.get_item_text(i)))
	panel.add_child(pp)
	persona_pick.append(pp)
	var phelp := Label.new()
	phelp.name = "PersonaHelp"
	phelp.text = Personality.PRESET_HELP.get(manager.team_preset_names[t], "")
	phelp.add_theme_font_size_override("font_size", 12)
	phelp.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	phelp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(phelp)
	for tr in Personality.TRAITS:
		panel.add_child(_slider_row(t, tr, Personality.TRAIT_HELP[tr], false))
	panel.set_meta("type_help", thelp)
	panel.set_meta("persona_help", phelp)
	panel.set_meta("team", t)
	_refresh_sliders(t)
	return panel


func _slider_row(t: int, key: String, help: String, is_type: bool) -> Control:
	var vb := VBoxContainer.new()
	var row := HBoxContainer.new()
	vb.add_child(row)
	var l := Label.new()
	l.text = key.capitalize()
	l.custom_minimum_size = Vector2(96, 0)
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0 if not is_type else 0.85
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 30)
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(44, 0)
	v.add_theme_font_size_override("font_size", 13)
	row.add_child(v)
	var h := Label.new()
	h.text = help
	h.add_theme_font_size_override("font_size", 11)
	h.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(h)
	if is_type:
		type_sliders[t][key] = s
		type_vals[t][key] = v
		s.value_changed.connect(func(val: float): _on_type_slider(t, key, val))
	else:
		persona_sliders[t][key] = s
		persona_vals[t][key] = v
		s.value_changed.connect(func(val: float): _on_slider(t, key, val))
	return vb


func _on_preset(t: int, preset_name: String) -> void:
	if preset_name == "Custom":
		return
	manager.team_personalities[t] = Personality.preset(preset_name)
	manager.team_preset_names[t] = preset_name
	_refresh_sliders(t)


func _on_slider(t: int, trait_name: String, v: float) -> void:
	if _updating:
		return
	manager.team_personalities[t].set_trait(trait_name, v)
	manager.team_preset_names[t] = manager.team_personalities[t].label()
	_refresh_sliders(t)


func _on_type(t: int, preset_name: String) -> void:
	if preset_name == "Custom":
		return
	manager.team_types[t] = SoldierType.preset(preset_name)
	manager.team_type_names[t] = preset_name
	_refresh_sliders(t)


func _on_type_slider(t: int, prop: String, v: float) -> void:
	if _updating:
		return
	manager.team_types[t].set_and_rebalance(prop, v)
	manager.team_type_names[t] = manager.team_types[t].label()
	_refresh_sliders(t)


func _refresh_sliders(t: int) -> void:
	_updating = true
	for tr in Personality.TRAITS:
		if persona_sliders[t].has(tr):
			persona_sliders[t][tr].value = manager.team_personalities[t].get_trait(tr)
			persona_vals[t][tr].text = "%.2f" % manager.team_personalities[t].get_trait(tr)
	for p in SoldierType.PROPS:
		if type_sliders[t].has(p):
			type_sliders[t][p].value = manager.team_types[t].get_prop(p)
			type_vals[t][p].text = "%.2f" % manager.team_types[t].get_prop(p)
	if persona_pick.size() > t:
		var pn: String = manager.team_preset_names[t]
		var idx := PRESET_LIST.find(pn)
		persona_pick[t].select(idx if idx >= 0 else PRESET_LIST.size())
		type_pick[t].select(maxi(TYPE_LIST.find(manager.team_type_names[t]), 0) if TYPE_LIST.has(manager.team_type_names[t]) else TYPE_LIST.size())
		var panel := persona_pick[t].get_parent()
		if panel.has_meta("persona_help"):
			(panel.get_meta("persona_help") as Label).text = Personality.PRESET_HELP.get(pn, "Custom blend")
			(panel.get_meta("type_help") as Label).text = SoldierType.TYPE_HELP.get(manager.team_type_names[t], "Custom build")
	_updating = false


func _build_results_overlay() -> void:
	var parts := _overlay("Result")
	results_overlay = parts[0]
	results_box = parts[1]
	results_title = parts[2]


func _close_overlays() -> void:
	teams_overlay.visible = false
	results_overlay.visible = false


func on_match_started() -> void:
	_close_overlays()
	set_status("The lines are drawn.")


func _set_speed(s: float) -> void:
	for i in speed_buttons.size():
		speed_buttons[i].button_pressed = is_equal_approx([1.0, 2.0, 4.0][i], s)


func set_status(text: String) -> void:
	status_label.text = text


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or manager == null:
		return
	_tick = 0.25
	for t in 2:
		var o: Dictionary = manager.orders[t]
		if o.is_empty():
			continue
		var st: Dictionary = manager.stats
		var fighting := manager.fighting(t).size()
		var alive := manager.alive_count(t)
		var mode: String = o.get("mode", "")
		var sgt: String = o.get("sergeant", "")
		team_labels[t].text = "%s: %d standing (%d in line) · %s · volleys %d · shots %d/%d · %s leads" % [
			MatchManager.TEAM_NAMES[t], alive, fighting, mode.replace("_", " "), st["volleys"][t], st["hits"][t], st["shots"][t], sgt]
	if manager.running:
		status_label.text = "%d:%02d" % [int(manager.elapsed) / 60, int(manager.elapsed) % 60]


func show_result(res: Dictionary) -> void:
	for c in results_box.get_children():
		c.queue_free()
	results_title.text = "%s - %s (%d:%02d)" % [
		("%s wins" % res["winner_name"]) if res["winner"] >= 0 else "Draw", res["reason"], int(res["duration"]) / 60, int(res["duration"]) % 60]
	var st: Dictionary = res["stats"]
	for t in 2:
		var l := Label.new()
		var acc := float(st["hits"][t]) / maxf(float(st["shots"][t]), 1.0) * 100.0
		var tacc := float(st["thrust_hits"][t]) / maxf(float(st["thrusts"][t]), 1.0) * 100.0
		l.text = "%s (%s, %s): %d of %d standing, %d ran. Shots %d, hits %d (%d%%), friendly hits %d. Volleys %d, charges %d, fall-backs %d. Killed by ball %d, by bayonet %d (%d thrusts, %d%% landed)." % [
			MatchManager.TEAM_NAMES[t], res["presets"][t], res["types"][t], res["alive"][t], res["sizes"][t], st["routed"][t],
			st["shots"][t], st["hits"][t], int(acc), st["friendly"][t], st["volleys"][t], st["charges"][t], st["fallbacks"][t],
			st["kills"][t][0], st["kills"][t][1], st["thrusts"][t], int(tacc)]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", MatchManager.TEAM_COLORS[t].lightened(0.4))
		results_box.add_child(l)
	# the men, best first
	var men: Array = res["soldiers"].duplicate()
	men.sort_custom(func(a, b): return a["kills"] > b["kills"] or (a["kills"] == b["kills"] and a["hits"] > b["hits"]))
	var shown := 0
	for m in men:
		if shown >= 12:
			break
		if m["kills"] == 0 and m["hits"] == 0:
			continue
		var l := Label.new()
		l.text = "  %s: %d kills (%d bayonet), %d/%d shots hit%s" % [m["name"], m["kills"], m["bayonet_kills"], m["hits"], m["shots"],
			"" if m["alive"] else " - fell", ]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", MatchManager.TEAM_COLORS[m["team"]].lightened(0.5))
		results_box.add_child(l)
		shown += 1
	var row := HFlowContainer.new()
	results_box.add_child(row)
	var again := _button("Next battle")
	again.pressed.connect(func(): _close_overlays(); new_match_requested.emit())
	row.add_child(again)
	var teams := _button("Companies")
	teams.pressed.connect(func(): _close_overlays(); teams_overlay.visible = true)
	row.add_child(teams)
	results_overlay.visible = true


func show_batch(summary: Dictionary) -> void:
	for c in results_box.get_children():
		c.queue_free()
	results_title.text = "Batch of %d" % summary["data"]["matches"]
	var l := Label.new()
	l.text = summary["text"]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_box.add_child(l)
	var row := HFlowContainer.new()
	results_box.add_child(row)
	var again := _button("New battle")
	again.pressed.connect(func(): _close_overlays(); new_match_requested.emit())
	row.add_child(again)
	var teams := _button("Companies")
	teams.pressed.connect(func(): _close_overlays(); teams_overlay.visible = true)
	row.add_child(teams)
	results_overlay.visible = true
