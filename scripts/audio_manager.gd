extends Node
## Sound effects and water ambience (all CC0, see CREDITS.md), on separate
## "Music" and "SFX" buses so players can mute or turn each down in Settings.
## Settings persist in user://settings.cfg.

const SFX := "res://assets/third_party/sfx/"
const SETTINGS_PATH := "user://settings.cfg"

var ambient_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}

var music_on := true
var music_volume := 0.6      # 0..1
var sfx_on := true
var sfx_volume := 0.8
var fullscreen := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	var files := {
		"click": "click_002", "select": "select_003", "success": "confirmation_002", "cast": "drop_002",
		"levelup": "maximize_006", "strike": "pluck_001", "error": "error_004",
		"splash": ["splash_02", "splash_05", "splash_09"], "splash_big": "splash_12",
		"bubble": ["bubble_01", "bubble_02"],
	}
	for k in files:
		var v = files[k]
		sounds[k] = []
		for n in (v if v is Array else [v]):
			var s = load(SFX + n + ".ogg")
			if s: sounds[k].append(s)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Music"
	var amb = load(SFX + "loop_water_01.ogg")
	if amb:
		amb.loop = true
		ambient_player.stream = amb
		ambient_player.volume_db = -14.0
		add_child(ambient_player)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	load_settings()
	apply_settings()
	if amb: ambient_player.play()

# ---------------------------------------------------------------- settings
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK: return
	music_on = cf.get_value("audio", "music_on", music_on)
	music_volume = cf.get_value("audio", "music_volume", music_volume)
	sfx_on = cf.get_value("audio", "sfx_on", sfx_on)
	sfx_volume = cf.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = cf.get_value("display", "fullscreen", fullscreen)

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music_on", music_on)
	cf.set_value("audio", "music_volume", music_volume)
	cf.set_value("audio", "sfx_on", sfx_on)
	cf.set_value("audio", "sfx_volume", sfx_volume)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.save(SETTINGS_PATH)

func apply_settings() -> void:
	_set_bus("Music", music_on, music_volume)
	_set_bus("SFX", sfx_on, sfx_volume)
	if OS.get_name() in ["Windows", "Linux", "macOS", "Web"]:
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)

func _set_bus(bus: String, on: bool, vol: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0: return
	AudioServer.set_bus_mute(i, not on or vol <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(vol, 0.001)))

func set_option(key: String, value) -> void:
	set(key, value)
	apply_settings()
	save_settings()

# ------------------------------------------------------------------ sounds
func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var list: Array = sounds.get(sound_name, [])
	if list.is_empty(): return
	var p: AudioStreamPlayer = sfx_players[0]
	for q in sfx_players:
		if not q.playing:
			p = q
			break
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()

func play_click() -> void: play_sfx("click", -6.0, randf_range(0.95, 1.05))
func play_cast() -> void: play_sfx("cast", -4.0, randf_range(0.9, 1.1))
func play_splash() -> void: play_sfx("splash", -3.0, randf_range(0.95, 1.1))
func play_reel() -> void: play_sfx("bubble", -6.0, randf_range(0.9, 1.1))
func play_strike() -> void: play_sfx("strike", -2.0, 1.0)
func play_success() -> void: play_sfx("success", -3.0, 1.0)
func play_levelup() -> void: play_sfx("levelup", -2.0, 1.0)
