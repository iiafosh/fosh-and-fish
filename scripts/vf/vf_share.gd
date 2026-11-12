extends RefCounted
## Share cards (1.1): a 1200x630 picture of a proud moment (a numbered shiny, a Derby score) with the player's name,
## the logo and the link, ready to post anywhere.
##   web: the phone's share sheet when the browser has one (Web Share API with a file); otherwise the picture
##        downloads and the text is copied
##   PC:  saved in Pictures/fosh&fish (shown in the file manager) and the text is copied
## Test: godot --path . --resolution 1280x720 -- --capture=DIR --share-test  (writes both cards to DIR, shares nothing)

const W := 1200
const H := 630
const LINK := "https://foshfish.xyz/play"
const GOLD := Color("#ffd75e")

var m                                   # vf_main
var _busy := false
var test_dir := ""                      # (--share-test: write here instead of sharing)

func _init(main) -> void:
	m = main

## the shiny celebration's Share button, and the Fish Book's
func shiny(species: String, serial: int) -> void:
	var t: Texture2D = m.v1.shiny_tex(species)
	var supply := VF.commas(VFData.SHINY_SUPPLY)
	await _go(t, "SHINY!", "Shiny %s" % species, "No. %04d  ·  only %s in the world" % [serial, supply],
		"I caught Shiny %s No. %04d in fosh&fish! Only %s exist. Play free: %s" % [species, serial, supply, LINK],
		"shiny_%s_%04d" % [VFData.slug(species), serial])

## the Derby panel's Share button
func derby(score: int, rank: int) -> void:
	var where := ("#%d this week" % rank) if rank > 0 else "this week"
	# the hero: the Derby Cup itself (render_v1.py ui derby_cup, the hat's own model)
	var cup: Texture2D = m.stage._tex("ui/derby_cup.png")
	if cup == null: cup = m.ph("trophy")
	await _go(cup, "FISHING DERBY", "%s points" % VF.commas(score), "%s  ·  beat my score!" % where,
		"I scored %s points in the fosh&fish Fishing Derby %s. Can you beat it? Play free: %s" % [VF.commas(score), where, LINK],
		"derby_%d" % score)

func _go(hero: Texture2D, kicker: String, title: String, sub: String, text: String, file: String) -> void:
	if _busy: return
	_busy = true
	var img := await _card(hero, kicker, title, sub)
	_busy = false
	if img == null:
		m._toast("Couldn't make the picture. Try again?", "quest")
		return
	_share(img, text, file + ".png")

## the card: the biome you're in, the hero picture in a glow, the words, the logo and the link
func _card(hero: Texture2D, kicker: String, title: String, sub: String) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root := Control.new()
	root.size = Vector2(W, H)
	root.theme = m.theme
	vp.add_child(root)
	var bg := TextureRect.new()
	bg.texture = m.stage._tex("scenes/%s.png" % VFData.slug(VF.biome))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(W, H)
	root.add_child(bg)
	var shade := TextureRect.new()                       # (darker toward the words, so they read on any biome)
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.06, 0.16, 0.2, 0.25))
	g.gradient.set_color(1, Color(0.06, 0.16, 0.2, 0.86))
	g.fill_from = Vector2(0.25, 0.0)
	g.fill_to = Vector2(0.75, 0.0)
	shade.texture = g
	shade.size = Vector2(W, H)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(shade)
	var glow := TextureRect.new()
	glow.texture = m.stage._tex("fx/glow.png")
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.modulate = Color(1.0, 0.9, 0.55, 0.85)
	glow.position = Vector2(20, 75)
	glow.size = Vector2(480, 480)
	root.add_child(glow)
	if hero:
		var pic := TextureRect.new()
		pic.texture = hero
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(80, 135)
		pic.size = Vector2(360, 360)
		root.add_child(pic)
	var col := VBoxContainer.new()
	col.position = Vector2(540, 150)
	col.size = Vector2(620, 330)
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)
	col.add_child(m.lbl(kicker, 30, GOLD, 8))
	var t: Label = m.lbl(title, 64, Color.WHITE, 12)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 620
	col.add_child(t)
	var s: Label = m.lbl(sub, 26, Color(1, 1, 1, 0.92), 6)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 620
	col.add_child(s)
	col.add_child(m.lbl("by %s" % VF.player_name, 26, Color("#bfe8ef"), 6))
	var logo := TextureRect.new()
	logo.texture = load("res://assets/brand/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(W - 250, H - 215)
	logo.size = Vector2(220, 180)
	root.add_child(logo)
	var url: Label = m.lbl("Play free at foshfish.xyz", 24, Color.WHITE, 8)
	url.position = Vector2(40, H - 62)
	root.add_child(url)
	m.add_child(vp)
	for _i in 3: await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

func _share(img: Image, text: String, file: String) -> void:
	if test_dir != "":
		img.save_png(test_dir.path_join(file))
		return
	if OS.has_feature("web"):
		var b64 := Marshalls.raw_to_base64(img.save_png_to_buffer())
		JavaScriptBridge.eval("""(async function (b64, name, text) {
	const bin = atob(b64); const a = new Uint8Array(bin.length);
	for (let i = 0; i < bin.length; i++) a[i] = bin.charCodeAt(i);
	const file = new File([a], name, { type: 'image/png' });
	try {
		if (navigator.canShare && navigator.canShare({ files: [file] })) { await navigator.share({ files: [file], text: text }); return; }
	} catch (e) { if (e && e.name === 'AbortError') return; }
	try { await navigator.clipboard.writeText(text); } catch (e) {}
	const url = URL.createObjectURL(file); const l = document.createElement('a');
	l.href = url; l.download = name; document.body.appendChild(l); l.click(); l.remove();
	setTimeout(function () { URL.revokeObjectURL(url); }, 5000);
})(%s, %s, %s);""" % [JSON.stringify(b64), JSON.stringify(file), JSON.stringify(text)], true)
		m._toast("Here's your picture! If no share menu opened, it downloaded and the text is copied.", "quest")
		return
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if dir == "": dir = OS.get_user_data_dir()
	dir = dir.path_join("fosh&fish")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file)
	if img.save_png(path) != OK:
		m._toast("Couldn't save the picture.", "quest")
		return
	DisplayServer.clipboard_set(text)
	m._toast("Saved to Pictures/fosh&fish, and the text is copied: paste it with the picture.", "quest")
	if not OS.has_feature("mobile"): OS.shell_show_in_file_manager(path)

## --share-test: both cards into DIR. Never saves the game.
func test(dir: String) -> void:
	VF.autosave = false
	m._veteran("River")
	VF.tutorial = 99
	VF.player_name = "afosh"
	m._apply_biome()
	await m.get_tree().create_timer(0.8).timeout
	test_dir = dir
	await shiny("Pufferfish", 42)
	await derby(1890, 3)
	test_dir = ""
	for f in ["shiny_pufferfish_0042.png", "derby_1890.png"]:
		var img := Image.load_from_file(dir.path_join(f))
		print("SHARE %s %s %s" % ["PASS" if img != null and img.get_size() == Vector2i(W, H) else "FAIL", f, img.get_size() if img else "missing"])
