extends SceneTree
## Signing for in-game updates (used by tools/release.py).
##   --keygen              create the private key (once) and print the public key
##   --sign=FILE           print "sha256 signature_base64" for a patch file
## The private key lives OUTSIDE the repo: %APPDATA%/fosh-and-fish/update_private.key
## (override with the FOSH_UPDATE_KEY environment variable). Back it up: without it you
## can't publish in-game updates for builds that carry the matching public key.

func _key_path() -> String:
	var p := OS.get_environment("FOSH_UPDATE_KEY")
	if p != "": return p
	return OS.get_environment("APPDATA").path_join("fosh-and-fish").path_join("update_private.key")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var crypto := Crypto.new()
	if "--keygen" in args:
		var path := _key_path()
		if FileAccess.file_exists(path):
			print("KEY_EXISTS ", path)
		else:
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var key := crypto.generate_rsa(2048)
			key.save(path)
			print("KEY_CREATED ", path)
		var k := CryptoKey.new()
		k.load(path)
		print("PUBLIC_KEY_BEGIN")
		print(k.save_to_string(true))
		print("PUBLIC_KEY_END")
	for a in args:
		if a.begins_with("--sign="):
			var file := a.substr(7)
			var sha := FileAccess.get_sha256(file)
			var key := CryptoKey.new()
			if key.load(_key_path()) != OK:
				printerr("no private key at ", _key_path())
				quit(1)
				return
			var sig := crypto.sign(HashingContext.HASH_SHA256, sha.hex_decode(), key)
			print("SIGNED ", sha, " ", Marshalls.raw_to_base64(sig))
	quit()
