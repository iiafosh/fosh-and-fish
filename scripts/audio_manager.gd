extends Node
## The soundtrack and the sound effects (see CREDITS.md), on separate "Music" and "SFX" buses
## so players can mute or turn each down in Settings. Settings persist in user://settings.cfg.

const SFX := "res://assets/third_party/sfx/"
const SETTINGS_PATH := "user://settings.cfg"

## The soundtrack: tracks from Scott Buckley's library (CC-BY 4.0, credited in the game and in CREDITS.md).
## tools/video/make_music.py makes the files. slug: [title, what it sounds like, minutes:seconds]
const MUSIC := "res://assets/audio/music/"
const COMPOSER := "Scott Buckley"
const MUSIC_CREDIT := "Music by Scott Buckley (www.scottbuckley.com.au), released under CC-BY 4.0"
const TRACKS := {
	"echoes_of_home": ["Echoes Of Home", "Warm and nostalgic, like a Ghibli film", "4:52"],
	"home_was_you": ["Home Was You", "Peaceful folk: piano, strings, accordion", "4:29"],
	"glow": ["Glow", "Relaxed and happy: acoustic guitar, piano", "3:11"],
	"amberlight": ["Amberlight", "Soft piano and orchestra at golden hour", "4:43"],
	"simplicity": ["Simplicity", "Sunny piano, fiddle and mandolin", "3:05"],
	"felicity": ["Felicity", "Hopeful and folksy, with mandolin", "3:31"],
	"castles_in_the_sky": ["Castles in the Sky", "Dreamy piano and vibes", "3:47"],
	"cirrus": ["Cirrus", "Floating synths and strings", "6:58"],
	"beyond_these_walls": ["Beyond These Walls", "Moody piano, far-away warm winds", "6:57"],
	"path_through_the_mountains": ["Path Through The Mountains", "Slow, sweeping and mysterious", "5:21"],
	"aurora": ["Aurora", "Slow, warm, glittering ambience", "8:19"],
	"borealis": ["Borealis", "Still and uplifting ambience", "6:32"],
	"solace": ["Solace", "Calm strings and glass marimba", "5:56"],
	"hymn_to_the_dawn": ["Hymn to the Dawn", "A sun rising on a new world", "6:58"],
	"meanwhile": ["Meanwhile", "A liquid, dreamy world to float in", "5:26"],
	"reverie": ["Reverie", "Intimate, dream-like piano", "3:44"],
	"moonlight": ["Moonlight", "A slow dance for piano and strings", "4:14"],
	"the_long_way_home": ["The Long Way Home", "Soft piano, almost a lullaby", "2:53"],
}
## who plays where: each biome has its own tracks; after dark (where night falls) it's the night's
const STATIONS := {
	"River": ["echoes_of_home", "home_was_you", "glow", "amberlight"],
	"Ocean": ["simplicity", "amberlight", "felicity", "glow"],
	"Volcanic": ["beyond_these_walls", "path_through_the_mountains"],
	"Sky": ["castles_in_the_sky", "cirrus", "home_was_you"],
	"Space": ["aurora", "borealis"],
	"Alien": ["solace", "hymn_to_the_dawn"],
	"Abyss": ["meanwhile", "reverie"],
	"night": ["moonlight", "the_long_way_home", "reverie"],
}
const FADE := 3.0             # seconds, between tracks that cut in (a new biome, nightfall)
const TRACK_GAP := 3.5        # seconds of quiet between tracks that end by themselves
signal track_changed(slug: String)

var music_players: Array[AudioStreamPlayer] = []
var _front := 0               # the player that's playing now (the other one fades out)
var _music_tween: Tween
var track := ""               # slug of the current track
var music_paused := false
var music_pick := false       # the player chose a track on the radio: the playlist runs on from there, wherever you fish
var _station := "River"
var _played: Array = []       # last tracks, so the next one isn't a repeat
var _gap_timer: Timer
var _web_tracks := {}         # (web build: downloaded when needed, see _stream_of)
var _web_http: HTTPRequest
var _music_ticket := 0        # (only the newest request starts playing)

