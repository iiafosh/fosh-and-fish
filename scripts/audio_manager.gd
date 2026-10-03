extends Node
## Sound effects and water ambience (all CC0, see CREDITS.md).

const SFX := "res://assets/third_party/sfx/"

var ambient_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var amb = load(SFX + "loop_water_01.ogg")
	if amb:
		amb.loop = true
		ambient_player.stream = amb
		ambient_player.volume_db = -20.0
		add_child(ambient_player)
		ambient_player.play()
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

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
