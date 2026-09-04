extends Node

const Art = preload('res://scripts/art.gd')
const PlayerScript = preload('res://scripts/player.gd')
const EnemyScript = preload('res://scripts/enemy.gd')
const BossScript = preload('res://scripts/boss.gd')
const PickupScript = preload('res://scripts/pickup.gd')
const ARROW_ICON = preload('res://assets/art/ui/arrow_right.svg')
const PAUSE_ICON = preload('res://assets/art/ui/pause.svg')
const SOUND_ON_ICON = preload('res://assets/art/ui/sound_on.svg')
const SOUND_OFF_ICON = preload('res://assets/art/ui/sound_off.svg')
const INK = Color('#254d4b')
const CREAM = Color('#fff3d6')
const CORAL = Color('#bd624a')
const MINT = Color('#a8d9ad')
const GOLD = Color('#edb956')
const SAVE_PATH = 'user://quest.cfg'

var ui: CanvasLayer
var backdrop: CanvasLayer
var screen: Control
var background: TextureRect
var world: Node2D
var camera: Camera2D
var player: CharacterBody2D
var boss: CharacterBody2D
var state := 'title'
var transitioning := false
var selected_map := 0
var tokens := 0
var insights := 0
var deaths := 0
var elapsed := 0.0
var checkpoint := Vector2(120, 430)
var checkpoint_reached := false
var boss_started := false
var boss_beaten := false
var death_pending := false
var level_cleared := false
var best_tokens := 0
var best_insights := 0
var muted := false
var hud_tokens: Label
var hud_insights: Label
var hud_sound_button: Button
var hud_hearts: Array[TextureRect] = []
var power_label: Label
var toast_label: Label
var toast_time := 0.0
var boss_bar: ProgressBar
var boss_caption: Label
var pause_panel: Control
var progress_bar: ProgressBar
var title_hero: TextureRect
var map_hero: TextureRect
var menu_time := 0.0
var theme_regular: Font
var theme_bold: Font
var run_id := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input()
	theme_regular = load('res://assets/fonts/Rubik-Regular.ttf')
	theme_bold = load('res://assets/fonts/Rubik-Bold.ttf')
	_load_save()
	Audio.set_muted(muted)
	backdrop = CanvasLayer.new()
	backdrop.layer = -10
	add_child(backdrop)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_show_title()

