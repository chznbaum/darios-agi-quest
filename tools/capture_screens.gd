extends SceneTree

func _initialize() -> void:
 call_deferred('_run')

func _capture(name: String) -> void:
 for i in range(3): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png('res://screenshots/' + name + '.png')

func _run() -> void:
 root.size = Vector2i(960,540)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
 var preview_script = GDScript.new()
 preview_script.source_code = "extends 'res://scripts/main.gd'\nfunc _load_save() -> void:\n\tpass\nfunc _save() -> void:\n\tpass\n"
 if preview_script.reload() != OK:
  quit(1)
  return
 var game = preview_script.new()
 root.add_child(game)
 await _capture('title')
 game._show_map()
 await _capture('world-map')
 game._start_level()
 for i in range(20): await physics_frame
 await _capture('token-meadow')
 game.player.position = Vector2(2040,328)
 game.player.velocity = Vector2.ZERO
 game.camera.position = Vector2(2150,270)
 for i in range(4): await physics_frame
 await _capture('high-route')
 game.player.position = Vector2(5360,430)
 game.camera.position = Vector2(5510,270)
 for i in range(4): await physics_frame
 await _capture('sam-boss')
 game._finish_level()
 await create_timer(0.65).timeout
 await _capture('ending')
 game.queue_free()
 await process_frame
 print('Saved six game screenshots.')
 quit()
