extends Node3D

# Cozy 3D Fishing Shoreline - Inspired by "I Just Wanted to Fish" / ForkedPush
# Low-Poly Cel-Shaded Atmospheric Showcase in Godot 4.7.2 Forward+

@onready var camera: Camera3D = $Camera3D
@onready var water_mesh: MeshInstance3D = $Environment/OceanWater
@onready var foam_mesh: MeshInstance3D = $Environment/ShorelineFoam
@onready var foam_fine_mesh: MeshInstance3D = $Environment/ShorelineFoamFine
@onready var bobber_node: Node3D = $Props/Bobber
@onready var fishing_line_node: Node3D = $Props/FishingLineArc
@onready var crab_node: Node3D = $Characters/RedCrab
@onready var seagull_node: Node3D = $Characters/Seagull
@onready var rod_node: Node3D = $Characters/Fisherman/BambooRod
@onready var fisherman_node: Node3D = $Characters/Fisherman
@onready var fish1: MeshInstance3D = $Characters/FishUndersea/Fish1
@onready var fish2: MeshInstance3D = $Characters/FishUndersea/Fish2
@onready var return_btn: Button = $CanvasLayer/HUD/ReturnBtn

# Camera Orbit & Zoom parameters (Signature Steam Capsule default)
var pivot: Vector3 = Vector3(-0.10, 0.45, 0.2)
var cam_distance: float = 5.4
var cam_yaw: float = -3.14159    # Radians: Looking straight along Z towards +Z (ocean)
var cam_pitch: float = 0.34      # Radians: ~19.5 degrees pitch down (eye-level 3/4 rear-side angle)

const DEFAULT_DISTANCE: float = 5.4
const DEFAULT_YAW: float = -3.14159
const DEFAULT_PITCH: float = 0.34

var is_dragging: bool = false
var drag_last_pos: Vector2 = Vector2.ZERO
var sim_time: float = 0.0

func _ready() -> void:
	print("⚓ [CozyFishing3D] Initialized Forward+ Vulkan 3D Shoreline Showcase")
	_update_camera_transform()
	_setup_materials()
	_export_glb_model()

	if return_btn:
		return_btn.pressed.connect(_on_return_btn_pressed)

	_auto_capture_screenshot()

func _auto_capture_screenshot() -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var out_path = "C:/Users/user/.gemini/antigravity/brain/6e0b9e30-bb2d-4fba-b300-f31fbe670511/screenshot_cozy_3d.png"
	var err = img.save_png(out_path)
	print("📸 Saved 3D showcase screenshot: ", out_path, " err: ", err)
	if "--capture-exit" in OS.get_cmdline_args():
		get_tree().quit(0)

func _process(delta: float) -> void:
	sim_time += delta

	# 1. Ocean Water & Shoreline Foam Breathing
	var wave_bob = sin(sim_time * 2.2) * 0.025
	if water_mesh:
		water_mesh.position.y = wave_bob * 0.4
	if foam_mesh:
		foam_mesh.position.z = 0.02 + sin(sim_time * 1.6) * 0.04
		foam_mesh.position.y = 0.015 + wave_bob * 0.25
	if foam_fine_mesh:
		foam_fine_mesh.position.z = 0.35 + cos(sim_time * 1.4) * 0.05

	# 2. Bobber Float & Pulsing Water Ripples
	if bobber_node:
		bobber_node.position.y = 0.02 + wave_bob
		bobber_node.rotation.z = sin(sim_time * 2.6) * 0.08
		bobber_node.rotation.x = cos(sim_time * 2.1) * 0.05
		var ripple = bobber_node.get_node_or_null("Ripple") as MeshInstance3D
		if ripple:
			var pulse = 1.0 + sin(sim_time * 3.5) * 0.16
			ripple.scale = Vector3(pulse, 1.0, pulse)

	# 3. Scuttling Red Crab (Googly eyes, claws, side-to-side walk along shoreline)
	if crab_node:
		var crab_t = sim_time * 1.4
		crab_node.position.x = -1.3 + sin(crab_t) * 0.25
		crab_node.position.z = 0.18 + cos(crab_t * 0.7) * 0.07
		crab_node.rotation.z = sin(sim_time * 6.0) * 0.05
		var claw_l = crab_node.get_node_or_null("ClawL") as MeshInstance3D
		var claw_r = crab_node.get_node_or_null("ClawR") as MeshInstance3D
		if claw_l and claw_r:
			var pinch = sin(sim_time * 4.0) * 0.12
			claw_l.rotation.y = 0.5 + pinch
			claw_r.rotation.y = -0.5 - pinch

	# 4. Seagull Soaring & Banking in Upper Right Quadrant
	if seagull_node:
		var gull_t = sim_time * 0.55
		seagull_node.position.x = -2.1 + cos(gull_t) * 0.35
		seagull_node.position.z = 2.2 + sin(gull_t) * 0.30
		seagull_node.position.y = 1.85 + sin(sim_time * 1.6) * 0.08
		seagull_node.rotation.z = sin(sim_time * 2.5) * 0.12 # Wing bank tilt

	# 5. Swimming Fish under Water Surface
	if fish1:
		var f1_t = sim_time * 0.75
		fish1.position.x = -0.7 + cos(f1_t) * 0.30
		fish1.position.z = 1.8 + sin(f1_t) * 0.25
		fish1.rotation.y = -f1_t + PI * 0.5
		var tail1 = fish1.get_node_or_null("Tail1") as MeshInstance3D
		if tail1:
			tail1.rotation.y = sin(sim_time * 6.5) * 0.35

	if fish2:
		var f2_t = sim_time * 0.55
		fish2.position.x = -2.1 + sin(f2_t) * 0.40
		fish2.position.z = 3.2 + cos(f2_t) * 0.30
		fish2.rotation.y = f2_t
		var tail2 = fish2.get_node_or_null("Tail2") as MeshInstance3D
		if tail2:
			tail2.rotation.y = sin(sim_time * 5.5) * 0.30

	# 6. Fisherman Breathing & Subtle Rod Flex
	if fisherman_node:
		var breath = sin(sim_time * 2.2) * 0.008
		fisherman_node.position.y = 0.42 + breath
	if rod_node:
		rod_node.rotation.z = 0.707107 + sin(sim_time * 2.5) * 0.015

	_update_camera_transform()

