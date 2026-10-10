extends SceneTree
## Online check of the in-game updater against the real update.json URL.
## Run: Godot_console.exe --headless --path . -s res://tests/updater_check.gd

func _init() -> void:
	await process_frame
	var u = root.get_node("Updater")
	u.check()
	var t := 0
	while u.state == "checking" and t < 300:
		await process_frame
		t += 1
	print("UPDATER state=", u.state, " error=", u.error, " version=", u.version, " build=", u.build)
	quit()
