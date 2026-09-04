extends SceneTree


var _failures: Array[String] = []
var _checks := 0
var _input_strengths: Dictionary = {}
var _crossed_gaps := [false, false, false]
var _phase := "traverse"
var _intentional_death := false
var _arena_reset_verified := false
var _stomps := 0
var _previous_boss_health := 3
var _last_report_x := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox_script := GDScript.new()
	sandbox_script.source_code = "extends \"res://scripts/main.gd\"\nvar save_calls := 0\nfunc _load_save() -> void:\n\tpass\nfunc _save() -> void:\n\tsave_calls += 1\n"
	if sandbox_script.reload() != OK:
		push_error("Could not load the test subclass after autoload initialization.")
		quit(1)
		return
	var game = sandbox_script.new()
	root.add_child(game)
	game._start_level()
	print("Traversal: following the ground route with movement and jump actions.")
	for frame in range(18000):
		await physics_frame
		await process_frame
		if game.state == "result":
			break
		if game.state != "level" or not is_instance_valid(game.player):
			_check(false, "The run remains playable until the result screen")
			break
		var player = game.player
		_track_gaps(player)
		if player.position.x >= _last_report_x + 1000.0:
			_last_report_x = player.position.x
			print("Traversal: x=%d, health=%d, deaths=%d" % [player.position.x, player.health, game.deaths])
		match _phase:
			"traverse":
				if player.is_dead:
					_check(false, "The ground route crosses all gaps without dying")
					break
				if game.boss_started:
					_check(game.checkpoint_reached, "The meadow checkpoint is reached through movement")
					_check(game.checkpoint.x > 5000.0, "The boss checkpoint is reached through movement")
					_phase = "deliberate_death"
					print("Traversal: arena entered; testing a real contact death and checkpoint restart.")
				else:
					_drive_ground_route(game)
			"deliberate_death":
				_action("jump", 0.0)
				_action("sprint", 0.0)
				if player.is_dead:
					_intentional_death = true
					_phase = "await_respawn"
					_release_input()
				else:
					_steer_to(player, game.boss.position.x)
			"await_respawn":
				if not player.is_dead and not game.death_pending:
					_check(absf(player.position.x - 5085.0) < 8.0, "A boss death returns to the nearby checkpoint")
					_check(not game.boss_started and game.boss.health == 3, "Respawning resets the arena and boss")
					_check(player.health == 3 and player.input_enabled, "Checkpoint respawn restores health and movement")
					_arena_reset_verified = true
					_phase = "fight"
					_previous_boss_health = 3
					print("Traversal: checkpoint restart verified; approaching Sam for three real stomps.")
			"fight":
				if player.is_dead:
					_check(false, "The boss is beatable through descending stomps after the checkpoint restart")
					break
				if game.boss.health < _previous_boss_health:
					_stomps += _previous_boss_health - game.boss.health
					_previous_boss_health = game.boss.health
					print("Traversal: real stomp %d, Sam health=%d" % [_stomps, game.boss.health])
				if game.boss_beaten:
					_phase = "castle"
					_action("jump", 0.0)
				else:
					_drive_boss_fight(game)
			"castle":
				_action("move_left", 0.0)
				_action("move_right", 1.0)
				_action("sprint", 1.0)
		if not _failures.is_empty():
			break
	_release_input()
	_check(_crossed_gaps.all(func(crossed): return crossed), "Actual jumps cross each of the three ground gaps")
	_check(_intentional_death and _arena_reset_verified, "A real arena death recovers without a softlock")
	_check(_stomps == 3, "Three actual descending collisions defeat Sam")
	_check(game.state == "result" and game.level_cleared, "Walking into the castle reaches the completed result screen")
	_check(game.best_tokens > 0, "The completed run records collected tokens")
	_check(game.save_calls > 0, "Completion invokes the overridden save without changing user progress")
	if _failures.is_empty():
		await _verify_high_route(game)
	game.queue_free()
	await process_frame
	var audio := root.get_node_or_null("Audio")
	if audio:
		audio.queue_free()
	await process_frame
	var mixer_drain_deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < mixer_drain_deadline:
		await process_frame
	if _failures.is_empty():
		print("PASS: %d full-level traversal checks (3 gaps, arena restart, 3 real stomps, castle, 3 high-route insights)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d of %d traversal checks, phase=%s." % [_failures.size(), _checks, _phase])
		quit(1)


