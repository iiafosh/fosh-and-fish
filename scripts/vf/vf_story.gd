extends RefCounted
## The story (Menu -> Story): how a man who sold umbrellas became a fisherman, got hooked, and set off through seven waters
## after the thing that ate his lunch. One page for every biome. A page opens by itself the first time you sail somewhere
## new (the first one when the tutorial ends), and every page you have reached can be read again here.
## The pictures are assets/vf/story/<biome>.jpg, made by tools/art/make_story.py from the owner's paintings (docs/STORY.md has
## the prompts for ChatGPT); a page without one shows the biome's own backdrop.
## Which pages have been read is VF.story_seen. Built with vf_main's UI kit (sbox, lbl, btn, icon, ph).
## Funny and kind, like the rest: nobody is hurt, the Leviathan least of all.

const CHAPTERS := [
	{"biome": "River", "where": "the River", "title": "One day off", "lines": [
		"He was not a fisherman. He sold umbrellas in a town where it never rained.",
		"On his one day off he rented a rowboat, a plastic rod and a tin of worms.",
		"He caught one small fish. It looked at him. He looked at it. It was the best day of his life.",
		"Then something as long as the river slid under the boat and ate his lunch.",
		"He should have gone home. He cast again."]},
	{"biome": "Volcanic", "where": "the Volcanic waters", "title": "Just one more", "lines": [
		"\"One more cast,\" he said. That was four thousand casts ago.",
		"He sold the umbrellas. He bought a better rod. He told his mother it was a phase.",
		"When the river felt small, he followed the warm water to a sea that boils.",
		"The fish here come out cooked. He says he is only after the thing that ate his lunch.",
		"He is not only after the thing that ate his lunch."]},
	{"biome": "Ocean", "where": "the Ocean", "title": "It has a name", "lines": [
		"In the harbour every sailor had a story about it, and not one of them had a photo.",
		"They call it the Leviathan. It swims through seven waters, and it has eaten a lunch in each.",
		"The merchant sold him a map: river, fire, sea, sky, stars, the strange seas, the bottom of everything.",
		"\"Nobody has sailed them all,\" said the merchant. \"Mostly because of the sky.\"",
		"He paid in fish. He would have paid in anything."]},
	{"biome": "Sky", "where": "the Sky", "title": "Nobody told the boat", "lines": [
		"Above the sea there is another sea, made of cloud, with islands that forgot to fall.",
		"Nobody had told the boat it couldn't sail up there. So it did.",
		"He caught a fish that was mostly weather, and a cold.",
		"One evening a shadow crossed the clouds from underneath, as long as a town.",
		"It was going up. So was he."]},
	{"biome": "Space", "where": "Space", "title": "A long way from the river", "lines": [
		"From here the river is a thin silver thread. He waves at it now and then.",
		"There is no up in space. The fish don't mind, and the worms float out of the tin looking pleased.",
		"He writes home: \"Still fishing. Send socks.\" The post is slow.",
		"Last night something huge swam past the moon and left a wake in the stars.",
		"He reeled in, and followed."]},
	{"biome": "Alien", "where": "the Alien seas", "title": "They know it here too", "lines": [
		"Two moons, green water, and fish with more eyes than he has hooks.",
		"The locals have a word for the Leviathan. It means \"the one who takes your lunch\".",
		"They have a word for him too. It means \"the one who won't go home\".",
		"He asked them where it sleeps. Every one of them pointed down.",
		"All the way down."]},
	{"biome": "Abyss", "where": "the Abyss", "title": "The bottom of everything", "lines": [
		"No light down here. Only his lamp, his line, and one very large eye.",
		"The Leviathan sleeps on everything it ever took: anchors, hats, a thousand rubber ducks, and a lunchbox with his name on it.",
		"He could have taken the lunchbox and gone home.",
		"He baited the hook instead.",
		"He caught it, of course. Then he let it go. What else would he chase tomorrow?"]},
]

var m                                 # vf_main
var at := "River"                     # the page the panel shows
var auto_in_tests := false            # captures and recordings: no page opens by itself, unless the story's own test asks


func _init(main) -> void:
	m = main