var sfx_players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}

var music_on := true
var music_volume := 0.8      # 0..1
var sfx_on := true
var sfx_volume := 0.8
var fullscreen := false
var ui_size := 1.0           # interface size: 0.85 smaller, 1.0 normal, 1.15 bigger (Settings)
var notify_on := false       # reminders while the game is in the background (vf_notify.gd; asks the browser first)
var scenery_fx := true       # moving water, wind, reflections, clouds and nightfall (Settings; off for weak devices)

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
		"coin": ["impactMetal_light_000", "impactMetal_light_001", "impactMetal_light_002"], "bell": "impactBell_heavy_000",
		"flop": ["impactPlank_medium_000", "impactPlank_medium_001", "impactPlank_medium_002"],
	}
	for k in files:
		var v = files[k]
		sounds[k] = []
		for n in (v if v is Array else [v]):
			var s = load(SFX + n + ".ogg")
			if s: sounds[k].append(s)
	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.process_mode = Node.PROCESS_MODE_ALWAYS
		mp.finished.connect(_on_track_finished.bind(mp))
		add_child(mp)
		music_players.append(mp)
	_gap_timer = Timer.new()
	_gap_timer.one_shot = true
	_gap_timer.timeout.connect(music_next)
	add_child(_gap_timer)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	load_settings()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		fullscreen = true          # only `--fullscreen` starts the window like this: the command line wins (not saved)
	apply_settings()
	if not _recording():
		_play(STATIONS.River[0])           # the main theme, from the title screen on

# ---------------------------------------------------------------- settings
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK: return
	music_on = cf.get_value("audio", "music_on", music_on)
	music_volume = cf.get_value("audio", "music_volume", music_volume)
	sfx_on = cf.get_value("audio", "sfx_on", sfx_on)
	sfx_volume = cf.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = cf.get_value("display", "fullscreen", fullscreen)
	ui_size = clampf(float(cf.get_value("display", "ui_size", ui_size)), 0.7, 1.4)
	notify_on = bool(cf.get_value("game", "notify_on", notify_on))
	scenery_fx = bool(cf.get_value("display", "scenery_fx", scenery_fx))

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music_on", music_on)
	cf.set_value("audio", "music_volume", music_volume)
	cf.set_value("audio", "sfx_on", sfx_on)
	cf.set_value("audio", "sfx_volume", sfx_volume)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "ui_size", ui_size)
	cf.set_value("game", "notify_on", notify_on)
	cf.set_value("display", "scenery_fx", scenery_fx)
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

# ------------------------------------------------------------------- music
## video recordings keep their soundtrack for the edit (tools/video)
func _recording() -> bool:
	return Backend.RECORDING_FLAGS.any(func(f): return f in OS.get_cmdline_user_args())

## where the player fishes now: a different biome (or nightfall) cuts to its music
func music_place(biome: String, night := false) -> void:
	var st: String = "night" if night and STATIONS.has("night") else biome
	if st == _station: return
	_station = st
	if music_pick or music_paused or _recording(): return
	if not track in STATIONS.get(st, []):
		_play(_pick_next(STATIONS.get(st, STATIONS.River)))

func _pick_next(list: Array) -> String:
	var fresh := list.filter(func(t): return not t in _played.slice(-mini(_played.size(), list.size() - 1)))
	return (fresh[0] if not fresh.is_empty() else list[0])

## the next track: of this place's list, or of the whole soundtrack after a pick on the radio
func music_next() -> void:
	_gap_timer.stop()
	var list: Array = TRACKS.keys() if music_pick else STATIONS.get(_station, STATIONS.River)
	if music_pick:
		_play(list[(list.find(track) + 1) % list.size()])
	else:
		_play(_pick_next(list))

func music_prev() -> void:
	_gap_timer.stop()
	var list: Array = TRACKS.keys() if music_pick else STATIONS.get(_station, STATIONS.River)
	_play(list[(maxi(list.find(track), 0) - 1 + list.size()) % list.size()])

