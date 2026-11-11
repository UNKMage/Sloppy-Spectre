extends Control
## The kit in a game's HUD: hearts, health, mana and stamina bars, a boss bar, a party panel of
## plain ProgressBars under a style's Theme, status columns, two orbs, cooldown rings and a
## segmented XP bar, over a torch-lit dungeon with the enemies under their bars. The buttons hit,
## heal and cast; the row under them swaps the frame style; ? shows again the card it opens with,
## saying how to use it.

const KIT := "res://addons/pixel_bars/"
const ALL_STYLES: Array[String] = ["wood", "stone", "sky", "forest", "royal", "ember", "gilded", "cyan"]
const ALL_FILLS: Array[String] = ["health", "mana", "stamina", "xp", "shield", "rage", "magic", "poison"]
const ART_HEIGHT := 240.0
const COOLDOWN := 2.5  # seconds a ring takes to refill
const HELP: Array[String] = [
	"Hit, Heal and Cast spend and refill the hero's hearts, bars and orbs; Strike boss hits the boss and the enemies.",
	"The row of names under them changes the frame style.",
	"Arrow keys or a pad move, Enter picks; or use the mouse.",
	"? brings this card back.",
]

## Store capture only: plays hits, heals and casts by itself, and swaps the style every
## `auto_style_frames` frames (0: never).
@export var auto := false
@export var auto_style_frames := 0

var style := "wood"
var bars: Array[PixelBar] = []
var style_buttons := {}
var party: Control
var hearts: PixelHearts
var hp: PixelBar
var mp: PixelBar
var stamina: PixelBar
var boss: PixelBar
var hp_orb: PixelBar
var mp_orb: PixelBar
var rings: Array[PixelBar] = []
var mobs: Array[PixelBar] = []
var xp: PixelBar
var frame := 0
var foes: Array[Mob] = []
var help: Control


## Draws at a whole-number scale so the art pixels stay square: the largest that still fits
## `art_height` pixels of art on screen.
static func pixel_scale(node: Node, art_height: float) -> void:
	var window := node.get_tree().root
	window.content_scale_factor = 1.0
	window.content_scale_factor = maxf(1.0, floorf(window.get_visible_rect().size.y / art_height))


static func installed(folder: String, names: Array[String]) -> Array[String]:
	return names.filter(func(n: String) -> bool: return DirAccess.dir_exists_absolute(KIT + folder + n))


static func styles() -> Array[String]:
	return installed("frames/", ALL_STYLES)


static func fills() -> Array[String]:
	return installed("fills/", ALL_FILLS)


## The fill if the kit has it, else the first it has: the free sampler has three.
static func some_fill(name: String) -> String:
	return name if name in fills() else fills()[0]


static func bar(parent: Control, shape: PixelBar.Shape, fill: String, at: Vector2, length := 0.0, value := 100.0) -> PixelBar:
	var b := PixelBar.new()
	b.shape = shape
	b.fill = some_fill(fill)
	b.position = at
	if length > 0.0:
		b.custom_minimum_size = Vector2(12, length) if shape == PixelBar.Shape.VERTICAL else Vector2(length, {PixelBar.Shape.THIN: 7, PixelBar.Shape.BOSS: 16}.get(shape, 12))
	b.value = value
	parent.add_child(b)
	b.settle()
	return b