static func index_of(biome: String) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i].biome == biome: return i
	return 0

## the picture of a page: the painted one if it's there, or else the biome's own backdrop
func picture(biome: String) -> Texture2D:
	var s: String = VFData.slug(biome)
	for ext in ["jpg", "webp", "png"]:
		var t: Texture2D = m.tex("story/%s.%s" % [s, ext])
		if t != null: return t
	return m.tex("scenes/%s.png" % s)

## Somewhere new (or the tutorial just ended): its page opens by itself, once, when nothing else is going on. If something is
## (a panel, the mini-game, a Derby run, the phone), the page waits in the Menu with a "new page!" note instead.
func offer(biome: String) -> void:
	if biome in VF.story_seen or not VF.story_open(biome): return
	if (m._capturing() or m._recording()) and not auto_in_tests: return
	var tree: SceneTree = m.get_tree()
	await tree.create_timer(1.4).timeout
	var waited := 0.0
	while m.sail.state != "idle" and waited < 6.0:      # (the boat is still coming in)
		await tree.process_frame
		waited += m.get_process_delta_time()
	await tree.create_timer(0.6).timeout
	if biome in VF.story_seen or VF.biome != biome or VF.tutorial < 99: return
	if m.overlay.visible or m.minigame != null or m.launcher_open() or (m.derby != null and m.derby.running): return
	if m.phone != null and m.phone.visible and not VF.tok_dock: return
	at = biome
	m._open_panel("story")

func _hint(i: int) -> String:
	if i + 1 >= CHAPTERS.size(): return "The end. He is still out there."
	var nxt: Dictionary = CHAPTERS[i + 1]
	if not VF.story_open(nxt.biome): return "The next page is in %s, at level %d." % [nxt.where, VFData.BIOMES[nxt.biome].level]
	return "" if nxt.biome in VF.story_seen else "A new page is waiting."

func _turn(text: String, biome: String) -> Button:
	var b: Button = m.btn(text, m.C_TEAL, 15, 120)
	b.pressed.connect(func():
		AudioManager.play_click()
		at = biome
		m._render_panel()
		m.panel_scroll.scroll_vertical = 0)
	return b

