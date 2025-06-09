extends Control
class_name BuildUI

var player: Player = null
var tower_placement_system: Node = null

# UI Elements
@onready var start_fight_button: TextureButton = $StartFightButton
@onready var phase_info_label: RichTextLabel = $PhaseScreen/PhaseInfoLabel
@onready var instruction_label: RichTextLabel = $InfoScreen/InstructionLabel

# Signals
signal fight_phase_requested()

func _ready():
	
	tower_placement_system = get_tower_placement_system()
	print("=== BUILD UI _ready() CALLED ===")
	print("BuildUI node created")
	print("BuildUI position: ", position)
	print("BuildUI global_position: ", global_position)
	print("BuildUI size: ", size)
	print("BuildUI visible: ", visible)
	
	visible = true
	print("BuildUI visible after setting true: ", visible)
	
	# Check if child nodes exist
	if start_fight_button:
		print("Start fight button found: ", start_fight_button.name)
		print("Button position: ", start_fight_button.position)
		print("Button visible: ", start_fight_button.visible)
	else:
		print("ERROR: Start fight button not found!")
	
	if phase_info_label:
		print("Phase info label found: ", phase_info_label.name)
	else:
		print("ERROR: Phase info label not found!")
	
	if instruction_label:
		print("Instruction label found: ", instruction_label.name)
	else:
		print("ERROR: Instruction label not found!")
	
	# Connect to GameManager if available
	if GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
		print("BuildUI connected to GameManager")
	else:
		print("BuildUI: No GameManager found - using fallback")
	
	print("=== BUILD UI _ready() COMPLETE ===")

func show_build_ui(phase_info: String = ""):
	print("=== SHOW_BUILD_UI CALLED ===")
	print("Phase info: ", phase_info)
	print("Current visible state: ", visible)
	
	visible = true
	print("Visible after setting true: ", visible)
	print("Global position: ", global_position)
	print("Size: ", size)
	
	# Update phase info
	if phase_info_label and phase_info != "":
		phase_info_label.text = phase_info
		phase_info_label.visible = true
		print("Phase info updated: ", phase_info)
	elif phase_info_label:
		phase_info_label.visible = false
		print("Phase info label hidden (no text)")
	else:
		print("ERROR: No phase_info_label found!")
	
	# Update instruction
	if instruction_label:
		instruction_label.visible = true
		print("Instruction label shown")
	else:
		print("ERROR: No instruction_label found!")
	
	# Enable the button
	if start_fight_button:
		start_fight_button.disabled = false
		start_fight_button.visible = true
		print("Fight button enabled and visible")
	else:
		print("ERROR: No start_fight_button found!")
	
	print("=== SHOW_BUILD_UI COMPLETE ===")

func hide_build_ui():
	print("=== HIDE_BUILD_UI CALLED ===")
	visible = false
	print("BuildUI hidden")

func _on_start_fight_pressed():
	"""Handle start fight button press"""
	print("Start Fight button pressed!")
	# Emit signal to start fight phase
	fight_phase_requested.emit()
	
	# Hide the UI
	hide_build_ui()

func _on_phase_changed(new_phase):
	"""Handle phase changes from GameManager"""
	match new_phase:
		GameManager.Phase.BUILD:
			# UI will be shown by the level manager when needed
			pass
		GameManager.Phase.FIGHT:
			hide_build_ui()


func _on_fight_button_is_pressed() -> void:
	_on_start_fight_pressed()


func _on_turret_button_pressed() -> void:
	print("Turret tower selected")
	# Get reference to tower placement system
	var tower_system = get_tower_placement_system()
	if tower_system:
		tower_system.select_tower(2)  # Turret is index 2 in your array

func _on_tesla_button_pressed() -> void:
	print("Tesla tower selected") 
	var tower_system = get_tower_placement_system()
	if tower_system:
		tower_system.select_tower(0)  # Tesla is index 0 in your array

func _on_fire_button_pressed() -> void:
	print("Fire/Lava tower selected")
	var tower_system = get_tower_placement_system()
	if tower_system:
		tower_system.select_tower(1) 

func get_tower_placement_system():
	"""Helper function to get the tower placement system"""
	# Method 1: Look in groups first (most reliable)
	var tower_systems = get_tree().get_nodes_in_group("tower_placement")
	if tower_systems.size() > 0:
		return tower_systems[0]
	
	# Method 2: Look for it as a child of player (only if player exists)
	if player and player.has_node("TowerPlacementSystem"):
		return player.get_node("TowerPlacementSystem")
	
	# Method 3: Search by class name in the scene
	var current_scene = get_tree().current_scene
	for child in current_scene.get_children():
		if child.get_script() and child.get_script().has_method("select_tower"):
			return child
		# Also check grandchildren
		for grandchild in child.get_children():
			if grandchild.get_script() and grandchild.get_script().has_method("select_tower"):
				return grandchild
	
	# Method 4: Find by name
	var tower_system = get_tree().current_scene.find_child("TowerPlacementSystem", true, false)
	if tower_system:
		return tower_system
	
	print("Warning: Could not find TowerPlacementSystem!")
	return null