static func label(parent: Control, text: String, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	parent.add_child(l)
	return l


## The style's Theme: its ProgressBars, and the pixel font; plus buttons cut from its frame.
static func style_theme(name: String) -> Theme:
	var t: Theme = load(KIT + "themes/%s.tres" % name).duplicate()
	for state in [["normal", 1.0], ["hover", 1.25], ["pressed", 0.8], ["focus", 1.0]]:
		var sb := StyleBoxTexture.new()
		sb.texture = load(KIT + "frames/%s/bar.png" % name)
		sb.set_texture_margin_all(4)
		sb.set_content_margin_all(4)
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		sb.modulate_color = Color(state[1], state[1], state[1])
		if state[0] == "focus":
			sb.draw_center = false
			sb.modulate_color = Color(2.2, 2.2, 2.2)  # the frame drawn again, bright, over the button
		t.set_stylebox(state[0], "Button", sb)
	var card := StyleBoxTexture.new()  # the help card's
	card.texture = load(KIT + "frames/%s/bar.png" % name)
	card.set_texture_margin_all(4)
	card.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", card)
	return t


func _ready() -> void:
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST  # project.godot's, for a project without it
	pixel_scale(self, ART_HEIGHT)
	var width := get_viewport_rect().size.x
	style = styles()[0]
	theme = style_theme(style)
	add_child(Arena.new())
	_player()
	_boss(width)
	_party(width)
	_status()
	_mobs(width)
	_bottom(width)
	_buttons(width)
	help = _help()
	show_help(Engine.get_write_movie_path() == "" and not auto)  # the store's shots go without it


func _player() -> void:
	hearts = PixelHearts.new()
	hearts.max_value = 20
	hearts.value = 14
	hearts.position = Vector2(6, 6)
	add_child(hearts)
	hp = bar(self, PixelBar.Shape.BAR, "health", Vector2(6, 26), 100, 80)
	hp.low = 0.3
	mp = bar(self, PixelBar.Shape.BAR, "mana", Vector2(6, 40), 80, 65)
	stamina = bar(self, PixelBar.Shape.THIN, "stamina", Vector2(6, 54), 64, 100)
	bars.append_array([hp, mp, stamina])


func _boss(width: float) -> void:
	boss = bar(self, PixelBar.Shape.BOSS, "health", Vector2(roundf(width / 2 - 89), 8), 176, 90)
	boss.segments = 4
	bars.append(boss)
	var name_label := label(self, "THE HOLLOW KING", Vector2.ZERO)
	name_label.position = Vector2(roundf(width / 2 - name_label.get_minimum_size().x / 2 + 8), 25)


## Plain ProgressBars: the style's Theme gives them its frame and a fill per variation.
func _party(width: float) -> void:
	party = GridContainer.new()
	party.columns = 3
	party.position = Vector2(width - 120, 6)
	party.add_theme_constant_override("h_separation", 2)
	party.add_theme_constant_override("v_separation", 2)
	add_child(party)
	for member in [["Wren", 90, 40], ["Bram", 35, 70], ["Cyn", 60, 100]]:
		var l := Label.new()
		l.text = member[0]
		l.custom_minimum_size.x = 26
		party.add_child(l)
		for pair in [["HealthBar", member[1], 52], ["ManaBar", member[2], 36]]:
			var p := ProgressBar.new()
			p.theme_type_variation = StringName(pair[0])
			p.show_percentage = false
			p.value = pair[1]
			p.custom_minimum_size = Vector2(pair[2], 12)
			party.add_child(p)


## Bars over the enemies' heads: thin ones, a shield over the health of one.
func _mobs(width: float) -> void:
	var x := roundf(width / 2 - 120)
	for mob in [["Slime", "health", 100, ""], ["Knight", "health", 70, "shield"], ["Wisp", "magic", 45, "poison"]]:
		var foe := Mob.new(mob[0].to_lower())
		var lift := 6.0 if mob[0] == "Wisp" else 0.0  # it floats
		foe.position = Vector2(x + 24 - floorf(foe.custom_minimum_size.x / 2), Arena.FLOOR - foe.custom_minimum_size.y - lift)
		add_child(foe)
		foes.append(foe)
		var name_label := label(self, mob[0], Vector2(x, 106))
		name_label.position.x = x + 24 - roundf(name_label.get_minimum_size().x / 2)
		var b := bar(self, PixelBar.Shape.THIN, mob[1], Vector2(x, 118), 48, mob[2])
		bars.append(b)
		mobs.append(b)
		if mob[3] != "" and mob[3] in fills():
			var extra := bar(self, PixelBar.Shape.THIN, mob[3], Vector2(x, 126), 48, 60)
			bars.append(extra)
			mobs.append(extra)
		x += 96


func _status() -> void:
	var x := 6.0
	var shown: Array = ["rage", "shield", "magic", "poison"].filter(func(f: String) -> bool: return f in fills())
	if shown.is_empty():  # the sampler's
		shown = fills()
	for i in shown.size():
		var fill: String = shown[i]
		var b := bar(self, PixelBar.Shape.VERTICAL, fill, Vector2(x, 86), 56, [70, 45, 90, 25][i % 4])
		b.segments = 4
		bars.append(b)
		label(self, fill.left(1).to_upper(), Vector2(x + 3, 142))
		x += 16


func _bottom(width: float) -> void:
	hp_orb = bar(self, PixelBar.Shape.ORB, "health", Vector2(6, 168), 0, 80)
	hp_orb.scale = Vector2(2, 2)
	mp_orb = bar(self, PixelBar.Shape.ORB, "mana", Vector2(width - 70, 168), 0, 65)
	mp_orb.scale = Vector2(2, 2)
	bars.append_array([hp_orb, mp_orb])
	for i in 4:
		var r := bar(self, PixelBar.Shape.RING, ["magic", "mana", "rage", "shield"][i], Vector2(roundf(width / 2 - 52 + i * 28), 196), 0, 100)
		r.trail = false
		r.flash = false
		bars.append(r)
		rings.append(r)
		label(self, str(i + 1), r.position + Vector2(8, 5))
	xp = bar(self, PixelBar.Shape.BAR, "xp", Vector2(roundf(width / 2 - 110), 222), 220, 40)
	xp.segments = 10
	xp.trail = false
	xp.flash = false
	bars.append(xp)


func _buttons(width: float) -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	add_child(actions)
	for pair in [["Hit", hit], ["Heal", heal], ["Cast", cast], ["Strike boss", strike]]:
		var b := Button.new()
		b.text = pair[0]
		b.pressed.connect(pair[1])
		actions.add_child(b)
	actions.position = Vector2(roundf(width / 2 - actions.get_combined_minimum_size().x / 2), 44)
	var switcher := HBoxContainer.new()
	switcher.add_theme_constant_override("separation", 2)
	add_child(switcher)
	var group := ButtonGroup.new()
	for name in styles():
		var b := Button.new()
		b.text = name.capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = name == style
		b.toggled.connect(func(on: bool) -> void: if on: set_style(name))
		switcher.add_child(b)
		style_buttons[name] = b
	var ask := Button.new()
	ask.text = "?"
	ask.tooltip_text = "How to use this demo"
	ask.pressed.connect(func() -> void: show_help(true))
	switcher.add_child(ask)
	switcher.position = Vector2(roundf(width / 2 - switcher.get_combined_minimum_size().x / 2), 66)


## The opening card: what the demo is and how to use it, over the HUD until Start or Esc.
func _help() -> Control:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var panel := PanelContainer.new()
	veil.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PIXEL BARS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for t in HELP:
		var l := Label.new()
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size.x = 220
		box.add_child(l)
	var start := Button.new()
	start.text = "Start"
	start.custom_minimum_size.x = 48
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(func() -> void: show_help(false))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:  # keys stay on the card while it is up
		start.set_focus_neighbor(side, ^".")
	start.focus_next = ^"."
	start.focus_previous = ^"."
	box.add_child(start)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	veil.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed(&"ui_cancel"):
			show_help(false))
	return veil


