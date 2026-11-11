extends SceneTree
## The in-game update, rehearsed against a local server (tools/updater_rehearsal.py runs this once per manifest):
## check -> pick the patch for this install -> download -> sha256 -> signature -> "ready", or the right error.
## Run by hand: Godot_console.exe --headless --path . -s res://tests/updater_local_check.gd -- --update-url=http://127.0.0.1:8099/good.json
## (tests/updater_check.gd is the other half: it only asks the real update.json.)

func _init() -> void:
	await process_frame
	var u = root.get_node("Updater")
	u.check()
	var t := 0
	while u.state in ["idle", "checking", "available", "downloading"] and t < 1500:
		await process_frame
		t += 1
	var patch_file := FileAccess.file_exists("user://patches/patch_b99.pck")
	var installed := FileAccess.file_exists("user://patches/installed.json")
	var leftover := FileAccess.file_exists("user://patches/patch_b99.pck.part")
	print("UPDATER state=%s error='%s' latest=%s base=%d build=%d platform=%s patch_file=%s installed_json=%s leftover_part=%s"
		% [u.state, u.error, u.latest.get("version", "-"), u.base_build, u.build, u.platform(), patch_file, installed, leftover])
	quit()
