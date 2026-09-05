extends SceneTree

var _checks := 0
var _failures: Array[String] = []
var _controls: Node2D
var _interactions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := root.get_node_or_null("Audio")
	if audio:
		audio.free()
	_controls = load("res://scripts/touch_controls.gd").new()
	root.add_child(_controls)
	_controls.interaction_started.connect(func(): _interactions += 1)
	_touch(0, Vector2(184, 464), true)
	_check(not Input.is_action_pressed("touch_move_right"), "Disabled controls ignore touches")
	_controls.set_enabled(true)
	_check(_controls.visible, "Enabling controls shows the saved control assets")
	_touch(0, Vector2(184, 464), true)
	_check(Input.is_action_pressed("touch_move_right"), "Right touch holds right movement")
	_check(Input.is_action_pressed("touch_sprint"), "Direction touch enables run speed by default")
	_touch(1, Vector2(870, 464), true)
	_check(Input.is_action_pressed("touch_move_right") and Input.is_action_pressed("touch_jump"), "Separate fingers hold movement and jump together")
	await process_frame
	await process_frame
	_check(Input.is_action_pressed("touch_jump"), "Jump remains held across frames for variable height and stomps")
	_drag(1, Vector2(840, 380))
	_check(Input.is_action_pressed("touch_jump"), "Jump finger drift preserves a held jump")
	_touch(1, Vector2(840, 380), false)
	_check(not Input.is_action_pressed("touch_jump") and Input.is_action_pressed("touch_move_right"), "Releasing jump leaves the direction finger active")
	_drag(0, Vector2(76, 464))
	_check(Input.is_action_pressed("touch_move_left") and not Input.is_action_pressed("touch_move_right"), "Sliding the movement finger changes direction")
	_drag(0, Vector2(128, 464))
	_check(Input.is_action_pressed("touch_move_left"), "Movement pad has no inactive gap between arrows")
	_drag(0, Vector2(132, 464))
	_check(Input.is_action_pressed("touch_move_right"), "Sliding across the pad midpoint selects right")
	_drag(0, Vector2(300, 340))
	_check(not Input.is_action_pressed("touch_move_right") and not Input.is_action_pressed("touch_sprint"), "Dragging off the movement pad stops movement and sprint")
	_drag(0, Vector2(76, 464))
	_check(Input.is_action_pressed("touch_move_left"), "The captured movement finger can return to the pad")
	_touch(0, Vector2(76, 464), false)
	_check(not Input.is_action_pressed("touch_move_left"), "Direction release stops movement")

	_touch(2, Vector2(184, 464), true)
	_touch(3, Vector2(870, 464), true)
	_touch(2, Vector2(184, 464), true, true)
	_check(not Input.is_action_pressed("touch_move_right") and Input.is_action_pressed("touch_jump"), "Canceled touch releases only its own action")
	_touch(4, Vector2(870, 464), true)
	_touch(3, Vector2(870, 464), false)
	_check(Input.is_action_pressed("touch_jump"), "Two fingers on one action retain it until both release")
	_touch(4, Vector2(870, 464), false)
	_check(not Input.is_action_pressed("touch_jump"), "Last jump finger release ends the held jump")
	_touch(5, Vector2(292, 476), true)
	_check(Input.is_action_pressed("touch_crouch"), "Drop control holds the fast fall action")
	_touch(5, Vector2(292, 476), false)
	_check(not Input.is_action_pressed("touch_crouch"), "Releasing drop ends fast fall")

	_touch(6, Vector2(184, 464), true)
	_touch(7, Vector2(768, 390), true)
	_check(not _controls.auto_run and not Input.is_action_pressed("touch_sprint") and Input.is_action_pressed("touch_move_right"), "RUN toggle switches an active direction hold to walking")
	_drag(7, Vector2(770, 392))
	_check(not _controls.auto_run, "Dragging within RUN does not repeatedly toggle it")
	_touch(7, Vector2(768, 390), false)
	_touch(7, Vector2(768, 390), true)
	_check(_controls.auto_run and Input.is_action_pressed("touch_sprint"), "A second RUN tap restores automatic sprint")
	_controls.release_all()
	_check(_all_released(), "release_all clears every touch action")
	_touch(8, Vector2(500, 200), true)
	_drag(8, Vector2(870, 464))
	_check(_all_released(), "Touches starting outside controls remain available for menus")

	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
	Input.action_press("move_right")
	_touch(9, Vector2(184, 464), true)
	_touch(10, Vector2(870, 464), true)
	_controls.set_enabled(false)
	_check(not _controls.visible and _all_released(), "Disabling the overlay hides it and releases active fingers")
	_check(Input.is_action_pressed("move_right"), "Releasing touch controls preserves keyboard movement")
	Input.action_release("move_right")
	_controls.set_enabled(true)
	_drag(9, Vector2(76, 464))
	_check(_all_released(), "Old finger drags cannot restart movement after re-enabling")
	_touch(11, Vector2(184, 464), true)
	paused = true
	await process_frame
	await process_frame
	_check(_all_released(), "Pausing releases input even though the overlay processes always")
	_touch(12, Vector2(870, 464), true)
	_check(_all_released(), "Paused controls cannot restart actions")
	paused = false
	await process_frame
	_touch(13, Vector2(184, 464), true)
	_controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(_all_released(), "Application focus loss releases held actions")
	_touch(14, Vector2(870, 464), true)
	_controls.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(_all_released(), "Window focus loss releases held actions")
	_touch(15, Vector2(184, 464), true)
	_controls.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_all_released(), "Mobile background notification releases held actions")
	_check(_interactions > 0, "Accepted touches signal an interaction for audio activation")
	_touch(16, Vector2(870, 464), true)
	_controls.queue_free()
	await process_frame
	_check(_all_released(), "Removing controls releases their remaining actions")
	if _failures.is_empty():
		print("PASS: %d touch control checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d of %d touch control checks" % [_failures.size(), _checks])
		quit(1)


func _touch(index: int, position: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	_controls._input(event)


func _drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	_controls._input(event)


func _all_released() -> bool:
	for action in ["touch_move_left", "touch_move_right", "touch_jump", "touch_crouch", "touch_sprint"]:
		if Input.is_action_pressed(action):
			return false
	return true


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