func show_help(on: bool) -> void:
	help.visible = on
	if on:
		(help.find_children("*", "Button", true, false)[0] as Button).grab_focus()
	else:
		style_buttons[style].grab_focus()  # keys and a pad work before any click


func set_style(name: String) -> void:
	style = name
	theme = style_theme(name)
	for b in bars:
		b.style = name


func hit() -> void:
	hp.value -= 22
	hp_orb.value = hp.value
	hearts.value -= 3


func heal() -> void:
	hp.value += 30
	hp_orb.value = hp.value
	hearts.value += 4


func cast() -> void:
	for r in rings:
		if r.value >= r.max_value:
			r.value = 0
			mp.value -= 20
			mp_orb.value = mp.value
			stamina.value -= 30
			xp.value = fmod(xp.value + 7, 100)
			return


func strike() -> void:
	boss.value = boss.value - 9 if boss.value > 9 else 100
	for f in foes:
		f.hit()
	for m in mobs:
		m.value = m.value - 15 if m.value > 15 else 100


func _process(delta: float) -> void:
	for r in rings:
		r.value += delta * 100 / COOLDOWN
	stamina.value += delta * 12
	mp.value += delta * 3
	mp_orb.value = mp.value
	if not auto:
		return
	frame += 1
	var beat := {20: strike, 45: hit, 70: cast, 95: strike, 120: hit, 135: cast, 160: heal, 175: strike}
	if beat.has(frame % 180):
		beat[frame % 180].call()
	if auto_style_frames > 0 and frame % auto_style_frames == 0:
		var names := styles()
		style_buttons[names[(names.find(style) + 1) % names.size()]].button_pressed = true


