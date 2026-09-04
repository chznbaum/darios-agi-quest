extends CharacterBody2D

signal health_changed(health: int)
signal died
signal power_changed(kind: String, remaining: float)

const WALK_SPEED := 260.0
const RUN_SPEED := 350.0
const GRAVITY := 1400.0
const JUMP_SPEED := -660.0
const COYOTE_DURATION := 0.12
const BUFFER_DURATION := 0.14

@export var max_health: int = 3
var health: int = 3
var shield_time: float = 0.0
var boost_time: float = 0.0
var input_enabled: bool = true
var spawn_point: Vector2
var invulnerable_time: float = 0.0
var is_dead: bool = false
var sprite: Sprite2D

var _visual: Node2D
var _shield_sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _current_frame := -1
var _coyote_time := 0.0
var _jump_buffer := 0.0
var _knockback_time := 0.0
var _animation_time := 0.0
var _power_signal_time := 0.0
var _facing := 1.0
var _squash_tween: Tween


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	floor_stop_on_slope = true
	spawn_point = global_position
	var art = load("res://scripts/art.gd")
	for index in range(4):
		_frames.append(art.texture(index))
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 48.0
	var collider := CollisionShape2D.new()
	collider.shape = capsule
	collider.position.y = -24.0
	add_child(collider)
	_visual = Node2D.new()
	add_child(_visual)
	_shield_sprite = Sprite2D.new()
	_shield_sprite.texture = art.texture(9)
	_shield_sprite.position.y = -29.0
	_shield_sprite.scale = Vector2.ONE * (72.0 / _shield_sprite.texture.get_height())
	_shield_sprite.modulate = Color(0.65, 0.95, 1.0, 0.48)
	_shield_sprite.visible = false
	_visual.add_child(_shield_sprite)
	sprite = Sprite2D.new()
	sprite.position.y = -32.0
	_visual.add_child(sprite)
	_set_frame(0)
	health_changed.emit(health)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_animation_time += delta
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	_knockback_time = maxf(0.0, _knockback_time - delta)
	_tick_powers(delta)
	var was_grounded := is_on_floor()
	if was_grounded:
		_coyote_time = COYOTE_DURATION
	else:
		_coyote_time = maxf(0.0, _coyote_time - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if input_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = BUFFER_DURATION

	var direction := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	var top_speed := RUN_SPEED if input_enabled and Input.is_action_pressed("sprint") else WALK_SPEED
	if boost_time > 0.0:
		top_speed *= 1.25
	var acceleration := 1850.0 if was_grounded else 1250.0
	if is_zero_approx(direction):
		acceleration = 2400.0 if was_grounded else 900.0
	if _knockback_time <= 0.0:
		velocity.x = move_toward(velocity.x, direction * top_speed, acceleration * delta)
	if not was_grounded:
		var fall_scale := 1.5 if input_enabled and Input.is_action_pressed("crouch") and velocity.y > 0.0 else 1.0
		velocity.y = minf(velocity.y + GRAVITY * fall_scale * delta, 900.0)
	if _jump_buffer > 0.0 and _coyote_time > 0.0:
		velocity.y = JUMP_SPEED * (1.10 if boost_time > 0.0 else 1.0)
		_coyote_time = 0.0
		_jump_buffer = 0.0
		_squash(Vector2(0.84, 1.12))
		_play_sound("jump")
	if input_enabled and Input.is_action_just_released("jump") and velocity.y < -190.0:
		velocity.y = -190.0
	var downward_speed := velocity.y
	move_and_slide()
	if not was_grounded and is_on_floor() and downward_speed > 150.0:
		_squash(Vector2(1.17, 0.82))
	if absf(velocity.x) > 5.0:
		_facing = signf(velocity.x)
	_update_visual()
	if global_position.y > 780.0:
		_die()


func take_hit(from_x: float) -> void:
	if is_dead or invulnerable_time > 0.0:
		return
	if shield_time > 0.0:
		shield_time = 0.0
		invulnerable_time = 0.8
		power_changed.emit("shield", 0.0)
		_play_sound("shield")
		_squash(Vector2(1.12, 1.12))
		return
	health = maxi(0, health - 1)
	health_changed.emit(health)
	if health <= 0:
		_die()
		return
	invulnerable_time = 1.4
	_knockback_time = 0.22
	var away := signf(global_position.x - from_x)
	if is_zero_approx(away):
		away = -_facing
	velocity = Vector2(away * 230.0, -290.0)
	_play_sound("hurt")
	_squash(Vector2(1.13, 0.9))


func bounce() -> void:
	if is_dead:
		return
	velocity.y = JUMP_SPEED * 0.82 if input_enabled and Input.is_action_pressed("jump") else -430.0
	_coyote_time = 0.0
	_jump_buffer = 0.0
	_squash(Vector2(0.83, 1.14))
	_play_sound("stomp")


func grant_power(kind: String) -> void:
	if is_dead:
		return
	match kind:
		"shield", "safety":
			shield_time = 12.0
			power_changed.emit("shield", shield_time)
			_play_sound("powerup")
		"coffee", "boost", "overclock":
			boost_time = 10.0
			power_changed.emit("boost", boost_time)
			_play_sound("powerup")
		"heart", "health":
			health = mini(health + 1, max_health)
			health_changed.emit(health)
			_play_sound("powerup")
	_squash(Vector2(1.15, 1.15))


func respawn(at: Vector2) -> void:
	global_position = at
	spawn_point = at
	velocity = Vector2.ZERO
	health = max_health
	shield_time = 0.0
	boost_time = 0.0
	invulnerable_time = 1.4
	_knockback_time = 0.0
	_coyote_time = 0.0
	_jump_buffer = 0.0
	is_dead = false
	input_enabled = true
	modulate = Color.WHITE
	health_changed.emit(health)
	power_changed.emit("shield", 0.0)
	power_changed.emit("boost", 0.0)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	input_enabled = false
	health = 0
	velocity = Vector2.ZERO
	health_changed.emit(health)
	_play_sound("death")
	died.emit()


func _tick_powers(delta: float) -> void:
	var previous_shield := shield_time
	var previous_boost := boost_time
	shield_time = maxf(0.0, shield_time - delta)
	boost_time = maxf(0.0, boost_time - delta)
	_power_signal_time -= delta
	if _power_signal_time <= 0.0:
		_power_signal_time = 0.1
		if shield_time > 0.0:
			power_changed.emit("shield", shield_time)
		if boost_time > 0.0:
			power_changed.emit("boost", boost_time)
	if previous_shield > 0.0 and shield_time <= 0.0:
		power_changed.emit("shield", 0.0)
	if previous_boost > 0.0 and boost_time <= 0.0:
		power_changed.emit("boost", 0.0)


func _update_visual() -> void:
	var frame := 0
	if not is_on_floor():
		frame = 3
	elif absf(velocity.x) > 25.0:
		frame = 1 + int(_animation_time * (14.0 if boost_time > 0.0 else 10.0)) % 2
	_set_frame(frame)
	sprite.flip_h = _facing < 0.0
	_visual.modulate.a = 0.45 if invulnerable_time > 0.0 and int(_animation_time * 14.0) % 2 == 0 else 1.0
	_shield_sprite.visible = shield_time > 0.0
	_shield_sprite.rotation = sin(_animation_time * 3.0) * 0.08
	sprite.modulate = Color(1.12, 0.95, 0.8) if boost_time > 0.0 else Color.WHITE


func _squash(amount: Vector2) -> void:
	if not is_instance_valid(_visual):
		return
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_visual.scale = amount
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visual, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_frame(index: int) -> void:
	if _current_frame == index:
		return
	_current_frame = index
	sprite.texture = _frames[index]
	sprite.scale = Vector2.ONE * (64.0 / sprite.texture.get_height())


func _play_sound(sound_name: String) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sound_name)
