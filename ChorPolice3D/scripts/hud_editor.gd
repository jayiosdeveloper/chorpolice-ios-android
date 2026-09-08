## HudEditor — "Customize buttons": drag every game button where your thumbs like it,
## pick a button size, RESET to defaults, DONE saves. Opened from Settings → Controls.
extends Control

var buttons := {}                  # kind -> Control
var selected := "fire"
var size_btns := {}
var size_label: Label
var drag_kind := ""
var drag_id := -1
var drag_off := Vector2.ZERO
var status: Label

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	add_child(UI.full_rect(UI.grad_tex([Color(0.05, 0.07, 0.14), Color(0.03, 0.04, 0.09)])))

	# zones: move (stick side) and look (other side)
	var left_is_move := not Settings.left_handed
	_zone(Rect2(0, 0, vp.x / 2.0, vp.y) if left_is_move else Rect2(vp.x / 2.0, 0, vp.x / 2.0, vp.y),
		"MOVE STICK ZONE", "touch anywhere here to move", UI.GREEN)
	_zone(Rect2(vp.x / 2.0, 0, vp.x / 2.0, vp.y) if left_is_move else Rect2(0, 0, vp.x / 2.0, vp.y),
		"LOOK ZONE", "drag here to aim the camera", UI.CYAN)
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.12)
	mid.position = Vector2(vp.x / 2.0 - 1, 0)
	mid.size = Vector2(2, vp.y)
	add_child(mid)
	var cross := Shapes.circ(3.5, Color(1, 1, 1, 0.8))
	cross.position = vp / 2.0
	add_child(cross)

	# top bar
	var bar := PanelContainer.new()
	bar.anchor_right = 1.0
	bar.offset_left = 20; bar.offset_right = -20; bar.offset_top = 12
	var sb := UI.glass(0.08, 16.0)
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	bar.add_child(h)
	h.add_child(UI.label("HUD LAYOUT", 20, UI.TEXT))
	var tip := UI.label("Drag the buttons where your thumbs rest", 13, UI.MUTED)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tip)
	size_label = UI.label("SIZE: FIRE", 12, UI.CYAN)
	size_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(size_label)
	for opt in [["S", 0.75], ["M", 1.0], ["L", 1.3], ["XL", 1.6]]:
		var b := Button.new()
		b.text = opt[0]
		b.custom_minimum_size = Vector2(42, 40)
		UI.style_button(b, "ghost", 12.0)
		b.pressed.connect(_resize.bind(float(opt[1])))
		size_btns[opt[1]] = b
		h.add_child(b)
	var reset := Button.new()
	reset.text = "RESET"
	reset.custom_minimum_size = Vector2(100, 40)
	UI.style_button(reset, "dark", 12.0)
	reset.pressed.connect(func() -> void:
		Settings.hud_layout = {}
		Settings.hud_size = {}
		Settings.hud_scale = 1.0
		Settings.save_cfg()
		get_tree().reload_current_scene())
	h.add_child(reset)
	var done := Button.new()
	done.text = "DONE"
	done.custom_minimum_size = Vector2(110, 40)
	UI.style_button(done, "primary", 12.0)
	done.pressed.connect(func() -> void:
		Settings.save_cfg()
		get_tree().change_scene_to_file("res://scenes/Settings.tscn"))
	h.add_child(done)

	for kind in HudKit.KINDS:
		var c := HudKit.make(kind, Settings.hud_scale * Settings.hud_size_of(kind))
		add_child(c)
		HudKit.place(c, Settings.hud_center(kind, vp))
		buttons[kind] = c
		# name tag under each button
		var tag := UI.label(HudKit.NAMES[kind], 10, UI.CYAN, false, HORIZONTAL_ALIGNMENT_CENTER)
		tag.name = "tag"
		tag.anchor_right = 1.0
		tag.offset_top = c.size.y + 2
		c.add_child(tag)

	_select("fire")
	status = UI.label("Tap a button to select it, drag to move it, then pick a size", 13, UI.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	status.anchor_right = 1.0
	status.anchor_top = 1.0; status.anchor_bottom = 1.0
	status.offset_top = -30
	add_child(status)

	if OS.has_environment("CP_HUDSHOT"):
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("CP_HUDSHOT"))
		get_tree().quit()

