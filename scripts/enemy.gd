extends CharacterBody2D

signal defeated(at: Vector2)

@export_enum("bug", "cloud") var kind: String = "bug"
@export var patrol_left: float = 0.0
@export var patrol_right: float = 0.0

var _sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _direction := -1.0
var _age := 0.0
var _hover_y := 0.0
var _is_defeated := false
var _spawn_grace := 0.15


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_hover_y = global_position.y
	_age = fmod(absf(global_position.x) * 0.02, TAU)
	if is_equal_approx(patrol_left, patrol_right):
		patrol_left = global_position.x - 90.0
		patrol_right = global_position.x + 90.0
	var art = load("res://scripts/art.gd")
	var first_frame := 4 if kind == "bug" else 6
	_frames.append(art.texture(first_frame))
	_frames.append(art.texture(first_frame + 1))
	var shape := RectangleShape2D.new()
	shape.size = Vector2(35.0, 32.0 if kind == "bug" else 30.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position.y = -16.0
	add_child(collider)
	_sprite = Sprite2D.new()
	_sprite.texture = _frames[0]
	_sprite.position.y = -24.0 if kind == "bug" else -27.0
	_sprite.scale = Vector2.ONE * ((48.0 if kind == "bug" else 54.0) / _sprite.texture.get_height())
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	_age += delta
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	if global_position.x <= patrol_left:
		_direction = 1.0
	elif global_position.x >= patrol_right:
		_direction = -1.0
	if kind == "bug":
		if is_on_wall():
			_direction *= -1.0
		if is_on_floor() and not _ground_ahead():
			_direction *= -1.0
		velocity.x = _direction * 52.0
		velocity.y = minf(velocity.y + 1400.0 * delta, 700.0)
		move_and_slide()
	else:
		velocity.x = _direction * 66.0
		velocity.y = ((_hover_y + sin(_age * 2.0) * 15.0) - global_position.y) * 7.0
		move_and_slide()
		if is_on_wall():
			_direction *= -1.0
	var frame := int(_age * 5.0) % 2
	_sprite.texture = _frames[frame]
	_sprite.scale = Vector2.ONE * ((48.0 if kind == "bug" else 54.0) / _sprite.texture.get_height())
	_sprite.flip_h = _direction > 0.0
	if _spawn_grace <= 0.0:
		_check_player_contact()
	if global_position.y > 850.0:
		queue_free()


func _check_player_contact() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player) or player.get("is_dead") == true:
		return
	var offset := player.global_position - global_position
	if absf(offset.x) > (31.0 if kind == "bug" else 34.0):
		return
	var head_y := global_position.y - 32.0
	if player.velocity.y > 0.0 and player.global_position.y >= head_y - 9.0 and player.global_position.y <= head_y + 17.0:
		player.bounce()
		_defeat()
	elif offset.y >= -31.0 and offset.y <= 43.0:
		player.take_hit(global_position.x)


func _defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	collision_layer = 0
	velocity = Vector2.ZERO
	defeated.emit(global_position)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _sprite.scale * Vector2(1.25, 0.25), 0.12)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.23).set_delay(0.08)
	tween.chain().tween_callback(queue_free)


func _ground_ahead() -> bool:
	var start := global_position + Vector2(_direction * 25.0, -10.0)
	var query := PhysicsRayQueryParameters2D.create(start, start + Vector2(0.0, 33.0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

