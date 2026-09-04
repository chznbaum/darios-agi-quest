extends CharacterBody2D

signal defeated
signal health_changed(value: int)

enum State { REST, TELEGRAPH, LEAP, DEFEATED }

@export var arena_left: float = 0.0
@export var arena_right: float = 0.0
var health: int = 3
var state: State = State.REST

var _sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _state_time := 1.6
var _invulnerable_time := 0.0
var _animation_time := 0.0
var _leap_direction := -1.0
var _body_scale := Vector2.ONE


func _ready() -> void:
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	if is_equal_approx(arena_left, arena_right):
		arena_left = global_position.x - 220.0
		arena_right = global_position.x + 220.0
	var art = load("res://scripts/art.gd")
	_frames.append(art.texture(12))
	_frames.append(art.texture(13))
	var shape := CapsuleShape2D.new()
	shape.radius = 22.0
	shape.height = 65.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position.y = -32.5
	add_child(collider)
	_sprite = Sprite2D.new()
	_sprite.texture = _frames[0]
	_sprite.position.y = -40.0
	_body_scale = Vector2.ONE * (80.0 / _sprite.texture.get_height())
	_sprite.scale = _body_scale
	add_child(_sprite)
	health_changed.emit(health)


func _physics_process(delta: float) -> void:
	if state == State.DEFEATED:
		return
	_animation_time += delta
	_invulnerable_time = maxf(0.0, _invulnerable_time - delta)
	_state_time -= delta
	var was_grounded := is_on_floor()
	velocity.y = minf(velocity.y + 1400.0 * delta, 850.0)
	match state:
		State.REST:
			velocity.x = move_toward(velocity.x, 0.0, delta * 1300.0)
			if _state_time <= 0.0:
				state = State.TELEGRAPH
				_state_time = 0.7
				_play_sound("boss_warn")
		State.TELEGRAPH:
			velocity.x = 0.0
			if _state_time <= 0.0 and was_grounded:
				_start_leap()
		State.LEAP:
			if global_position.x <= arena_left + 28.0:
				velocity.x = absf(velocity.x)
			elif global_position.x >= arena_right - 28.0:
				velocity.x = -absf(velocity.x)
	move_and_slide()
	if state == State.LEAP and not was_grounded and is_on_floor():
		state = State.REST
		_state_time = 2.0
		velocity.x = 0.0
		_play_sound("boss_land")
	_update_visual()
	_check_player_contact()


func _start_leap() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		_leap_direction = signf(player.global_position.x - global_position.x)
	if is_zero_approx(_leap_direction):
		_leap_direction = -1.0
	velocity = Vector2(_leap_direction * (160.0 + (3 - health) * 22.0), -510.0)
	state = State.LEAP
	_state_time = 3.0


func _check_player_contact() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player) or player.get("is_dead") == true:
		return
	var offset := player.global_position - global_position
	if absf(offset.x) > 36.0:
		return
	var head_y := global_position.y - 65.0
	if player.velocity.y > 0.0 and player.global_position.y >= head_y - 10.0 and player.global_position.y <= head_y + 21.0:
		player.bounce()
		if _invulnerable_time <= 0.0:
			_take_stomp()
	elif offset.y >= -59.0 and offset.y <= 43.0:
		player.take_hit(global_position.x)


func _take_stomp() -> void:
	health = maxi(0, health - 1)
	health_changed.emit(health)
	_invulnerable_time = 1.0
	if health == 0:
		state = State.DEFEATED
		collision_layer = 0
		velocity = Vector2.ZERO
		_play_sound("boss_defeat")
		defeated.emit()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_sprite, "rotation", -0.18, 0.25)
		tween.tween_property(_sprite, "position:y", -27.0, 0.25)
		tween.tween_property(_sprite, "scale", _body_scale * Vector2(1.12, 0.8), 0.25)
		return
	state = State.REST
	_state_time = 2.0
	velocity.x = 0.0
	_play_sound("boss_hit")


func _update_visual() -> void:
	_sprite.texture = _frames[1 if state == State.TELEGRAPH or state == State.LEAP else 0]
	_body_scale = Vector2.ONE * (80.0 / _sprite.texture.get_height())
	_sprite.modulate.a = 0.45 if _invulnerable_time > 0.0 and int(_animation_time * 12.0) % 2 == 0 else 1.0
	_sprite.flip_h = _leap_direction > 0.0
	if state == State.TELEGRAPH:
		_sprite.scale = _body_scale * Vector2(1.0 + sin(_animation_time * 26.0) * 0.05, 0.9)
	elif state == State.LEAP:
		_sprite.scale = _body_scale * Vector2(0.94, 1.05)
	else:
		_sprite.scale = _body_scale


func _play_sound(sound_name: String) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sound_name)
