class_name VFHaptics
extends RefCounted
## Phones vibrate when something happens. Short and weak on purpose: this is a relaxing game. Settings -> Vibration
## turns it off (AudioManager.vibration_on); Android needs permissions/vibrate in export_presets.cfg. Auto-fish never
## buzzes (see vf_stage.show_catch): the phone may be lying on a table.
## Under --capture a call prints "HAPTIC <kind>" instead, so a capture can prove the calls happen. Nobody can feel one
## without a real phone, so these numbers are a first guess until someone has.

## kind: the pulses, each [milliseconds, strength 0..1]. Phones that can't set the strength only go by the length.
const KINDS := {
	"reel": [[15, 0.2]],                       # the mini-game, while the net is on the fish
	"tap": [[20, 0.3]],                        # an everyday fish lands on deck
	"poke": [[25, 0.3]],                       # a crab, a gull, a bottle...
	"lose": [[30, 0.25]],                      # it got away: nothing to feel bad about
	"bite": [[40, 0.45]],
	"win": [[50, 0.5]],
	"honk": [[60, 0.4]],
	"rare": [[30, 0.4], [45, 0.5]],            # something special lands on deck
	"gerald": [[50, 0.5], [50, 0.5]],          # dun dun
	"shiny": [[30, 0.35], [30, 0.45], [70, 0.6]],
}
const PAUSE_MS := 90                           # between the pulses of a pattern
const REEL_EVERY_MS := 450                     # the mini-game ticks about 6 times a second: every third is plenty

static var _reel_at := -REEL_EVERY_MS

static func buzz(kind: String) -> void:
	if not KINDS.has(kind):
		push_error("VFHaptics: no kind called " + kind)
		return
	if not AudioManager.vibration_on or _too_soon(kind): return
	if _capturing():
		print("HAPTIC ", kind)
	elif OS.has_feature("mobile") or OS.has_feature("web_android"):
		_play(KINDS[kind])

static func _too_soon(kind: String) -> bool:
	if kind != "reel": return false
	var now := Time.get_ticks_msec()
	if now - _reel_at < REEL_EVERY_MS: return true
	_reel_at = now
	return false

static func _capturing() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): return true
	return false

## one after the other: a new pulse would cut off the one before it
static func _play(pulses: Array) -> void:
	for i in pulses.size():
		Input.vibrate_handheld(pulses[i][0], pulses[i][1])
		if i < pulses.size() - 1:
			await (Engine.get_main_loop() as SceneTree).create_timer((pulses[i][0] + PAUSE_MS) / 1000.0).timeout
