extends SceneTree

# Build the subclass after SceneTree has registered the Audio autoload. Loading
# main.gd at parse time under --script happens before autoload names exist.
const ISOLATED_APP_SOURCE := """extends "res://scripts/main.gd"
var save_requests := 0
func _load_save() -> void:
	muted = true
func _save() -> void:
	save_requests += 1
"""


var _failures: Array[String] = []
var _checks := 0
var _app
const PICKUP_SCRIPT = preload("res://scripts/pickup.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var isolated_app_script := GDScript.new()
	isolated_app_script.source_code = ISOLATED_APP_SOURCE
	if isolated_app_script.reload() != OK:
		push_error("Unable to compile the isolated flow-test controller")
		quit(1)
		return
	_app = isolated_app_script.new()
	root.add_child(_app)
	await process_frame
	_check(_app.state == "title" and _app.world == null, "Launch opens the title without a running level")
	_check(not _app.level_cleared and _app.best_tokens == 0 and _app.best_insights == 0 and _app.muted, "The test starts from isolated progress without loading the player's save")
	_check(_app.title_hero.size.is_equal_approx(Vector2(147, 212)), "Title hero respects its intended size instead of the source atlas size")
	_press("How to play")
	_check(is_instance_valid(_app.pause_panel), "How to play opens its control overlay")
	_press("Got it!")
	_check(_app.pause_panel == null, "Got it closes the control overlay")
	_press("LET’S GO")
	await process_frame
	_check(_app.state == "map" and _app.selected_map == 0, "Title button opens the playable world-map node")
	_check(_app.map_hero.size.is_equal_approx(Vector2(48, 66)), "World-map hero stays within its marker size")
	_press("…")
	_check(_app.selected_map == 1 and _find_button("BACK TO 1–1") != null, "Future chapter displays its return action")
	_press("BACK TO 1–1")
	_press("ENTER LEVEL")
	await process_frame
	_freeze_player()
	_check(_app.state == "level" and is_instance_valid(_app.world), "Enter level creates the playable world")
	_check(_app.tokens == 0 and _app.insights == 0 and _app.player.health == 3, "New run begins with empty counters and three hearts")
	_check(_pickups("token").size() == 72 and _pickups("insight").size() == 3, "The level contains 72 route tokens and three hidden insights")
	_check(_pickups("shield").size() == 2 and _pickups("coffee").size() == 1 and _pickups("heart").size() == 2, "The route includes both powers and two recovery hearts")
	for heart in _app.hud_hearts:
		_check(heart.size.is_equal_approx(Vector2(27, 26)), "HUD heart respects its small icon bounds")

	var token = _pickups("token")[0]
	token._on_body(_app.player)
	token._on_body(_app.player)
	_check(_app.tokens == 1 and _app.hud_tokens.text == "001", "A token updates its HUD once even if contact is reported twice")
	for insight in _pickups("insight"):
		insight._on_body(_app.player)
	_check(_app.insights == 3 and _app.hud_insights.text == "3 / 3", "All three insight pickups update the completion counter")
	_pickups("shield")[0]._on_body(_app.player)
	_pickups("coffee")[0]._on_body(_app.player)
	_app.player.health = 2
	_pickups("heart")[0]._on_body(_app.player)
	_check(_app.player.shield_time == 12.0 and _app.player.boost_time == 10.0 and _app.player.health == 3, "Power and heart pickups grant their gameplay effects through the controller")
	await process_frame
	_check(_pickups("token").size() == 71 and _pickups("insight").is_empty(), "Claimed pickups leave the level")

	_press("Pause")
	var paused_elapsed: float = _app.elapsed
	await create_timer(0.06).timeout
	_check(paused and is_instance_valid(_app.pause_panel) and _app.elapsed == paused_elapsed, "Pause opens its overlay and stops the run clock")
	_press("KEEP GOING")
	_check(not paused and _app.pause_panel == null, "Keep going resumes the game")
	_press("Pause")
	var old_world = _app.world
	_press("Restart level")
	await process_frame
	_freeze_player()
	_check(not paused and _app.state == "level" and not is_instance_valid(old_world), "Restart from pause replaces the old world and unpauses")
	_check(_app.tokens == 0 and _app.insights == 0 and _pickups("token").size() == 72, "Restart restores pickups and clears the run counters")
	_check(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("boss").size() == 1, "Restart leaves exactly one player and one boss in the scene tree")

	# Follow a normal 660 px/s jump from the highest platform at 184 px.
	_app.camera.position.y = 270.0
	var smallest_screen_top := INF
	for frame in range(30):
		var t := float(frame + 1) / 60.0
		_app.player.position = Vector2(1214, 184.0 - 660.0 * t + 700.0 * t * t)
		_app._process(1.0 / 60.0)
		smallest_screen_top = minf(smallest_screen_top, _app.player.position.y - 64.0 - _app.camera.position.y + 270.0)
	_check(smallest_screen_top >= 0.0, "Vertical camera movement keeps the upper-route jump inside the viewport")
	_app.player.position = Vector2(120, 440)

	var route_tokens := _pickups("token")
	route_tokens[0]._on_body(_app.player)
	route_tokens[1]._on_body(_app.player)
	_pickups("insight")[0]._on_body(_app.player)
	await process_frame
	_app.player.position = Vector2(5300, 440)
	_app._process(1.0 / 60.0)
	_app.boss.set_physics_process(false)
	_check(_app.boss_started and _app.boss_bar.visible and _app.checkpoint.x == 5085, "Entering the arena starts the boss and records the nearby checkpoint")
	var reward_count_before := _pickups("token").size()
	for stomp in range(3):
		_app.player.position = _app.boss.position + Vector2(0, -64)
		_app.player.velocity.y = 300.0
		_app.boss._invulnerable_time = 0.0
		_app.boss._check_player_contact()
	_check(_app.boss_beaten and not _app.boss_bar.visible, "Three actual boss contacts notify the controller of victory")
	_check(_pickups("token").size() == reward_count_before + 8, "Defeating the boss releases eight reward tokens")
	_app.player.position = Vector2(5900, 440)
	_app.player.velocity = Vector2.ZERO
	_app._process(1.0 / 60.0)
	_check(_app.transitioning and not _app.player.input_enabled, "Entering the castle starts the completion transition")
	await create_timer(0.65).timeout
	_check(_app.state == "result" and _app.world == null, "Castle completion replaces gameplay with the result screen")
	_check(_app.level_cleared and _app.best_tokens == 2 and _app.best_insights == 1 and _app.save_requests == 1, "Completion records run totals while the test intercepts the save write")
	_check(_contains_label("But AGI is in another castle."), "The result screen reveals the next-castle ending")
	_press("WORLD MAP")
	_check(_app.state == "map" and _find_button("PLAY AGAIN") != null, "Result returns to the world map with replay enabled")
	_press("PLAY AGAIN")
	_freeze_player()

	# A delayed callback from an abandoned run must not touch its replacement.
	_app._finish_level()
	_press("Pause")
	_press("Restart level")
	_freeze_player()
	var replacement_player = _app.player
	var replacement_run: int = _app.run_id
	await create_timer(0.65).timeout
	_check(_app.state == "level" and _app.player == replacement_player and _app.run_id == replacement_run, "Restart during the victory delay does not finish the replacement run")
	_check(not _app.transitioning and _app.player.input_enabled, "Restart during victory restores input and clears transition state")

	_app.player._die()
	_check(_app.death_pending, "Player death starts the delayed respawn")
	_press("Pause")
	_press("Restart level")
	_freeze_player()
	_app.player.position = Vector2(400, 430)
	replacement_player = _app.player
	await create_timer(0.95).timeout
	_check(_app.player == replacement_player and is_equal_approx(_app.player.position.x, 400.0), "Restart during the death delay prevents an old respawn from moving the new player")
	_check(not _app.death_pending and not _app.player.is_dead and _app.player.health == 3, "Replacement run remains alive with no pending death")
	_press("Pause")
	_press("World map")
	_check(_app.state == "map" and not paused and _app.world == null, "Pause-menu world map abandons the level and unpauses the tree")

	_app.queue_free()
	await process_frame
	# Rapid screen changes enqueue several mixer stop/start operations. Destroy
	# audio while the tree still advances so its final buffers can be released.
	var audio := root.get_node_or_null("Audio")
	if is_instance_valid(audio):
		audio.queue_free()
	await create_timer(0.2).timeout
	await process_frame
	if _failures.is_empty():
		print("PASS: %d flow checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d of %d flow checks" % [_failures.size(), _checks])
		quit(1)


func _freeze_player() -> void:
	_app.player.set_physics_process(false)
	_app.player.velocity = Vector2.ZERO


func _pickups(kind: String) -> Array[Node]:
	var matches: Array[Node] = []
	for child in _app.world.get_children():
		if child.get_script() == PICKUP_SCRIPT and child.kind == kind and not child.is_queued_for_deletion():
			matches.append(child)
	return matches


func _find_button(text: String) -> Button:
	for node in _app.screen.find_children("*", "Button", true, false):
		if node.text == text or node.accessibility_name == text:
			return node
	return null


func _press(text: String) -> void:
	var button := _find_button(text)
	_check(is_instance_valid(button), "Screen exposes button: " + text)
	if is_instance_valid(button):
		button.pressed.emit()


func _contains_label(text: String) -> bool:
	for node in _app.screen.find_children("*", "Label", true, false):
		if text in node.text:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
