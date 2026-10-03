extends Control

@onready var overworld = get_tree().root.find_child("Overworld", true, false)

@onready var btn_river: Button = $CenterContainer/Panel/VBox/CardsGrid/RiverCard/VBox/SailBtn
@onready var btn_volcanic: Button = $CenterContainer/Panel/VBox/CardsGrid/VolcanicCard/VBox/SailBtn
@onready var btn_ocean: Button = $CenterContainer/Panel/VBox/CardsGrid/OceanCard/VBox/SailBtn
@onready var btn_subspace: Button = $CenterContainer/Panel/VBox/CardsGrid/SubspaceCard/VBox/SailBtn
@onready var close_btn: Button = $CenterContainer/Panel/VBox/CloseBtn

func _ready() -> void:
	visible = false
	btn_river.pressed.connect(func(): _sail_to("River"))
	btn_volcanic.pressed.connect(func(): _sail_to("Volcanic"))
	btn_ocean.pressed.connect(func(): _sail_to("Ocean"))
	btn_subspace.pressed.connect(func(): _sail_to("Subspace 0x00"))
	close_btn.pressed.connect(func(): 
		AudioManager.play_click()
		visible = false
	)

func _process(_delta: float) -> void:
	if visible:
		# Update button states based on player level
		btn_volcanic.disabled = GameManager.level < 50
		btn_volcanic.text = "Set Sail" if GameManager.level >= 50 else "Locked (Lv. 50)"

		btn_ocean.disabled = GameManager.level < 100
		btn_ocean.text = "Set Sail" if GameManager.level >= 100 else "Locked (Lv. 100)"

func _sail_to(biome_name: String) -> void:
	AudioManager.play_click()
	if overworld and overworld.has_method("travel_to_biome"):
		overworld.travel_to_biome(biome_name)
	visible = false
