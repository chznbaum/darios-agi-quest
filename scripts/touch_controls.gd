extends Node2D

signal interaction_started

const TOUCH_ACTIONS: Array[StringName] = [
	&"touch_move_left", &"touch_move_right", &"touch_jump", &"touch_crouch", &"touch_sprint",
]
const CENTERS := {
	&"left": Vector2(76, 464), &"right": Vector2(184, 464),
	&"down": Vector2(292, 476), &"run": Vector2(768, 390), &"jump": Vector2(870, 464),
}
const ACTION_FOR_CONTROL := {
	&"left": &"touch_move_left", &"right": &"touch_move_right",
	&"down": &"touch_crouch", &"jump": &"touch_jump",
}
const INK := Color("214d49")
const CREAM := Color("fff4d6")
const RUN_TEXTURE: Texture2D = preload("res://assets/art/ui/touch_run.svg")
const WALK_TEXTURE: Texture2D = preload("res://assets/art/ui/touch_walk.svg")

var auto_run := true
var _enabled := false
var _pointers: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _faces: Dictionary = {}
var _labels: Dictionary = {}
var _was_paused := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for action in TOUCH_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _ready() -> void:
	var font: Font = preload("res://assets/fonts/Rubik-Bold.ttf")
	for control: StringName in CENTERS:
		var face := Sprite2D.new()
		face.texture = load("res://assets/art/ui/touch_%s.svg" % control)
		face.position = CENTERS[control]
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(face)
		_faces[control] = face
		if control in [&"jump", &"run", &"down"]:
			var label := Label.new()
			label.position = CENTERS[control] + Vector2(-48, 10 if control == &"jump" else 8)
			label.size = Vector2(96, 23)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", 17 if control == &"jump" else 12)
			label.add_theme_color_override("font_color", CREAM if control == &"jump" else INK)
			label.text = "JUMP" if control == &"jump" else ("DROP" if control == &"down" else "RUN ON")
			add_child(label)
			_labels[control] = label
	_update_faces()


func set_enabled(value: bool) -> void:
	if value == _enabled:
		return
	_enabled = value
	visible = value
	if not value:
		release_all()


func release_all() -> void:
	_pointers.clear()
	for action in TOUCH_ACTIONS:
		if _pressed_actions.get(action, false):
			Input.action_release(action)
	_pressed_actions.clear()
	_update_faces()


func _exit_tree() -> void:
	release_all()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release_all()


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused and not _was_paused:
		release_all()
	_was_paused = paused


func _input(event: InputEvent) -> void:
	if not _enabled or get_tree().paused:
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if _pointers.has(event.index):
				_pointers.erase(event.index)
				_sync_actions()
				get_viewport().set_input_as_handled()
			return
		var control := _hit_control(point)
		if control.is_empty():
			return
		_pointers[event.index] = {
			"control": control,
			"direction": control in [&"left", &"right"],
		}
		if control == &"run":
			auto_run = not auto_run
		interaction_started.emit()
		_sync_actions()
		get_viewport().set_input_as_handled()
	elif _pointers.has(event.index):
		var pointer: Dictionary = _pointers[event.index]
		if pointer.direction:
			var control := _hit_direction(point)
			pointer.control = control
		_sync_actions()
		get_viewport().set_input_as_handled()


func _hit_control(point: Vector2) -> StringName:
	var direction := _hit_direction(point)
	if not direction.is_empty():
		return direction
	for control: StringName in [&"jump", &"run", &"down"]:
		var half_size := 56.0 if control == &"jump" else 44.0
		var offset: Vector2 = point - CENTERS[control]
		if absf(offset.x) <= half_size and absf(offset.y) <= half_size:
			return control
	return &""


func _hit_direction(point: Vector2) -> StringName:
	if Rect2(28, 416, 204, 96).has_point(point):
		return &"left" if point.x < 130.0 else &"right"
	return &""


func _sync_actions() -> void:
	var desired: Dictionary = {}
	for pointer: Dictionary in _pointers.values():
		var action: StringName = ACTION_FOR_CONTROL.get(pointer.control, &"")
		if not action.is_empty():
			desired[action] = true
	if auto_run and (desired.has(&"touch_move_left") or desired.has(&"touch_move_right")):
		desired[&"touch_sprint"] = true
	for action in TOUCH_ACTIONS:
		var pressed: bool = desired.get(action, false)
		if pressed != bool(_pressed_actions.get(action, false)):
			if pressed:
				Input.action_press(action)
			else:
				Input.action_release(action)
		_pressed_actions[action] = pressed
	_update_faces()


func _update_faces() -> void:
	for control: StringName in _faces:
		var pressed := false
		for pointer: Dictionary in _pointers.values():
			if pointer.control == control:
				pressed = true
		var face: Sprite2D = _faces[control]
		face.modulate.a = 1.0 if pressed else 0.76
		face.scale = Vector2.ONE * (0.94 if pressed else 1.0)
		if _labels.has(control):
			_labels[control].modulate.a = 1.0 if pressed else 0.86
	if _faces.has(&"run"):
		_faces[&"run"].texture = RUN_TEXTURE if auto_run else WALK_TEXTURE
		_labels[&"run"].text = "RUN ON" if auto_run else "WALK"
