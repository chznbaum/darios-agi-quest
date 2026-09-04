extends Node
## Plays the game's original, pre-rendered soundtrack and effects.

const MUSIC: Dictionary = {
	"title": preload("res://assets/audio/title.wav"),
	"meadow": preload("res://assets/audio/meadow.wav"),
	"boss": preload("res://assets/audio/boss.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
}
const EFFECTS: Dictionary = {
	"jump": preload("res://assets/audio/jump.wav"),
	"token": preload("res://assets/audio/token.wav"),
	"stomp": preload("res://assets/audio/stomp.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"powerup": preload("res://assets/audio/powerup.wav"),
	"checkpoint": preload("res://assets/audio/checkpoint.wav"),
	"select": preload("res://assets/audio/select.wav"),
	"death": preload("res://assets/audio/death.wav"),
	"shield": preload("res://assets/audio/shield.wav"),
	"boss_warn": preload("res://assets/audio/boss_warn.wav"),
	"boss_land": preload("res://assets/audio/boss_land.wav"),
	"boss_hit": preload("res://assets/audio/boss_hit.wav"),
	"boss_defeat": preload("res://assets/audio/boss_defeat.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
}

var is_muted: bool = false
var _music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _current_track: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	add_child(_music)
	for index in range(12):
		var player := AudioStreamPlayer.new()
		player.volume_db = -5.0
		add_child(player)
		_sfx_players.append(player)
	for track in MUSIC:
		var stream: AudioStreamWAV = MUSIC[track]
		if track != "victory":
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)


func play_music(track: String) -> void:
	if not MUSIC.has(track):
		push_warning("Unknown music track: " + track)
		return
	if _current_track == track and _music.playing:
		return
	_current_track = track
	_music.stream = MUSIC[track]
	_music.play()


func play_sfx(effect: String) -> void:
	if not EFFECTS.has(effect):
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = EFFECTS[effect]
	player.play()


func set_muted(value: bool) -> void:
	is_muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)


func _exit_tree() -> void:
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	for player in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_sfx_players.clear()
	_current_track = ""
	# stop() queues mixer cleanup. Let its final buffer drain before engine teardown.
	# Godot shutdown race: https://github.com/godotengine/godot/issues/76745
	OS.delay_msec(50)
