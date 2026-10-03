extends Node

var ambient_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load sound resources
	sounds["click"] = load("res://web/assets/sfx/click.mp3")
	sounds["whoosh"] = load("res://web/assets/sfx/whoosh.mp3")
	sounds["reel"] = load("res://web/assets/sfx/reel.mp3")
	sounds["splash"] = load("res://web/assets/sfx/splash.mp3")
	sounds["strike"] = load("res://web/assets/sfx/strike.wav")
	sounds["success"] = load("res://web/assets/sfx/success.wav")
	sounds["ambient"] = load("res://web/assets/sfx/sea_ambient.mp3")

	# Ambient sea loop player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.stream = sounds["ambient"]
	ambient_player.volume_db = -14.0
	ambient_player.autoplay = true
	add_child(ambient_player)
	if sounds["ambient"]:
		ambient_player.play()

	# Create SFX pool
	for i in range(8):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sounds.has(sound_name) or sounds[sound_name] == null:
		return

	for p in sfx_players:
		if not p.playing:
			p.stream = sounds[sound_name]
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return

	# If all busy, use first
	var p = sfx_players[0]
	p.stream = sounds[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()

func play_click() -> void:
	play_sfx("click", -4.0, randf_range(0.95, 1.05))

func play_cast() -> void:
	play_sfx("whoosh", -2.0, randf_range(0.9, 1.1))

func play_splash() -> void:
	play_sfx("splash", -2.0, randf_range(0.95, 1.05))

func play_reel() -> void:
	play_sfx("reel", -6.0, randf_range(0.9, 1.1))

func play_strike() -> void:
	play_sfx("strike", 2.0, 1.0)

func play_success() -> void:
	play_sfx("success", 0.0, 1.0)