func _verify_high_route(game: Node) -> void:
	_phase = "high_route"
	game._start_level()
	print("Traversal: beginning a second input-only run to collect all three high-route insights.")
	var hops := [
		[570.0, Vector2(716.0, 328.0)],
		[780.0, Vector2(976.0, 240.0)],
		[1040.0, Vector2(1214.0, 192.0)],
		[1830.0, Vector2(1976.0, 328.0)],
		[2050.0, Vector2(2175.0, 248.0)],
		[2180.0, Vector2(2442.0, 184.0)],
		[2850.0, Vector2(2996.0, 328.0)],
		[3080.0, Vector2(3226.0, 240.0)],
		[3310.0, Vector2(3472.0, 192.0)]
	]
	for index in range(hops.size()):
		if not await _walk_to(game, hops[index][0]):
			return
		print("Traversal: high-route hop %d starts at (%d, %d), health=%d." % [index + 1, game.player.position.x, game.player.position.y, game.player.health])
		if not await _jump_to(game, hops[index][1]):
			return
		if index % 3 == 2:
			if not await _walk_to(game, hops[index][1].x):
				return
			_check(game.insights == (index + 1) / 3, "The high route collects insight %d through a real pickup collision" % ((index + 1) / 3))
			print("Traversal: high-route insight %d collected." % game.insights)
	_check(game.insights == 3 and game.deaths == 0, "All three insights are reachable in one continuous run without dying")
	_release_input()


func _walk_to(game: Node, target_x: float) -> bool:
	_action("sprint", 0.0)
	_action("jump", 0.0)
	for frame in range(600):
		await physics_frame
		await process_frame
		var player = game.player
		if player.is_dead:
			_check(false, "The high route remains alive while approaching x=%d" % target_x)
			return false
		_steer_to(player, target_x)
		if absf(player.position.x - target_x) < 4.0 and absf(player.velocity.x) < 35.0 and player.is_on_floor():
			return true
	_check(false, "High-route approach timed out at x=%d toward x=%d" % [game.player.position.x, target_x])
	return false


func _jump_to(game: Node, target: Vector2) -> bool:
	_action("sprint", 1.0 if target.x - game.player.position.x > 190.0 else 0.0)
	_action("jump", 1.0)
	var became_airborne := false
	for frame in range(240):
		await physics_frame
		await process_frame
		var player = game.player
		if player.is_dead:
			_check(false, "A high-route jump died at (%d, %d) toward (%d, %d)" % [player.position.x, player.position.y, target.x, target.y])
			return false
		if not player.is_on_floor():
			became_airborne = true
		_steer_to(player, target.x)
		if became_airborne and player.is_on_floor():
			_action("jump", 0.0)
			var landed_on_target := absf(player.position.y - target.y) < 2.0 and absf(player.position.x - target.x) < 86.0
			_check(landed_on_target, "A real jump lands on the high-route platform near (%d, %d); actual (%d, %d)" % [target.x, target.y, player.position.x, player.position.y])
			return landed_on_target
	_check(false, "High-route jump timed out toward (%d, %d)" % [target.x, target.y])
	return false


func _drive_ground_route(game: Node) -> void:
	var player = game.player
	_action("move_left", 0.0)
	_action("move_right", 1.0)
	_action("sprint", 1.0)
	if not player.is_on_floor():
		return
	if Input.is_action_pressed("jump"):
		_action("jump", 0.0)
		return
	var jump_needed := false
	for edge in [1250.0, 2400.0, 3600.0]:
		var distance: float = edge - player.position.x
		if distance > 0.0 and distance < 145.0:
			jump_needed = true
	for enemy in get_nodes_in_group("enemies"):
		if enemy.get("_is_defeated"):
			continue
		var distance: float = enemy.position.x - player.position.x
		if distance > 0.0 and distance < 125.0 and absf(enemy.position.y - player.position.y) < 70.0:
			jump_needed = true
	_action("jump", 1.0 if jump_needed else 0.0)


func _drive_boss_fight(game: Node) -> void:
	var player = game.player
	var boss = game.boss
	_action("sprint", 0.0)
	_steer_to(player, boss.position.x + boss.velocity.x * 0.15)
	if player.is_on_floor():
		if Input.is_action_pressed("jump"):
			_action("jump", 0.0)
		elif absf(boss.position.x - player.position.x) < 165.0:
			_action("jump", 1.0)
	else:
		_action("jump", 1.0)


func _steer_to(player: CharacterBody2D, target_x: float) -> void:
	var direction := clampf((target_x - player.position.x - player.velocity.x * 0.18) / 65.0, -1.0, 1.0)
	_action("move_left", maxf(0.0, -direction))
	_action("move_right", maxf(0.0, direction))


func _track_gaps(player: CharacterBody2D) -> void:
	var gap_ends := [1350.0, 2530.0, 3730.0]
	for index in range(gap_ends.size()):
		if player.position.x > gap_ends[index] + 14.0 and player.position.y < 450.0:
			_crossed_gaps[index] = true


func _action(action: String, strength: float) -> void:
	if is_equal_approx(float(_input_strengths.get(action, 0.0)), strength):
		return
	_input_strengths[action] = strength
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release_input() -> void:
	for action in ["move_left", "move_right", "sprint", "jump"]:
		_action(action, 0.0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