## Highlights the selected button + syncs the S/M/L active state.
func _select(kind: String) -> void:
	selected = kind
	if size_label:
		size_label.text = "SIZE: %s" % HudKit.NAMES[kind].to_upper()
	var cur := Settings.hud_size_of(kind)
	for v in size_btns:
		UI.style_button(size_btns[v], "blue" if is_equal_approx(cur, float(v)) else "ghost", 12.0)
	for k in buttons:
		var tag: Node = buttons[k].get_node_or_null("tag")
		if tag:
			tag.modulate = Color(1, 0.8, 0.2) if k == kind else UI.CYAN

func _resize(factor: float) -> void:
	Settings.set_hud_size(selected, factor)
	Settings.save_cfg()
	_rebuild_button(selected)
	_select(selected)
	if status:
		status.text = "%s size set" % HudKit.NAMES[selected]

func _rebuild_button(kind: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	var center := Settings.hud_center(kind, vp)
	buttons[kind].queue_free()
	var c := HudKit.make(kind, Settings.hud_scale * Settings.hud_size_of(kind))
	add_child(c)
	HudKit.place(c, center)
	buttons[kind] = c
	var tag := UI.label(HudKit.NAMES[kind], 10, UI.CYAN, false, HORIZONTAL_ALIGNMENT_CENTER)
	tag.name = "tag"
	tag.anchor_right = 1.0
	tag.offset_top = c.size.y + 2
	c.add_child(tag)

func _zone(r: Rect2, title: String, sub: String, col: Color) -> void:
	var z := ColorRect.new()
	z.color = Color(col.r, col.g, col.b, 0.05)
	z.position = r.position
	z.size = r.size
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(z)
	var t := UI.label(title, 14, Color(col.r, col.g, col.b, 0.8), false, HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(r.position.x, r.position.y + r.size.y * 0.42)
	t.size = Vector2(r.size.x, 20)
	add_child(t)
	var s := UI.label(sub, 12, Color(1, 1, 1, 0.35), false, HORIZONTAL_ALIGNMENT_CENTER)
	s.position = Vector2(r.position.x, r.position.y + r.size.y * 0.42 + 22)
	s.size = Vector2(r.size.x, 20)
	add_child(s)

func _hit(p: Vector2) -> String:
	# smallest button first so overlapping ones stay pickable
	var best := ""
	var best_area := 1.0e12
	for kind in buttons:
		var c: Control = buttons[kind]
		var r := HudKit.rect(c, 8.0)
		if r.has_point(p) and r.get_area() < best_area:
			best_area = r.get_area()
			best = kind
	return best

func _input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var moved := false
	var pos := Vector2.ZERO
	var idx := 0
	if event is InputEventScreenTouch:
		pressed = event.pressed; released = not event.pressed; pos = event.position; idx = event.index
	elif event is InputEventScreenDrag:
		moved = true; pos = event.position; idx = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed; released = not event.pressed; pos = event.position; idx = 100
	elif event is InputEventMouseMotion:
		moved = true; pos = event.position; idx = 100
	else:
		return
	if pressed and drag_kind == "":
		var k := _hit(pos)
		if k != "":
			drag_kind = k
			drag_id = idx
			_select(k)
			var c: Control = buttons[k]
			drag_off = c.position + c.size * c.scale / 2.0 - pos
			status.text = "Moving %s" % HudKit.NAMES[k]
	elif moved and drag_kind != "" and idx == drag_id:
		var c: Control = buttons[drag_kind]
		var vp := get_viewport().get_visible_rect().size
		var half := c.size * c.scale / 2.0
		var center := pos + drag_off
		center.x = clampf(center.x, half.x + 4.0, vp.x - half.x - 4.0)
		center.y = clampf(center.y, half.y + 70.0, vp.y - half.y - 4.0)
		HudKit.place(c, center)
	elif released and drag_kind != "" and idx == drag_id:
		var c: Control = buttons[drag_kind]
		var vp := get_viewport().get_visible_rect().size
		Settings.set_hud_center(drag_kind, c.position + c.size * c.scale / 2.0, vp)
		Settings.save_cfg()
		status.text = "%s saved" % HudKit.NAMES[drag_kind]
		drag_kind = ""
		drag_id = -1