## A dungeon behind the HUD: a brick wall and a flagstone floor, lit by two flickering torches in
## steps of light, so the bars read as over a game. Drawn in art pixels.
class Arena extends Control:
	const FLOOR := 160
	const BASE := Color(0.1, 0.1, 0.14)
	const WARM := Color(0.6, 0.34, 0.15)
	var time := 0.0
	var rest := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _process(delta: float) -> void:
		time += delta
		rest -= delta
		if rest <= 0.0:  # the flames move on a few times a second, not every frame
			rest = 0.1
			queue_redraw()

	func torches() -> Array[Vector2]:
		return [Vector2(82, 98), Vector2(size.x - 82, 98)]

	## The torches' light at `p`, in fifths.
	func light(p: Vector2) -> float:
		var l := 0.0
		var lit := torches()
		for i in lit.size():
			var reach := 125.0 + 6.0 * sin(time * 7.0 + i * 2.3) + 4.0 * sin(time * 13.0 + i)
			l += maxf(0.0, 1.0 - p.distance_to(lit[i]) / reach)
		return floorf(minf(l, 1.0) * 5.0) / 5.0

	func _draw() -> void:
		for y in range(0, FLOOR, 8):
			for x in range(-8 * int(y % 16 != 0), int(size.x), 16):
				var c := BASE.lerp(WARM, 0.6 * light(Vector2(x + 8, y + 4)))
				draw_rect(Rect2(x, y, 15, 7), c)
				draw_rect(Rect2(x, y, 15, 1), c.lightened(0.08))  # each brick's lit top edge
		draw_rect(Rect2(0, FLOOR, size.x, 1), BASE.lightened(0.25))
		var odd := false
		for y in range(FLOOR + 1, int(size.y), 12):
			for x in range(-12 * int(odd), int(size.x), 24):
				var c := BASE.darkened(0.15).lerp(WARM, 0.5 * light(Vector2(x + 12, y + 6)))
				draw_rect(Rect2(x, y, 23, 11), c)
			odd = not odd
		for t in torches():
			draw_rect(Rect2(t.x - 1, t.y + 2, 3, 8), Color(0.26, 0.17, 0.1))  # the sconce
			draw_rect(Rect2(t.x - 3, t.y + 1, 7, 2), Color(0.36, 0.24, 0.14))
			draw_rect(Rect2(t.x - 3, t.y + 3, 7, 1), Color(0.16, 0.1, 0.07))
			var lick := int(time * 9.0 + t.x) % 3  # the flame, licking up and to the sides
			draw_rect(Rect2(t.x - 2, t.y - 2, 5, 3), Color(0.9, 0.36, 0.12))
			draw_rect(Rect2(t.x - 1 + int(lick == 2), t.y - 4 - lick, 2, 3 + lick), Color(0.98, 0.58, 0.18))
			draw_rect(Rect2(t.x - 1, t.y - 2, 3, 2), Color(1.0, 0.82, 0.32))
			draw_rect(Rect2(t.x, t.y - 1, 1, 1), Color(1.0, 0.97, 0.8))


