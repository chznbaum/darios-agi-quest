extends SceneTree

# Register the controller after its Audio autoload, and intercept both progress
# reads and writes so this test never changes the player's saved game.
const ISOLATED_APP_SOURCE := """extends "res://scripts/main.gd"
var save_requests := 0
func _detect_touch_mode() -> bool:
	return true
func _load_save() -> void:
	muted = true
func _save() -> void:
	save_requests += 1
"""
const DESKTOP_APP_SOURCE := """extends "res://scripts/main.gd"
func _detect_touch_mode() -> bool:
	return false
func _load_save() -> void:
	muted = true
func _save() -> void:
	pass
"""
const RIGHT := Vector2(184, 464)
const JUMP := Vector2(870, 464)
const TOUCH_ACTIONS := ["touch_move_left", "touch_move_right", "touch_jump", "touch_crouch", "touch_sprint"]

var _app
var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_app = _new_app(ISOLATED_APP_SOURCE)
	if _app == null:
		quit(1)
		return
	root.add_child(_app)
	await process_frame
	_check(_app.touch_mode and _app.state == "title", "A touch-capable launch selects mobile controls")
	_check(_app.touch_controls == null, "The title has no gameplay touch controls")
	_check(not _app.level_cleared and _app.best_tokens == 0 and _app.muted, "Mobile tests use isolated progress and muted audio")
	_check_mobile_buttons("title")
	_press("How to play")
	_check(is_instance_valid(_app.pause_panel), "Mobile help opens from the title")
	_check_mobile_buttons("help")
	_press("Got it!")
	_press("LET’S GO")
	await process_frame
	_check(_app.state == "map" and _app.touch_controls == null, "The world map has no gameplay touch controls")
	_check_mobile_buttons("world map")
	_press("ENTER LEVEL")
	await _ticks(10)
	_app._apply_mobile_environment(false, true, 0)
	_check(not paused and not _app._mobile_blocked, "A visible landscape launch starts playable without a pause interruption")
	_check(_app.state == "level" and is_instance_valid(_app.touch_controls) and _app.touch_controls.visible, "Starting the level shows touch controls")
	_check_mobile_buttons("HUD")
	_check(_app.player.is_on_floor(), "The player settles on the starting ground before touch movement")
	await _verify_touch_movement()
	await _verify_pause_and_environment()
	await _verify_transitions()

	_app.queue_free()
	await process_frame
	_app = _new_app(DESKTOP_APP_SOURCE)
	root.add_child(_app)
	_app._start_level()
	await process_frame
	_check(not _app.touch_mode and _app.touch_controls == null, "Desktop gameplay keeps the keyboard layout without touch controls")
	_app.queue_free()
	await process_frame
	var audio := root.get_node_or_null("Audio")
	if is_instance_valid(audio):
		audio.queue_free()
	await create_timer(0.2).timeout
	await process_frame
	if _failures.is_empty():
		print("PASS: %d mobile controller integration checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d of %d mobile controller integration checks" % [_failures.size(), _checks])
		quit(1)


func _new_app(source: String):
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		push_error("Unable to compile the isolated mobile-test controller")
		return null
	return script.new()


func _verify_touch_movement() -> void:
	var starting_position: Vector2 = _app.player.position
	_touch(10, RIGHT, true)
	_touch(11, JUMP, true)
	_check(Input.is_action_pressed("touch_move_right") and Input.is_action_pressed("touch_jump") and Input.is_action_pressed("touch_sprint"), "Separate fingers can hold right, auto-run and jump together")
	await _ticks(8)
	_check(_app.player.position.x > starting_position.x + 8.0 and _app.player.position.y < starting_position.y - 45.0, "Real touch actions move the player forward and upward together")
	_touch(10, RIGHT, false)
	_check(not Input.is_action_pressed("touch_move_right") and Input.is_action_pressed("touch_jump"), "Lifting movement leaves the other finger's jump held")
	var held_peak := starting_position.y - float(_app.player.position.y)
	for frame in range(100):
		await _ticks(1)
		held_peak = maxf(held_peak, starting_position.y - float(_app.player.position.y))
		if _app.player.is_on_floor():
			break
	_touch(11, JUMP, false)
	_check(_app.player.is_on_floor() and held_peak > 130.0, "Holding touch jump completes a full-height jump and lands safely")
	await _ticks(2)
	var tap_ground_y: float = _app.player.position.y
	_touch(12, JUMP, true)
	await _ticks(2)
	var tap_peak := tap_ground_y - float(_app.player.position.y)
	_touch(12, JUMP, false)
	for frame in range(100):
		await _ticks(1)
		tap_peak = maxf(tap_peak, tap_ground_y - float(_app.player.position.y))
		if _app.player.is_on_floor():
			break
	_check(_app.player.is_on_floor() and tap_peak > 10.0 and held_peak > tap_peak + 55.0, "Releasing touch jump early produces a shorter jump")
	_check(_touch_actions_released(), "Finishing both jumps leaves no held touch action")