## Menu -> Story: one page at a time, a row of numbers to turn to any page you have reached
func panel() -> void:
	var new_look: bool = m.skin.on()
	var i := index_of(at)
	var ch: Dictionary = CHAPTERS[i]
	var biome: String = ch.biome
	var open: bool = VF.story_open(biome)
	if open and not biome in VF.story_seen:
		VF.story_read(biome)                      # (no VF.changed from in here: it would build this panel twice)
		m.collect.refresh_badges()
	var ink: Color = m.skin.INK if new_look else m.C_TEXT
	var soft: Color = m.skin.INK_SOFT if new_look else m.C_MUTED
	var pages := HBoxContainer.new()
	pages.alignment = BoxContainer.ALIGNMENT_CENTER
	pages.add_theme_constant_override("separation", 8)
	for k in CHAPTERS.size():
		var b: String = CHAPTERS[k].biome
		var can: bool = VF.story_open(b)
		var d: Button = m.btn(str(k + 1) if can else "", Color(VFData.BIOMES[b].accent).darkened(0.2) if can else Color("#5b6b6d"), 15, 44)
		d.custom_minimum_size = Vector2(56, 46) if k == i else Vector2(44, 38)      # (the page you are on is the big one)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not can:
			d.icon = m.ph("lock")
			d.expand_icon = true
		d.tooltip_text = "%s: %s" % [b, CHAPTERS[k].title] if can else "%s: level %d" % [b, VFData.BIOMES[b].level]
		d.modulate.a = 1.0 if k == i or (can and not b in VF.story_seen) else 0.6
		d.pressed.connect(func():
			AudioManager.play_click()
			at = b
			m._render_panel()
			m.panel_scroll.scroll_vertical = 0)
		pages.add_child(d)
	m.panel_body.add_child(pages)
	# the page: its picture, and the words beside it (under it where there's no room)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", m.skin.card_box() if new_look else m.sbox(m.C_PANEL2, 12, 0, Color.TRANSPARENT, 12))
	var room: float = m.size.x                # (the game's own width: a phone held sideways is wide but not tall)
	var stack: bool = room < 700.0
	var pw: float = clampf(room * 0.36, 230.0, 390.0)
	var box: BoxContainer = VBoxContainer.new() if stack else HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", m.sbox(Color("#0b2930"), 14, 0, Color.TRANSPARENT, 0))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.custom_minimum_size = Vector2(0, 180) if stack else Vector2(pw, roundf(pw * 2.0 / 3.0))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = picture(biome)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open: pic.modulate = Color(0.3, 0.34, 0.38)
	frame.add_child(pic)
	box.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size.x = 100
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 7)
	col.add_child(m.lbl("PAGE %d OF %d  ·  %s" % [i + 1, CHAPTERS.size(), biome.to_upper()], 13, Color(VFData.BIOMES[biome].accent).darkened(0.4)))
	var title: Label = m.lbl(String(ch.title) if open else "Still ahead", 26, ink)
	if new_look: title.add_theme_font_override("font", m.skin.bold())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var lines: Array = ch.lines if open else ["The story goes on in %s. Reach level %d and sail there to read this page." % [ch.where, VFData.BIOMES[biome].level]]
	for ln in lines:
		var p: Label = m.lbl(String(ln), 16, ink if open else soft)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_theme_constant_override("line_spacing", -9)       # (a sentence that wraps stays one sentence)
		col.add_child(p)
	box.add_child(col)
	m.panel_body.add_child(card)
	# turning the page
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	var hint: Label = m.lbl(_hint(i) if open else "", 14, m.C_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size.x = 100
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nav.add_child(hint)
	if i > 0: nav.add_child(_turn("Earlier", CHAPTERS[i - 1].biome))
	if i + 1 < CHAPTERS.size() and VF.story_open(CHAPTERS[i + 1].biome):
		nav.add_child(_turn("Next page", CHAPTERS[i + 1].biome))
	else:
		var go: Button = m.btn("Keep fishing", m.C_GOOD, 15, 130)
		go.pressed.connect(func(): m._close_panel())
		nav.add_child(go)
	m.panel_body.add_child(nav)

## godot --path . --resolution 1280x720 -- --capture=DIR --story-test [--touch --ui-dp=390] : every page, a page still
## ahead, and the page that opens by itself on arriving somewhere new (once). Never saves.
func capture_test(dir: String) -> void:
	VF._apply(VF._defaults.duplicate(true))
	VF.tutorial = 99
	VF.level = 3000
	VF.changed.emit()
	for ch in CHAPTERS:
		at = ch.biome
		m._open_panel("story")
		await m._wait(0.5)
		await m._shot(dir + "/story_%s.png" % VFData.slug(ch.biome))
	print("STORY read=%s unread=%d painted=%s" % [VF.story_seen, VF.story_unread(),
		CHAPTERS.filter(func(c): return picture(c.biome) != m.tex("scenes/%s.png" % VFData.slug(c.biome))).map(func(c): return c.biome)])
	m._close_panel()
	# a beginner: the first page is theirs, the rest is still ahead
	VF._apply(VF._defaults.duplicate(true))
	VF.tutorial = 99
	VF.changed.emit()
	print("STORY beginner: unread=%d open=%s" % [VF.story_unread(), VFData.BIOME_ORDER.filter(func(b): return VF.story_open(b))])
	m._open_panel("menu")
	await m._wait(0.5)
	await m._shot(dir + "/story_menu.png")
	at = "Sky"
	m._open_panel("story")
	await m._wait(0.5)
	await m._shot(dir + "/story_ahead.png")
	m._close_panel()
	# arriving: the page opens by itself, and only the first time
	auto_in_tests = true
	VF.level = 60
	VF.select_biome("Volcanic")
	m._apply_biome()
	offer("Volcanic")
	await m._wait(3.2)
	print("STORY arriving: panel='%s' page=%s read=%s" % [m._panel_kind, at, VF.story_seen])
	await m._shot(dir + "/story_arriving.png")
	m._close_panel()
	offer("Volcanic")
	await m._wait(3.2)
	print("STORY arriving again: panel='%s'" % m._panel_kind)