func _configure_input() -> void:
	var bindings := {
		'move_left':[KEY_A, KEY_LEFT], 'move_right':[KEY_D, KEY_RIGHT],
		'jump':[KEY_W, KEY_SPACE, KEY_UP], 'crouch':[KEY_S, KEY_DOWN],
		'sprint':[KEY_SHIFT], 'confirm':[KEY_ENTER], 'pause':[KEY_ESCAPE],
		'mute':[KEY_M], 'fullscreen':[KEY_F11], 'restart':[KEY_R]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		level_cleared = cfg.get_value('progress', 'cleared', false)
		best_tokens = cfg.get_value('progress', 'tokens', 0)
		best_insights = cfg.get_value('progress', 'insights', 0)
		muted = cfg.get_value('settings', 'muted', false)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value('progress', 'cleared', level_cleared)
	cfg.set_value('progress', 'tokens', best_tokens)
	cfg.set_value('progress', 'insights', best_insights)
	cfg.set_value('settings', 'muted', muted)
	cfg.save(SAVE_PATH)

func _clear_screen() -> void:
	run_id += 1
	transitioning = false
	get_tree().paused = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	player = null
	boss = null
	pause_panel = null
	hud_sound_button = null
	title_hero = null
	map_hero = null
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	for child in backdrop.get_children():
		backdrop.remove_child(child)
		child.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(screen)

func _set_background(path: String, tint := Color.WHITE) -> void:
	background = TextureRect.new()
	background.texture = load(path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size = Vector2(960, 540)
	background.modulate = tint
	backdrop.add_child(background)

func _label(parent: Node, text: String, pos: Vector2, font_size: int, color := INK, bold := false, width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override('font', theme_bold if bold else theme_regular)
	label.add_theme_font_size_override('font_size', font_size)
	label.add_theme_color_override('font_color', color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0:
		label.custom_minimum_size.x = width
		label.size.x = width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _panel(parent: Node, rect: Rect2, color: Color, border := Color.TRANSPARENT, radius := 14) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override('panel', style)
	parent.add_child(panel)
	return panel

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary := false, button_icon: Texture2D = null) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = button_icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text.is_empty() else HORIZONTAL_ALIGNMENT_RIGHT
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_theme_constant_override('h_separation', 10)
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override('font', theme_bold)
	button.add_theme_font_size_override('font_size', 18)
	button.add_theme_color_override('font_color', CREAM if primary else INK)
	button.add_theme_color_override('font_hover_color', CREAM if primary else INK)
	button.add_theme_color_override('font_focus_color', CREAM if primary else INK)
	for icon_state in ['normal', 'hover', 'pressed', 'hover_pressed', 'focus']:
		button.add_theme_color_override('icon_' + icon_state + '_color', CREAM if primary else INK)
	for type in ['normal','hover','pressed','focus']:
		var style := StyleBoxFlat.new()
		style.bg_color = CORAL if primary else CREAM
		if type == 'hover': style.bg_color = style.bg_color.lightened(0.12)
		if type == 'pressed': style.bg_color = style.bg_color.darkened(0.12)
		style.set_corner_radius_all(10)
		if button_icon != null and not text.is_empty():
			style.content_margin_left = 12
			style.content_margin_right = 12
		style.border_color = GOLD if type == 'focus' else INK
		style.set_border_width_all(3 if type == 'focus' else 2)
		style.shadow_color = Color(0.10,0.22,0.20,0.22)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0,3)
		button.add_theme_stylebox_override(type, style)
	button.pressed.connect(func(): Audio.play_sfx('select'); callback.call())
	button.mouse_entered.connect(func(): Audio.play_sfx('select'))
	parent.add_child(button)
	return button

func _icon(parent: Node, index: int, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = Art.texture(index)
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	image.set_deferred('size', rect.size)
	return image

func _shade(parent: Node, color: Color) -> ColorRect:
	var shade := ColorRect.new()
	shade.size = Vector2(960,540)
	shade.color = color
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	return shade

func _show_title() -> void:
	_clear_screen()
	state = 'title'
	_set_background('res://assets/art/landscape.png')
	_label(screen, 'A LITTLE ADVENTURE. A VERY BIG QUESTION.', Vector2(56,40), 12, INK, true)
	_label(screen, 'DARIO’S', Vector2(52,87), 54, INK, true)
	var title := _label(screen, 'AGI QUEST', Vector2(49,140), 80, CORAL, true)
	title.add_theme_color_override('font_shadow_color', CREAM)
	title.add_theme_constant_override('shadow_offset_y', 4)
	title.add_theme_constant_override('shadow_offset_x', 3)
	_label(screen, 'Big hair. Small hero. Unreasonably ambitious quest.', Vector2(58,240), 16, INK)
	_label(screen, 'Bounce through Token Meadow, outwit the bugs,\nand find out what’s really in that castle.', Vector2(58,275), 16, INK)
	_button(screen, 'LET’S GO', Rect2(58,342,222,52), _show_map, true, ARROW_ICON).grab_focus()
	_button(screen, 'How to play', Rect2(58,408,145,42), _show_help)
	_button(screen, 'Sound: ' + ('off' if muted else 'on'), Rect2(215,408,130,42), _toggle_mute_button)
	title_hero = _icon(screen, 0, Rect2(579,272,147,212))
	_icon(screen, 8, Rect2(747,278,32,36))
	_icon(screen, 9, Rect2(788,360,40,48))
	_panel(screen, Rect2(40,491,880,29), Color('#fff1d4dc'), Color.TRANSPARENT, 8)
	_label(screen, 'WASD + SPACE TO PLAY', Vector2(57,497), 11, INK, true)
	_label(screen, 'An unofficial, affectionate AI-industry parody', Vector2(405,497), 11, INK)
	_label(screen, 'CHAPTER 01', Vector2(807,497), 11, INK, true)
	Audio.play_music('title')

func _toggle_mute_button() -> void:
	_toggle_mute()
	if state == 'title': _show_title()

func _toggle_mute() -> void:
	muted = not muted
	Audio.set_muted(muted)
	_update_sound_button()
	_save()
	if state == 'level': _toast('Sound off' if muted else 'Sound on')

func _update_sound_button() -> void:
	if not is_instance_valid(hud_sound_button): return
	hud_sound_button.icon = SOUND_OFF_ICON if muted else SOUND_ON_ICON
	hud_sound_button.accessibility_name = 'Unmute sound' if muted else 'Mute sound'
	hud_sound_button.tooltip_text = hud_sound_button.accessibility_name + ' (M)'

func _show_help() -> void:
	if is_instance_valid(pause_panel): return
	_set_menu_enabled(false)
	pause_panel = Control.new()
	screen.add_child(pause_panel)
	_shade(pause_panel, Color(0.10,0.23,0.23,0.6)).mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(pause_panel, Rect2(169,56,622,428), CREAM, INK, 18)
	_label(pause_panel, 'SMALL HERO. BIG MOVES.', Vector2(211,88), 28, INK, true)
	_label(pause_panel, 'A / D   Move     •     W / Space   Jump\nHold jump to go higher. Shift to run. S to fast-fall.\nEsc   Pause     •     M   Sound     •     F11   Fullscreen', Vector2(212,140), 17, INK)
	_icon(pause_panel, 9, Rect2(212,243,44,54))
	_label(pause_panel, 'Safety Shield', Vector2(274,242), 18, INK, true)
	_label(pause_panel, 'Blocks one hit. Lasts 12 seconds.', Vector2(274,268), 15, INK)
	_icon(pause_panel, 10, Rect2(220,312,30,54))
	_label(pause_panel, 'Overclock Coffee', Vector2(274,311), 18, INK, true)
	_label(pause_panel, 'A 10-second burst of speed and bigger jumps.', Vector2(274,338), 15, INK)
	_label(pause_panel, 'Stomp bugs and Sam from above. Flags save your place.\nThree insight crystals are hidden along the high route.', Vector2(212,380), 15, INK)
	_button(pause_panel, 'Got it!', Rect2(620,427,127,38), _close_overlay, true).grab_focus()

func _close_overlay() -> void:
	if is_instance_valid(pause_panel): pause_panel.queue_free()
	pause_panel = null
	_set_menu_enabled(true)

func _set_menu_enabled(enabled: bool) -> void:
	for child in screen.get_children():
		if child is Button: child.disabled = not enabled

func _show_map() -> void:
	_clear_screen()
	state = 'map'
	_set_background('res://assets/art/world_map.png')
	_panel(screen, Rect2(24,22,912,72), CREAM, INK, 12)
	_label(screen, 'THE ROAD TO AGI', Vector2(45,33), 25, INK, true)
	_label(screen, 'CHAPTER 01  /  THE FIRST SMALL STEP', Vector2(46,66), 11, CORAL, true)
	_button(screen, 'Title', Rect2(826,37,88,39), _show_title)
	_label(screen, 'THE NEXT CASTLE', Vector2(625,102), 11, CREAM, true)
	var ring := _button(screen, '1–1', Rect2(473,251,54,46), func(): selected_map = 0; _show_map(), true)
	ring.tooltip_text = 'Token Meadow — ready to explore'
	_button(screen, '…', Rect2(818,205,48,40), func(): selected_map = 1; _show_map())
	map_hero = _icon(screen, 0, Rect2(475,192,48,66))
	if selected_map == 1: map_hero.position = Vector2(818,146)
	_panel(screen, Rect2(28,386,904,130), CREAM, INK, 14)
	if selected_map == 0:
		_label(screen, '1–1   TOKEN MEADOW', Vector2(51,401), 25, INK, true)
		_label(screen, 'Follow the tokens. Mind the bugs. Knock on the castle door.', Vector2(53,440), 15, INK)
		_label(screen, ('CLEARED  •  Best: %d tokens  /  %d of 3 insights' % [best_tokens,best_insights]) if level_cleared else '3 hidden insights   •   2 power-ups   •   1 suspiciously familiar boss', Vector2(53,475), 12, CORAL, true)
		_button(screen, 'PLAY AGAIN' if level_cleared else 'ENTER LEVEL', Rect2(715,424,193,53), _start_level, true, ARROW_ICON).grab_focus()
	else:
		_label(screen, '2–1   COMPUTE PEAKS', Vector2(51,401), 25, INK, true)
		_label(screen, 'An adventure for another day. The path is still being built.', Vector2(53,442), 15, INK)
		_label(screen, 'COMING IN A FUTURE CHAPTER', Vector2(53,475), 12, CORAL, true)
		_button(screen, 'BACK TO 1–1', Rect2(715,424,193,53), func(): selected_map=0; _show_map(), true).grab_focus()
	Audio.play_music('title')

func _start_level() -> void:
	_clear_screen()
	state = 'level'
	tokens = 0
	insights = 0
	deaths = 0
	elapsed = 0
	checkpoint = Vector2(120,430)
	checkpoint_reached = false
	boss_started = false
	boss_beaten = false
	death_pending = false
	_set_background('res://assets/art/landscape.png')
	background.size = Vector2(1200,675)
	background.position.y = -108
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.add_child(load('res://scenes/meadow_layout.tscn').instantiate())
	player = PlayerScript.new()
	player.position = checkpoint
	player.spawn_point = checkpoint
	world.add_child(player)
	player.health_changed.connect(_update_health)
	player.died.connect(_on_died)
	camera = Camera2D.new()
	camera.position = Vector2(480,270)
	camera.position_smoothing_enabled = false
	world.add_child(camera)
	camera.make_current()
	_populate_level()
	_create_hud()
	_update_health(player.health)
	_toast('TOKEN MEADOW   •   Let’s find that AGI.', 3.0)
	Audio.play_music('meadow')

func _sprite_at(index: int, at: Vector2, height: float, parent: Node = null) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Art.texture(index)
	sprite.position = at
	sprite.scale = Vector2.ONE * height / sprite.texture.get_height()
	(parent if parent != null else world).add_child(sprite)
	return sprite

func _world_text(text: String, at: Vector2, font_size := 14, width := 200.0) -> void:
	var label := _label(world, text, at, font_size, INK, true, width)
	label.add_theme_color_override('font_outline_color', CREAM)
	label.add_theme_constant_override('outline_size', 5)

func _pickup(kind: String, at: Vector2) -> void:
	var item := PickupScript.new()
	item.kind = kind
	item.position = at
	item.collected.connect(_collect)
	world.add_child(item)

func _token_arc(x: float, y: float, count: int, spacing := 45.0) -> void:
	for i in range(count):
		_pickup('token', Vector2(x+i*spacing,y-sin(float(i)/maxf(count-1,1)*PI)*30))

func _populate_level() -> void:
	_world_text('A / D   MOVE\nW / SPACE   JUMP', Vector2(68,306), 15, 200)
	_world_text('HOLD JUMP\nTO GO HIGHER', Vector2(382,290), 13, 170)
	_world_text('STOMP FROM ABOVE!', Vector2(856,362), 13, 250)
	_world_text('SHIFT TO RUN', Vector2(1507,380), 13, 210)
	_world_text('THE HIGH ROAD\nHAS ITS REWARDS', Vector2(2825,255), 13, 240)
	_world_text('ONE LAST LEAP', Vector2(4600,375), 13, 250)
	for data in [[280,391,5],[643,287,4],[909,199,4],[1192,315,5],[1510,393,5],[1905,287,4],[2140,207,4],[2420,315,5],[2700,390,4],[2930,287,4],[3160,199,4],[3480,305,5],[3830,388,4],[4150,287,3],[4380,207,3],[4710,387,5],[4990,388,4]]:
		_token_arc(data[0],data[1],data[2])
	for point in [Vector2(1214,141),Vector2(2442,135),Vector2(3472,141)]:
		_pickup('insight',point)
	_pickup('shield', Vector2(685,274))
	_pickup('coffee', Vector2(1745,389))
	_pickup('heart', Vector2(2710,385))
	_pickup('shield', Vector2(4460,195))
	_pickup('heart', Vector2(5010,377))
	_supply_block(Vector2(1650,310), 'coffee')
	_supply_block(Vector2(3970,304), 'shield')
	for data in [[960,810,1130,'bug'],[1620,1410,1810,'bug'],[2190,1960,2320,'bug'],[3000,2850,3220,'bug'],[3990,3820,4220,'bug'],[4770,4560,4920,'bug'],[2300,2110,2310,'cloud'],[3280,3150,3400,'cloud'],[4290,4180,4430,'cloud']]:
		var enemy := EnemyScript.new()
		enemy.kind = data[3]
		enemy.position = Vector2(data[0], 290 if data[3]=='cloud' else 435)
		enemy.patrol_left = data[1]
		enemy.patrol_right = data[2]
		enemy.defeated.connect(func(at): _burst(at, 8, 6))
		world.add_child(enemy)
	var flag := _sprite_at(14, Vector2(2780,398), 83)
	flag.name = 'CheckpointFlag'
	_world_text('CHECKPOINT', Vector2(2725,315), 12, 160)
	_sprite_at(14, Vector2(5070,399), 83)
	_world_text('TAKE A BREATH.\nTHE DEMO IS AHEAD.', Vector2(4940,285), 13, 240)
	_spawn_boss()

func _supply_block(at: Vector2, power: String) -> void:
	var block := StaticBody2D.new()
	block.position = at
	block.collision_layer = 1
	block.collision_mask = 2
	block.set_meta('power',power)
	block.set_meta('used',false)
	block.add_to_group('supply_blocks')
	var sprite := Sprite2D.new()
	sprite.texture = load('res://assets/art/environment/question_block.svg')
	block.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(48,48)
	shape.shape = box
	block.add_child(shape)
	world.add_child(block)

func _spawn_boss() -> void:
	if is_instance_valid(boss):
		world.remove_child(boss)
		boss.queue_free()
	boss = BossScript.new()
	boss.position = Vector2(5520,435)
	boss.arena_left = 5250
	boss.arena_right = 5780
	boss.defeated.connect(_boss_defeated)
	boss.health_changed.connect(func(value):
		if is_instance_valid(boss_bar): boss_bar.value = value)
	world.add_child(boss)
	boss.set_physics_process(false)

func _create_hud() -> void:
	_panel(screen, Rect2(18,16,271,58), CREAM, INK, 12)
	hud_hearts.clear()
	for i in range(3): hud_hearts.append(_icon(screen,11,Rect2(32+i*34,31,27,26)))
	_icon(screen,8,Rect2(156,30,28,29))
	hud_tokens = _label(screen,'000',Vector2(193,31),23,INK,true)
	_panel(screen, Rect2(670,16,272,58), CREAM, INK, 12)
	_icon(screen,15,Rect2(689,28,28,32))
	hud_insights = _label(screen,'0 / 3',Vector2(729,32),21,INK,true)
	var pause_button := _button(screen,'',Rect2(838,27,42,35),_pause,false,PAUSE_ICON)
	pause_button.accessibility_name = 'Pause'
	pause_button.tooltip_text = 'Pause (Esc)'
	hud_sound_button = _button(screen,'',Rect2(890,27,39,35),_toggle_mute,false,SOUND_ON_ICON)
	_update_sound_button()
	power_label = _label(screen,'',Vector2(23,82),14,INK,true)
	power_label.add_theme_color_override('font_outline_color',CREAM)
	power_label.add_theme_constant_override('outline_size',5)
	_label(screen,'1–1  TOKEN MEADOW',Vector2(351,21),14,INK,true)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(345,50)
	progress_bar.size = Vector2(248,7)
	progress_bar.show_percentage = false
	progress_bar.max_value = 5940
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color('#fff3d68c')
	bg.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override('background',bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CORAL
	fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override('fill',fill)
	screen.add_child(progress_bar)
	progress_bar.set_deferred('size', Vector2(248,7))
	toast_label = _label(screen,'',Vector2(150,479),18,CREAM,true,660)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override('font_outline_color',INK)
	toast_label.add_theme_constant_override('outline_size',8)
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(330,114)
	boss_bar.size = Vector2(300,12)
	boss_bar.max_value = 3
	boss_bar.value = 3
	boss_bar.show_percentage = false
	boss_bar.visible = false
	boss_bar.add_theme_stylebox_override('background',bg)
	boss_bar.add_theme_stylebox_override('fill',fill)
	screen.add_child(boss_bar)
	boss_bar.set_deferred('size', Vector2(300,12))
	boss_caption = _label(screen,'SAM  /  THE DEMO MUST GO ON',Vector2(300,85),14,INK,true,360)
	boss_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_caption.visible = false

func _collect(kind: String, at: Vector2) -> void:
	match kind:
		'token':
			tokens += 1
			Audio.play_sfx('token')
			_burst(at,8,3)
		'insight':
			insights += 1
			Audio.play_sfx('powerup')
			_toast('INSIGHT %d / 3   •   A little closer to understanding.' % insights)
			_burst(at,15,7)
		_:
			player.grant_power(kind)
			var names := {'shield':'SAFETY SHIELD   •   One hit of protection, 12 seconds.', 'coffee':'OVERCLOCK   •   Faster feet. Bigger leaps. 10 seconds.', 'heart':'A little encouragement. +1 heart.'}
			_toast(names.get(kind,''))
	hud_tokens.text = '%03d' % tokens
	hud_insights.text = '%d / 3' % insights

func _burst(at: Vector2, index: int, count: int) -> void:
	for i in range(count):
		var sparkle := _sprite_at(index,at,9)
		var target := at + Vector2(cos(i*TAU/count)*34,-24+sin(i*TAU/count)*28)
		var tween := sparkle.create_tween().set_parallel(true)
		tween.tween_property(sparkle,'position',target,0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle,'modulate:a',0.0,0.45)
		tween.chain().tween_callback(sparkle.queue_free)

func _update_health(value: int) -> void:
	for i in range(hud_hearts.size()): hud_hearts[i].modulate.a = 1.0 if i<value else 0.22

func _toast(text: String, duration := 3.0) -> void:
	if not is_instance_valid(toast_label): return
	toast_label.text = text
	toast_time = duration
	toast_label.modulate.a = 1.0

func _on_died() -> void:
	if death_pending: return
	var dying_run := run_id
	death_pending = true
	deaths += 1
	_toast('A small setback. A fresh start.', 1.0)
	await get_tree().create_timer(0.8, false).timeout
	if state != 'level' or run_id != dying_run or not is_instance_valid(player): return
	player.respawn(checkpoint)
	death_pending = false
	if boss_started and not boss_beaten:
		_spawn_boss()
		boss_started = false
		boss_bar.value = 3
		boss_bar.visible = false
		boss_caption.visible = false
		Audio.play_music('meadow')
	_toast('Back at the flag. You’ve got this.' if checkpoint_reached else 'Try again! Hold W / Space for a higher jump.')

func _boss_defeated() -> void:
	boss_beaten = true
	boss_bar.visible = false
	boss_caption.text = 'DEMO COMPLETE. NICE WORK!'
	_toast('Sam: “Okay, that was a pretty good demo.”  To the castle!', 5.0)
	Audio.play_music('meadow')
	for i in range(8): _pickup('token', Vector2(5580+i*35,370))

func _pause() -> void:
	if state != 'level': return
	if get_tree().paused:
		get_tree().paused = false
		_close_overlay()
		return
	get_tree().paused = true
	_set_menu_enabled(false)
	pause_panel = Control.new()
	screen.add_child(pause_panel)
	_shade(pause_panel,Color(0.10,0.23,0.23,0.66)).mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(pause_panel,Rect2(268,109,424,326),CREAM,INK,18)
	_label(pause_panel,'TAKE A BREATHER',Vector2(304,139),27,INK,true)
	_label(pause_panel,'Even little heroes need a pause.',Vector2(306,181),16,INK)
	_button(pause_panel,'KEEP GOING',Rect2(306,231,347,48),_pause,true).grab_focus()
	_button(pause_panel,'Restart level',Rect2(306,293,164,42),_start_level)
	_button(pause_panel,'World map',Rect2(488,293,165,42),_show_map)
	_label(pause_panel,'A / D move  •  W / Space jump  •  Shift run\nM sound  •  F11 fullscreen  •  Esc resume',Vector2(306,365),13,INK)

func _finish_level() -> void:
	if transitioning: return
	var finishing_run := run_id
	transitioning = true
	player.input_enabled = false
	player.velocity = Vector2.ZERO
	level_cleared = true
	best_tokens = maxi(best_tokens,tokens)
	best_insights = maxi(best_insights,insights)
	_save()
	Audio.play_music('victory')
	await get_tree().create_timer(0.5, false).timeout
	if state != 'level' or run_id != finishing_run:
		return
	var final_tokens := tokens
	var final_insights := insights
	var final_elapsed := elapsed
	_clear_screen()
	state = 'result'
	transitioning = false
	_set_background('res://assets/art/landscape.png')
	_shade(screen,Color(0.93,0.96,0.83,0.18))
	_panel(screen,Rect2(139,48,682,447),CREAM,INK,18)
	_label(screen,'CHAPTER 01 COMPLETE',Vector2(339,72),14,CORAL,true)
	_label(screen,'A GIANT LITTLE STEP.',Vector2(214,108),38,INK,true)
	_icon(screen,0,Rect2(208,191,76,133))
	_label(screen,'“Thank you, Dario!\nBut AGI is in another castle.”',Vector2(323,190),24,INK,true)
	_label(screen,'The good news? You found the way forward.\nAnd probably a few bugs along the way.',Vector2(324,268),16,INK)
	_label(screen,'%d TOKENS' % final_tokens,Vector2(212,343),21,CORAL,true)
	_label(screen,'%d / 3 INSIGHTS' % final_insights,Vector2(401,343),21,CORAL,true)
	_label(screen,'%d:%02d' % [int(final_elapsed)/60,int(final_elapsed)%60],Vector2(653,343),21,CORAL,true)
	_button(screen,'WORLD MAP',Rect2(244,408,222,50),_show_map,true).grab_focus()
	_button(screen,'One more run',Rect2(491,408,222,50),_start_level)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('mute'):
		_toggle_mute()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed('fullscreen'):
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed('pause'):
		if state == 'level': _pause()
		elif is_instance_valid(pause_panel): _close_overlay()
		elif state == 'map': _show_title()
		return
	if is_instance_valid(pause_panel): return
	if state == 'title' and (event.is_action_pressed('jump') or event.is_action_pressed('confirm')):
		_show_map()
	elif state == 'map':
		if event.is_action_pressed('move_left') or event.is_action_pressed('move_right'):
			selected_map = 1-selected_map
			Audio.play_sfx('select')
			_show_map()
		elif event.is_action_pressed('jump') or event.is_action_pressed('confirm'):
			if selected_map == 0: _start_level()
	elif state == 'result' and event.is_action_pressed('confirm'):
		_show_map()

func _physics_process(_delta: float) -> void:
	if state != 'level' or get_tree().paused or not is_instance_valid(player): return
	player.position.x = clampf(player.position.x, 18, 6080)
	if player.is_on_ceiling():
		for i in range(player.get_slide_collision_count()):
			var collision := player.get_slide_collision(i)
			var object := collision.get_collider()
			if object is Node and object.is_in_group('supply_blocks') and not object.get_meta('used'):
				object.set_meta('used',true)
				object.modulate = Color('#a2b4a2')
				var power: String = object.get_meta('power')
				player.grant_power(power)
				_toast('SUPPLY CACHE   •   ' + ('Overclock activated!' if power=='coffee' else 'Safety Shield activated!'))
				_burst(object.position+Vector2(0,-25),10 if power=='coffee' else 9,6)

func _process(delta: float) -> void:
	menu_time += delta
	if is_instance_valid(title_hero): title_hero.position.y = 272 + sin(menu_time*2.0)*3
	if is_instance_valid(map_hero): map_hero.position.y = (192 if selected_map==0 else 146) + sin(menu_time*3.0)*3
	if state != 'level' or get_tree().paused or not is_instance_valid(player): return
	elapsed += delta
	var target_x := clampf(player.position.x+110,480,5620)
	if boss_started and not boss_beaten: target_x = 5510
	camera.position.x = lerpf(camera.position.x,target_x,1.0-exp(-delta*6))
	var target_y := clampf(player.position.y + 100, 160, 270)
	camera.position.y = lerpf(camera.position.y,target_y,1.0-exp(-delta*5))
	background.position.x = -clampf(camera.position.x*0.035,0,220)
	progress_bar.value = player.position.x
	toast_time = maxf(0,toast_time-delta)
	toast_label.modulate.a = minf(1,toast_time*3)
	var powers := ''
	if player.shield_time>0: powers += 'SHIELD  %ds   ' % ceili(player.shield_time)
	if player.boost_time>0: powers += 'OVERCLOCK  %ds' % ceili(player.boost_time)
	power_label.text = powers
	if player.position.x > 2730 and not checkpoint_reached:
		checkpoint_reached = true
		checkpoint = Vector2(2800,430)
		Audio.play_sfx('checkpoint')
		_toast('CHECKPOINT   •   Your progress is safe here.')
	if player.position.x > 5030 and checkpoint.x < 5000:
		checkpoint = Vector2(5085,430)
		Audio.play_sfx('checkpoint')
		_toast('BOSS CHECKPOINT   •   Land three stomps on Sam!')
	if player.position.x > 5200 and not boss_started and not boss_beaten:
		boss_started = true
		boss.set_physics_process(true)
		boss_bar.visible = true
		boss_caption.visible = true
		Audio.play_music('boss')
		_toast('Sam: “Just one more demo!”   •   Jump on top to interrupt.',4)
	if boss_started and not boss_beaten:
		player.position.x = clampf(player.position.x,5220,5830)
	if boss_beaten and player.position.x > 5895:
		_finish_level()