func _verify_pause_and_environment() -> void:
	_touch(20, RIGHT, true)
	_key(KEY_D, true)
	_check(Input.is_action_pressed("move_right"), "A real keyboard event still registers alongside touch input")
	_press("Pause")
	_check(paused and not _app.touch_controls.visible and _touch_actions_released(), "Pausing immediately hides controls and releases every touch action")
	_check(Input.is_action_pressed("move_right"), "Clearing touch input preserves a held physical keyboard action")
	_key(KEY_D, false)
	_touch(21, JUMP, true)
	_check(_touch_actions_released(), "A touch cannot restart movement behind the pause menu")
	_check_mobile_buttons("pause menu")
	_press("KEEP GOING")
	_check(not paused and _app.touch_controls.visible and _touch_actions_released(), "Explicit resume restores controls without resurrecting old touches")

	_touch(22, RIGHT, true)
	_app._apply_mobile_environment(false, false, 1)
	_check(paused and _touch_actions_released() and not _app.touch_controls.visible, "Hiding the mobile page pauses gameplay and clears active touches")
	_app._apply_mobile_environment(false, true, 1)
	_check(paused, "Returning to a visible page waits for an explicit resume")
	_press("KEEP GOING")
	_check(not paused, "The pause menu resumes after the page becomes visible")

	_app._apply_mobile_environment(true, true, 2)
	_check(paused and not _app.touch_controls.visible, "Portrait orientation pauses the landscape game")
	_app._pause()
	_check(paused, "Resume stays blocked while the phone is portrait")
	_app._apply_mobile_environment(false, true, 2)
	_check(paused, "Rotating back to landscape does not resume unexpectedly")
	_press("KEEP GOING")
	_check(not paused and _app.touch_controls.visible, "Explicit resume works after returning to landscape")

	# A throttled browser may skip every animation frame while its tab is hidden.
	# The shell's event revision must preserve that interruption on its next frame.
	_app._apply_mobile_environment(false, true, 3)
	_check(paused and _touch_actions_released(), "A changed pause revision catches a tab interruption even without an inactive game frame")
	_press("KEEP GOING")
	_app._apply_mobile_environment(false, true, 3)
	_check(not paused, "An unchanged environment revision does not repeatedly pause after resume")


func _verify_transitions() -> void:
	_touch(30, RIGHT, true)
	_touch(31, JUMP, true)
	_app.player._die()
	_check(_app.death_pending and not _app.touch_controls.visible and _touch_actions_released(), "Death hides and releases touch controls before the respawn delay")
	await create_timer(0.9).timeout
	_check(not _app.death_pending and not _app.player.is_dead and _app.touch_controls.visible, "Respawn restores mobile controls")
	_check(_touch_actions_released(), "Respawn does not inherit fingers held at death")

	_touch(32, RIGHT, true)
	var old_controls = _app.touch_controls
	_app._show_map()
	_check(_app.state == "map" and _app.touch_controls == null and _touch_actions_released(), "Changing scenes clears touch ownership before removing the level")
	await process_frame
	_check(not is_instance_valid(old_controls), "The old touch overlay is freed with its screen")
	_app._apply_mobile_environment(true, true, 4)
	_check(not paused and _app._mobile_blocked, "Portrait orientation on the world map blocks gameplay input without creating a pause menu")
	_app._apply_mobile_environment(false, true, 4)
	_app._start_level()
	await process_frame
	_app._apply_mobile_environment(false, true, 4)
	_check(not paused and _app.touch_controls.visible and _touch_actions_released(), "A new run after map rotation starts playable with a fresh, idle touch overlay")
	_touch(33, RIGHT, true)
	_app._finish_level()
	_check(_app.transitioning and not _app.touch_controls.visible and _touch_actions_released(), "Completion immediately disables touch movement during the victory delay")
	await create_timer(0.65).timeout
	_check(_app.state == "result" and _app.touch_controls == null, "The result screen contains no gameplay touch overlay")
	_check(_app.save_requests == 1, "Completion invokes only the isolated save interceptor")
	_check_mobile_buttons("result screen")


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _app.touch_controls.get_global_transform_with_canvas() * point
	event.pressed = pressed
	_app.touch_controls._input(event)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _ticks(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _touch_actions_released() -> bool:
	for action in TOUCH_ACTIONS:
		if Input.is_action_pressed(action):
			return false
	return true


func _find_button(label: String) -> Button:
	for node in _app.screen.find_children("*", "Button", true, false):
		if node.text == label or node.accessibility_name == label:
			return node
	return null


func _press(label: String) -> void:
	var button := _find_button(label)
	_check(is_instance_valid(button), "Screen exposes button: " + label)
	if is_instance_valid(button):
		button.pressed.emit()


func _check_mobile_buttons(context: String) -> void:
	for button in _app.screen.find_children("*", "Button", true, false):
		_check(button.size.y >= 60.0, "%s button has a mobile-sized target: %s" % [context, button.text if not button.text.is_empty() else button.accessibility_name])


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
