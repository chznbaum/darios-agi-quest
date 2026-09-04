extends SceneTree

var _failures: Array[String] = []
var _checks := 0
var _death_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := root.get_node_or_null("Audio")
	if audio:
		audio.free()
	for action in ["move_left", "move_right", "jump", "sprint", "crouch"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0.0, 460.0)
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(1000.0, 40.0)
	var floor_collision := CollisionShape2D.new()
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	stage.add_child(floor_body)
	var player = load("res://scripts/player.gd").new()
	player.position = Vector2(0.0, 430.0)
	stage.add_child(player)
	player.died.connect(func(): _death_count += 1)
	await _step_frames(12)
	_check(player.is_on_floor(), "Player settles on solid ground")
	Input.action_press("move_right")
	await _step_frames(12)
	_check(player.velocity.x > 240.0, "Movement accelerates to walk speed")
	Input.action_press("sprint")
	await _step_frames(8)
	_check(player.velocity.x > 335.0, "Sprint reaches its higher speed")
	Input.action_release("sprint")
	Input.action_release("move_right")
	await _step_frames(12)
	_check(absf(player.velocity.x) < 1.0, "Ground friction stops movement without sliding")

	player.respawn(Vector2(486.0, 439.0))
	await _step_frames(4)
	Input.action_press("move_right")
	for frame in range(20):
		await _step_frames(1)
		if not player.is_on_floor():
			break
	_check(not player.is_on_floor(), "Coyote scenario leaves the actual platform edge")
	Input.action_press("jump")
	await _step_frames(1)
	_check(player.velocity.y < -450.0, "Coyote jump succeeds after leaving a ledge")
	Input.action_release("jump")
	Input.action_release("move_right")
	await _step_frames(1)
	_check(player.velocity.y >= -190.0, "Releasing jump shortens the jump")

	player.respawn(Vector2(0.0, 395.0))
	player.velocity.y = 250.0
	for frame in range(15):
		await _step_frames(1)
		if player.position.y >= 425.0:
			break
	_check(not player.is_on_floor(), "Buffered jump is pressed while airborne")
	Input.action_press("jump")
	await _step_frames(4)
	_check(player.velocity.y < -400.0, "Jump buffer triggers immediately after landing")
	Input.action_release("jump")

	player.respawn(Vector2(-100.0, 439.0))
	await _step_frames(4)
	Input.action_press("jump")
	var normal_apex: float = player.position.y
	for frame in range(32):
		await _step_frames(1)
		normal_apex = minf(normal_apex, player.position.y)
	_check(440.0 - normal_apex >= 140.0 and 440.0 - normal_apex <= 165.0, "Holding a normal jump reaches approximately 150 pixels")
	Input.action_release("jump")
	player.respawn(Vector2(-100.0, 439.0))
	await _step_frames(4)
	player.grant_power("coffee")
	Input.action_press("jump")
	var boosted_apex: float = player.position.y
	for frame in range(35):
		await _step_frames(1)
		boosted_apex = minf(boosted_apex, player.position.y)
	_check(normal_apex - boosted_apex > 25.0, "Overclock coffee produces a meaningfully higher jump")
	Input.action_release("jump")

	var high_platform := StaticBody2D.new()
	high_platform.position = Vector2(230.0, 348.0)
	var platform_shape := RectangleShape2D.new()
	platform_shape.size = Vector2(160.0, 40.0)
	var platform_collision := CollisionShape2D.new()
	platform_collision.shape = platform_shape
	high_platform.add_child(platform_collision)
	stage.add_child(high_platform)
	player.respawn(Vector2(80.0, 439.0))
	await _step_frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _step_frames(49)
	_check(player.is_on_floor() and absf(player.position.y - 328.0) < 1.0, "Normal movement can land on the level's 112-pixel platform step")
	Input.action_release("jump")
	Input.action_release("move_right")

	player.set_physics_process(false)
	player.respawn(Vector2(0.0, 440.0))
	player.invulnerable_time = 0.0
	player.take_hit(-30.0)
	_check(player.health == 2 and player.velocity.x > 0.0, "Side contact removes one heart and knocks away")
	player.take_hit(-30.0)
	_check(player.health == 2, "Damage invulnerability prevents repeated damage")
	player.invulnerable_time = 0.0
	player.grant_power("shield")
	player.take_hit(30.0)
	_check(player.health == 2 and player.shield_time == 0.0, "Safety shield absorbs and consumes one contact")
	player.grant_power("coffee")
	_check(player.boost_time == 10.0, "Coffee grants overclock boost")
	player.grant_power("heart")
	_check(player.health == 3, "Heart restores health")
	player.grant_power("heart")
	_check(player.health == player.max_health, "Health cannot exceed its maximum")
	player._tick_powers(11.0)
	_check(player.boost_time == 0.0, "Timed powers expire")

	var enemy = load("res://scripts/enemy.gd").new()
	enemy.position = Vector2(150.0, 440.0)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	player.global_position = Vector2(150.0, 410.0)
	player.velocity.y = 300.0
	enemy._check_player_contact()
	_check(enemy._is_defeated and player.velocity.y < 0.0, "Landing on an enemy defeats it and bounces the player")
	Input.action_press("jump")
	player.bounce()
	_check(player.velocity.y < -530.0, "Holding jump makes a stomp bounce higher")
	Input.action_release("jump")

	var boss = load("res://scripts/boss.gd").new()
	boss.position = Vector2(300.0, 440.0)
	stage.add_child(boss)
	boss.set_physics_process(false)
	for stomp in range(3):
		player.global_position = Vector2(300.0, 376.0)
		player.velocity.y = 300.0
		boss._invulnerable_time = 0.0
		boss._check_player_contact()
	_check(boss.health == 0 and boss.state == boss.State.DEFEATED, "Three descending stomps defeat the boss")

	player.health = 1
	player.invulnerable_time = 0.0
	player.take_hit(0.0)
	player.take_hit(0.0)
	player._die()
	_check(_death_count == 1 and player.is_dead, "Death emits only once despite repeated contacts")
	player.respawn(Vector2(10.0, 440.0))
	_check(player.health == 3 and not player.is_dead and player.input_enabled, "Respawn restores playable state")
	_check(player.global_position == Vector2(10.0, 440.0) and player.velocity == Vector2.ZERO, "Respawn restores checkpoint position and clears motion")
	_check(player.shield_time == 0.0 and player.boost_time == 0.0 and player.invulnerable_time > 0.0, "Respawn clears powers and grants protection")
	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: %d gameplay checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d of %d gameplay checks" % [_failures.size(), _checks])
		quit(1)


func _step_frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