func _update_camera_transform() -> void:
	if not camera:
		return
	var h_dist = cam_distance * cos(cam_pitch)
	var cam_x = pivot.x + h_dist * sin(cam_yaw)
	var cam_y = pivot.y + cam_distance * sin(cam_pitch)
	var cam_z = pivot.z + h_dist * cos(cam_yaw)

	camera.position = Vector3(cam_x, cam_y, cam_z)
	camera.look_at(pivot, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			drag_last_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_distance = clamp(cam_distance - 0.4, 2.5, 12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_distance = clamp(cam_distance + 0.4, 2.5, 12.0)
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - drag_last_pos
		drag_last_pos = event.position
		cam_yaw -= delta.x * 0.007
		cam_pitch = clamp(cam_pitch + delta.y * 0.005, 0.1, 1.4)

	# Keyboard orbit & zoom controls
	if event.is_action_pressed("ui_left"):
		cam_yaw -= 0.08
	elif event.is_action_pressed("ui_right"):
		cam_yaw += 0.08
	elif event.is_action_pressed("ui_up"):
		cam_pitch = clamp(cam_pitch + 0.05, 0.1, 1.4)
	elif event.is_action_pressed("ui_down"):
		cam_pitch = clamp(cam_pitch - 0.05, 0.1, 1.4)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Reset to Steam Capsule Signature View
			cam_distance = DEFAULT_DISTANCE
			cam_yaw = DEFAULT_YAW
			cam_pitch = DEFAULT_PITCH
		elif event.keycode == KEY_W:
			cam_distance = clamp(cam_distance - 0.3, 2.5, 12.0)
		elif event.keycode == KEY_S:
			cam_distance = clamp(cam_distance + 0.3, 2.5, 12.0)
		elif event.keycode == KEY_V or event.keycode == KEY_ESCAPE:
			_on_return_btn_pressed()

func _on_return_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")

func _setup_materials() -> void:
	# Guarantee Cel-Shaded Toon lighting on all StandardMaterial3D instances
	for child in find_children("*", "MeshInstance3D", true):
		var mesh_inst = child as MeshInstance3D
		if mesh_inst and mesh_inst.material_override:
			var mat = mesh_inst.material_override as StandardMaterial3D
			if mat:
				mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON

func _export_glb_model() -> void:
	var glb_dir = "res://assets/models"
	if not DirAccess.dir_exists_absolute(glb_dir):
		DirAccess.make_dir_recursive_absolute(glb_dir)

	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_scene(self, gltf_state)
	if err == OK:
		var export_path = "res://assets/models/cozy_fishing_shoreline.glb"
		var write_err = gltf_doc.write_to_filesystem(gltf_state, export_path)
		if write_err == OK:
			print("✅ [CozyFishing3D] Successfully exported 3D model to: ", export_path)
		else:
			print("⚠️ [CozyFishing3D] Failed to write GLTF file: ", write_err)

func math_fmod(a: float, b: float) -> float:
	return a - b * floor(a / b)