## a track chosen on the radio
func music_choose(slug: String) -> void:
	music_pick = true
	music_paused = false
	_gap_timer.stop()
	_play(slug)

## back to the music of wherever you fish
func music_follow_place() -> void:
	music_pick = false
	music_paused = false
	_gap_timer.stop()
	if not track in STATIONS.get(_station, []): _play(_pick_next(STATIONS.get(_station, STATIONS.River)))
	elif not music_players[_front].playing: music_next()

func music_toggle_pause() -> void:
	music_paused = not music_paused
	music_players[_front].stream_paused = music_paused
	if not music_paused and not music_players[_front].playing:
		music_next()
	if music_paused: _gap_timer.stop()

func music_is_playing() -> bool:
	return not music_paused and (music_players[_front].playing or not _gap_timer.is_stopped())

func _on_track_finished(p: AudioStreamPlayer) -> void:
	if p == music_players[_front] and not music_paused:
		_gap_timer.start(TRACK_GAP)

func _play(slug: String) -> void:
	_music_ticket += 1
	var ticket := _music_ticket
	var stream = await _stream_of(slug)
	if stream == null or ticket != _music_ticket: return
	track = slug
	_played.append(slug)
	if _played.size() > 6: _played.pop_front()
	var old := music_players[_front]
	_front = 1 - _front
	var now := music_players[_front]
	if _music_tween: _music_tween.kill()
	now.stream = stream
	now.stream_paused = false
	now.volume_db = -40.0 if old.playing else 0.0
	now.play()
	_music_tween = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", -60.0, FADE).set_trans(Tween.TRANS_SINE)
		_music_tween.tween_property(now, "volume_db", 0.0, FADE).set_trans(Tween.TRANS_SINE)
		_music_tween.chain().tween_callback(old.stop)
	track_changed.emit(slug)

## The file of a track. The web build leaves the soundtrack out of its big first download and fetches a track
## when it's needed (index.music.<slug>.ogg, next to the game: tools/release.py).
func _stream_of(slug: String):
	if not OS.has_feature("web"):
		return load(MUSIC + slug + ".ogg")
	if _web_tracks.has(slug): return _web_tracks[slug]
	if _web_http == null:
		_web_http = HTTPRequest.new()
		add_child(_web_http)
	if _web_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: _web_http.cancel_request()
	var base := str(JavaScriptBridge.eval("location.href.split('?')[0].split('#')[0]")).get_base_dir()
	if _web_http.request(base + "/index.music.%s.ogg" % slug) != OK: return null
	var got: Array = await _web_http.request_completed
	if got[0] != HTTPRequest.RESULT_SUCCESS or got[1] != 200: return null
	var st := AudioStreamOggVorbis.load_from_buffer(got[3])
	if st == null: return null
	if _web_tracks.size() >= 3: _web_tracks.erase(_web_tracks.keys()[0])
	_web_tracks[slug] = st
	return st

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
func play_splash() -> void: play_sfx("splash", -14.0, randf_range(1.0, 1.2))
func play_reel() -> void: play_sfx("bubble", -6.0, randf_range(0.9, 1.1))
func play_bite() -> void: play_sfx("strike", -13.0, randf_range(0.9, 1.15))
func play_burst(big := 0) -> void: play_sfx("splash_big", -13.0 + big * 4.0, randf_range(1.05, 1.2) - big * 0.14)    # a fish out of the water
func play_flop() -> void: play_sfx("flop", -17.0, randf_range(1.2, 1.5))                                              # ... and onto the deck
func play_strike() -> void: play_sfx("strike", -2.0, 1.0)
func play_success() -> void: play_sfx("success", -3.0, 1.0)
func play_levelup() -> void: play_sfx("levelup", -2.0, 1.0)
func play_coin() -> void: play_sfx("coin", -12.0, randf_range(1.45, 1.75))     # a metal tap, pitched up into a coin
func play_bell() -> void: play_sfx("bell", -6.0, 1.15)
