extends Control
## A vertical, snapping FishTok feed. Mouse wheel, drag/swipe (with a flick)
## and the arrow keys move one post at a time; only the current post and its
## neighbours exist. Tap pauses, double tap likes.

const Post := preload("res://scripts/vf/vf_tok_post.gd")

signal moved(index: int)

var phone
var items: Array = []
var index := 0
var track: Control
var views := {}                  # index -> post view
var live := true                 # false while the feed page is hidden
var _drag := false
var _moved := false
var _press := Vector2.ZERO
var _vel := 0.0
var _last_motion_ms := 0
var _tw: Tween
var _wheel_lock := 0.0
var _tap_left := -1.0

func setup(p, its: Array, sz: Vector2, start := 0) -> void:
	phone = p
	items = its
	size = sz
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	track = Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	index = clampi(start, 0, maxi(0, items.size() - 1))
	track.position.y = -index * size.y
	_sync()

func current():
	return views.get(index)

func _sync() -> void:
	for i in views.keys():
		if absi(i - index) > 1:
			views[i].queue_free()
			views.erase(i)
	for i in range(index - 1, index + 2):
		if i < 0 or i >= items.size() or views.has(i): continue
		var pv := Post.new()
		pv.setup(phone, items[i], size)
		pv.position.y = i * size.y
		track.add_child(pv)
		views[i] = pv
	for i in views:
		views[i].set_active(i == index and live)

func set_live(on: bool) -> void:
	live = on
	for i in views:
		views[i].set_active(i == index and live)

func go(i: int, animate := true) -> void:
	var target_i := clampi(i, 0, items.size() - 1)
	var changed := target_i != index
	index = target_i
	_sync()
	if _tw: _tw.kill()
	var y := -index * size.y
	if animate:
		_tw = create_tween()
		_tw.tween_property(track, "position:y", y, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		track.position.y = y
	if changed:
		moved.emit(index)

func next() -> void:
	if index >= items.size() - 1:
		_bump(-1.0)
		return
	go(index + 1)

func prev() -> void:
	if index <= 0:
		_bump(1.0)
		return
	go(index - 1)

## rubber-band nudge at either end
func _bump(dir: float) -> void:
	if _tw: _tw.kill()
	var y := -index * size.y
	_tw = create_tween()
	_tw.tween_property(track, "position:y", y + dir * 38.0, 0.12).set_ease(Tween.EASE_OUT)
	_tw.tween_property(track, "position:y", y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_wheel_lock = maxf(0.0, _wheel_lock - delta)
	if _tap_left >= 0.0:
		_tap_left -= delta
		if _tap_left < 0.0 and current():
			current().toggle_pause()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			if _wheel_lock <= 0.0:
				if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN: next()
				else: prev()
				_wheel_lock = 0.32
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT: return
		if mb.pressed:
			if mb.double_click:
				_tap_left = -1.0
				if current(): current().double_tap(mb.position)
				accept_event()
				return
			_drag = true
			_moved = false
			_press = mb.position
			_vel = 0.0
		elif _drag:
			_drag = false
			if _moved:
				_release(mb.position.y - _press.y)
			else:
				_tap_left = 0.27            # wait: a second tap makes it a like, not a pause
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		var mm := e as InputEventMouseMotion
		var dy := mm.position.y - _press.y
		if not _moved and absf(dy) > 8.0:
			_moved = true
			if _tw: _tw.kill()
		if _moved:
			var off := dy
			if (index == 0 and dy > 0.0) or (index == items.size() - 1 and dy < 0.0): off = dy * 0.3
			track.position.y = -index * size.y + off
			_vel = mm.velocity.y
			_last_motion_ms = Time.get_ticks_msec()
		accept_event()

func _release(dy: float) -> void:
	var vel := _vel if Time.get_ticks_msec() - _last_motion_ms < 90 else 0.0
	if dy < -size.y * 0.16 or vel < -650.0: go(index + 1)
	elif dy > size.y * 0.16 or vel > 650.0: go(index - 1)
	else: go(index)