## An enemy under its bars, drawn from a character grid at 1x: it idles, and flashes white and
## shakes when struck.
class Mob extends Control:
	const PALETTE := {"k": Color8(26, 28, 44), "w": Color8(244, 244, 244), "e": Color8(196, 206, 220),
		"s": Color8(148, 176, 194), "d": Color8(86, 100, 128), "r": Color8(222, 64, 72), "R": Color8(150, 32, 56),
		"g": Color8(72, 196, 96), "G": Color8(32, 124, 76), "H": Color8(176, 240, 120), "b": Color8(64, 150, 240),
		"B": Color8(40, 78, 180), "y": Color8(255, 206, 84), "Y": Color8(206, 132, 40), "n": Color8(156, 96, 58),
		"p": Color8(156, 88, 208), "Q": Color8(92, 44, 132), "v": Color8(212, 170, 255)}
	const SPRITES := {
		"slime": [
			"......kkkk......",
			"....kkHHggkk....",
			"...kHHgggggGk...",
			"..kHgggggggggk..",
			"..kgggggggggGk..",
			".kggkkggggkkgGk.",
			".kggkwggggkwgGk.",
			".kggggggggggGGk.",
			"kgggggkkkgggGGGk",
			"kGgggggggggGGGGk",
			"kGGGGGGGGGGGGGGk",
			".kkkkkkkkkkkkkk."],
		"knight": [
			"......rr......",
			".....rRr......",
			"....kkkkkk....",
			"...keessssk...",
			"...kekkkksk...",
			"...kesssssk...",
			"....kddddk....",
			"..kkesssssdkk.",
			".kbbkessssdkek",
			"kbyybkssssdkek",
			"kbbybkssssdkek",
			"kbyybkddddkkek",
			"kbbbbkeesssknk",
			".kbbkkessssdkk",
			"..kk.kssssddk.",
			".....kddkddk..",
			".....kssksdk..",
			".....kssksdk..",
			"....kkdkkkdkk.",
			"....kkkk.kkkk."],
		"wisp": [
			".....k......",
			"....kvk..k..",
			"....kvpk.kk.",
			"...kvvpk.kpk",
			"..kvwvvpkkpk",
			"..kvwwvvppk.",
			".kvwwwwvvpk.",
			".kvkwwkvvpk.",
			".kvkwwkwvpk.",
			".kvwwwwwvpk.",
			"..kvwwwvpk..",
			"..kpvvvppk..",
			"...kppppk...",
			"....kQQk....",
			".....kk....."],
	}
	var grid: Array
	var time := 0.0
	var flash := 0.0
	var phase := 0.0

	func _init(kind: String) -> void:
		grid = SPRITES[kind]
		custom_minimum_size = Vector2(grid[0].length(), grid.size())
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase = kind.length()

	func hit() -> void:
		flash = 0.15

	func _process(delta: float) -> void:
		var before := _pose()
		time += delta
		flash = maxf(0.0, flash - delta)
		if _pose() != before or flash > 0.0:
			queue_redraw()

	## The frame's offset and squash, in whole pixels.
	func _pose() -> Vector3i:
		var bob := int(roundf(sin(time * 2.5 + phase)))  # -1, 0 or 1
		return Vector3i(int(time * 30.0) % 2 * 2 - 1 if flash > 0.0 else 0, bob, int(flash > 0.0))

	func _draw() -> void:
		var pose := _pose()
		var squash := pose.y > 0 and grid.size() < 14  # the slime squashes where the others bob
		var y := float(pose.y if not squash else 1)  # a row shorter, on the same ground
		for r in grid.size():
			if squash and r == 2:
				continue
			for x in grid[r].length():
				var ch: String = grid[r][x]
				if ch != ".":
					var c: Color = PALETTE[ch]
					if pose.z == 1 and ch != "k":
						c = Color.WHITE
					draw_rect(Rect2(x + pose.x, y, 1, 1), c)
			y += 1.0
