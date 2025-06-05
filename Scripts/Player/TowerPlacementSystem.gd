extends Node2D
class_name TowerPlacementSystem

# References
@export var player: Player  # Reference to the player 
@export var grid_size: float = 64.0  # Size of each grid cell
@export var tower_spacing: int = 1  # Minimum grid cells between towers (1 = 3x3 exclusion zone)

# Multiple tower scenes
@export var tesla_tower_scene: PackedScene  # TeslaTower.tscn
@export var lava_tower_scene: PackedScene   # LavaTower.tscn
@export var turret_tower_scene: PackedScene # TurretTower.tscn

# Tower selection
var selected_tower_index: int = 0  # 0 = Tesla, 1 = Lava, 2 = Turret
var tower_scenes: Array[PackedScene] = []
var tower_type_names: Array[String] = ["tesla_tower", "lava_tower", "turret_tower"]
var tower_display_names: Array[String] = ["Tesla Tower", "Lava Tower", "Turret Tower"]

var preview_tower: Node2D = null  # The ghost/preview tower
var current_grid_position: Vector2i = Vector2i.ZERO
var can_place: bool = false

@export var valid_placement_color: Color = Color(0, 1, 0, 0.5)  # Green with transparency
@export var invalid_placement_color: Color = Color(1, 0, 0, 0.5)  # Red with transparency

# Tower management
var placed_towers: Array[Node2D] = []  # Keep track of all placed towers
var occupied_positions: Dictionary = {}  # Track which grid positions are occupied

# Cost defaults for each tower type
@export var tesla_tower_cost: int = 100
@export var lava_tower_cost: int = 150
@export var turret_tower_cost: int = 75

# Visual feedback for affordability
@export var affordable_preview_color: Color = Color(0, 1, 0, 0.5)  # Green when affordable
@export var unaffordable_preview_color: Color = Color(1, 0, 0, 0.5)  # Red when can't afford

# Add these variables to track affordability state
var can_afford_tower: bool = true
var last_affordability_check: float = 0.0
var affordability_check_interval: float = 0.1  # Check 10 times per second

func _ready() -> void:
	# Initialize tower scenes array
	tower_scenes = [tesla_tower_scene, lava_tower_scene, turret_tower_scene]
	
	# Auto-find player if not set in inspector
	if not player:
		player = get_parent() as Player
		if not player:
			push_error("TowerPlacementSystem: Could not find Player as parent! Make sure this is a child of the Player node.")
			return
	
	# Connect to phase changes
	if GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	
	# Connect to currency changes to update affordability in real-time
	if CurrencyManager:
		CurrencyManager.currency_changed.connect(_on_currency_changed)
		# Set up costs for each tower type
		setup_tower_costs()
		# Initial affordability check
		update_affordability()
	else:
		push_error("TowerPlacementSystem: CurrencyManager not found!")
		
	visible = GameManager.instance and GameManager.instance.is_build_phase()
	
	# Validate tower scenes
	validate_tower_scenes()

func validate_tower_scenes() -> void:
	"""Ensure all tower scenes are properly assigned"""
	var missing_scenes: Array[String] = []
	
	if not tesla_tower_scene:
		missing_scenes.append("Tesla Tower")
	if not lava_tower_scene:
		missing_scenes.append("Lava Tower")
	if not turret_tower_scene:
		missing_scenes.append("Turret Tower")
	
	if missing_scenes.size() > 0:
		push_error("TowerPlacementSystem: Missing tower scenes: " + str(missing_scenes))

func setup_tower_costs() -> void:
	"""Initialize tower costs in the CurrencyManager"""
	if CurrencyManager:
		CurrencyManager.set_tower_cost("tesla_tower", tesla_tower_cost)
		CurrencyManager.set_tower_cost("lava_tower", lava_tower_cost)
		CurrencyManager.set_tower_cost("turret_tower", turret_tower_cost)

func _process(delta: float) -> void:
	# Only process during build phase
	if not GameManager.instance or not GameManager.instance.is_build_phase():
		return
	
	if not player:
		push_error("TowerPlacementSystem: No player reference set!")
		return
	
	update_preview_position()
	
	last_affordability_check += delta
	if last_affordability_check >= affordability_check_interval:
		update_affordability()
		last_affordability_check = 0.0
	
	# Redraw debug visualization if enabled
	if OS.is_debug_build() and visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	# Only handle input during build phase
	if not GameManager.instance or not GameManager.instance.is_build_phase():
		return
	
	# Tower selection with number keys
	if event.is_action_pressed("select_tower_1"): 
		select_tower(0)
	elif event.is_action_pressed("select_tower_2"):
		select_tower(1)
	elif event.is_action_pressed("select_tower_3"):
		select_tower(2)
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				select_tower(0)
			KEY_2:
				select_tower(1)
			KEY_3:
				select_tower(2)
	
	# Place with left click
	if event.is_action_pressed("placeTower"):  
		attempt_place_tower()
	
	# Cancel placement with right click
	if event.is_action_pressed("cancelPlacement"): 
		hide_preview()

func select_tower(index: int) -> void:
	"""Select a tower type by index (0-2)"""
	if index < 0 or index >= tower_scenes.size():
		return
	
	if index == selected_tower_index:
		return  # Already selected
	
	selected_tower_index = index
	
	print("Selected: ", tower_display_names[selected_tower_index], " (Cost: ", get_current_tower_cost(), ")")
	
	# Update affordability for new tower type
	update_affordability()
	
	# Refresh preview with new tower type
	if preview_tower:
		hide_preview()
		show_preview()

func get_current_tower_scene() -> PackedScene:
	"""Get the currently selected tower scene"""
	if selected_tower_index >= 0 and selected_tower_index < tower_scenes.size():
		return tower_scenes[selected_tower_index]
	return null

func get_current_tower_type() -> String:
	"""Get the currently selected tower type name"""
	if selected_tower_index >= 0 and selected_tower_index < tower_type_names.size():
		return tower_type_names[selected_tower_index]
	return ""

func get_current_tower_cost() -> int:
	"""Get the cost of the currently selected tower"""
	var tower_type = get_current_tower_type()
	if CurrencyManager:
		return CurrencyManager.get_item_cost(tower_type, "tower")
	else:
		# Fallback to exported costs
		match selected_tower_index:
			0: return tesla_tower_cost
			1: return lava_tower_cost
			2: return turret_tower_cost
			_: return 100

# Calculate grid position from world position
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / grid_size)),
		int(round(world_pos.y / grid_size))
	)

# Convert grid position back to world position
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * grid_size, grid_pos.y * grid_size)

# Check if a grid position is too close to any existing tower
func is_too_close_to_tower(grid_pos: Vector2i) -> bool:
	# Check each placed tower
	for tower_pos in occupied_positions:
		# Calculate Manhattan distance to this tower
		var distance_x = abs(grid_pos.x - tower_pos.x)
		var distance_y = abs(grid_pos.y - tower_pos.y)
		
		# If within the spacing requirement, it's too close
		if distance_x <= tower_spacing and distance_y <= tower_spacing:
			return true
	
	return false

# Check if a grid position is on the player
func is_on_player(grid_pos: Vector2i) -> bool:
	if not player:
		return false
	
	# Get the world position of the grid cell
	var grid_world_pos = grid_to_world(grid_pos)
	
	# Check if the player's center is within this grid cell
	# This accounts for the player being slightly off-grid (kinda? it could be better)
	var half_grid = grid_size / 2.0
	var player_pos = player.global_position
	
	# Check if player center is within the grid cell bounds
	var within_x = abs(player_pos.x - grid_world_pos.x) < half_grid
	var within_y = abs(player_pos.y - grid_world_pos.y) < half_grid
	
	return within_x and within_y

# Check if a position is valid for placement
func is_valid_placement(grid_pos: Vector2i) -> bool:
	# Check if position is already occupied by a tower
	if occupied_positions.has(grid_pos):
		return false
	
	# Check if too close to another tower
	if is_too_close_to_tower(grid_pos):
		return false
	
	# Check if trying to place on the player
	if is_on_player(grid_pos):
		return false
	
	if not can_afford_tower:
		return false
	
	return true

# Get detailed reason why placement is invalid (useful for UI feedback)
func get_placement_error(grid_pos: Vector2i) -> String:
	if occupied_positions.has(grid_pos):
		return "Position occupied"
	elif is_too_close_to_tower(grid_pos):
		return "Too close to another tower"
	elif is_on_player(grid_pos):
		return "Cannot place on player"
	elif not can_afford_tower:
		var cost = get_current_tower_cost()
		var current = CurrencyManager.get_current_currency() if CurrencyManager else 0
		return "Insufficient funds for " + tower_display_names[selected_tower_index] + " (Need: " + str(cost) + ", Have: " + str(current) + ")"
	else:
		return ""  # Valid placement

# Update the preview tower position
func update_preview_position() -> void:
	var mouse_pos = get_global_mouse_position()
	
	current_grid_position = world_to_grid(mouse_pos)
	can_place = is_valid_placement(current_grid_position)
	
	# Debug: Print when hovering over player
	if is_on_player(current_grid_position) and OS.is_debug_build():
		print("Preview is on player position - should be RED")
	
	if not preview_tower:
		show_preview()
	
	if preview_tower:
		preview_tower.global_position = grid_to_world(current_grid_position)
		
		var preview_color: Color
		if not can_afford_tower:
			# Special color for insufficient funds
			preview_color = unaffordable_preview_color
		elif can_place:
			# Can place and can afford
			preview_color = affordable_preview_color
		else:
			# Can afford but can't place for other reasons
			preview_color = invalid_placement_color
		
		# Update preview appearance
		if preview_tower.has_method("set_preview_state"):
			preview_tower.set_preview_state(can_place)
		else:
			preview_tower.modulate = preview_color

# Show the preview tower
func show_preview() -> void:
	var current_scene = get_current_tower_scene()
	if not current_scene:
		push_error("TowerPlacementSystem: No tower scene available for index " + str(selected_tower_index))
		return
	
	preview_tower = current_scene.instantiate()
	add_child(preview_tower)
	
	if preview_tower.has_method("set_preview_mode"):
		preview_tower.set_preview_mode(true)
	
	if preview_tower.has_method("set_preview_state"):
		preview_tower.set_preview_state(can_place)
	else:
		# Fallback: set the modulate directly
		preview_tower.modulate = valid_placement_color if can_place else invalid_placement_color

func hide_preview() -> void:
	if preview_tower:
		preview_tower.queue_free()
		preview_tower = null

#Tower placement that handles currency transaction
func attempt_place_tower() -> void:
	if not can_place:
		# Provide specific feedback about why placement failed
		var error = get_placement_error(current_grid_position)
		print("Cannot place tower: " + error)
		
		# Special handling for currency issues
		if not can_afford_tower:
			show_insufficient_funds_feedback()
		
		return
	
	var current_scene = get_current_tower_scene()
	if not current_scene:
		push_error("TowerPlacementSystem: No tower scene available!")
		return
	
	# Attempt to purchase the tower before placing it
	var cost = get_current_tower_cost()
	var tower_type = get_current_tower_type()
	
	if not CurrencyManager or not CurrencyManager.spend_currency(cost, tower_type):
		print("Tower placement failed: Could not complete currency transaction")
		show_insufficient_funds_feedback()
		return
	
	# Currency transaction successful, proceed with placement
	place_tower_at_position(current_grid_position)
	
	# Update affordability after purchase
	update_affordability()

# Handle phase changes
func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	match new_phase:
		GameManager.Phase.BUILD:
			visible = true
			update_affordability()  # Check if we can afford towers when entering build phase
		GameManager.Phase.FIGHT:
			visible = false
			hide_preview()

func get_all_towers() -> Array[Node2D]:
	return placed_towers

func remove_tower(tower: Node2D) -> void:
	for pos in occupied_positions:
		if occupied_positions[pos] == tower:
			occupied_positions.erase(pos)
			break
	
	# Remove from placed towers array
	placed_towers.erase(tower)
	
	tower.queue_free()
	
	if OS.is_debug_build():
		queue_redraw()

func update_affordability() -> void:
	"""Update whether the player can afford to place the currently selected tower"""
	if not CurrencyManager:
		can_afford_tower = false
		return
	
	var cost = get_current_tower_cost()
	can_afford_tower = CurrencyManager.can_afford(cost)

func place_tower_at_position(grid_pos: Vector2i) -> void:
	# Create the actual tower
	var current_scene = get_current_tower_scene()
	var new_tower = current_scene.instantiate()
	
	# Add tower to the game world
	var game_root = get_tree().current_scene
	game_root.add_child(new_tower)
	
	# Position the tower
	var world_position = grid_to_world(grid_pos)
	new_tower.global_position = world_position
	
	# Mark position as occupied
	occupied_positions[grid_pos] = new_tower
	placed_towers.append(new_tower)
	
	# Initialize the tower
	if new_tower.has_method("initialize"):
		new_tower.initialize()
	
	print(tower_display_names[selected_tower_index] + " placed at ", world_position, " for ", get_current_tower_cost(), " currency")
	
	# Provide positive feedback
	show_successful_placement_feedback()

func show_insufficient_funds_feedback() -> void:
	print("Insufficient funds to place " + tower_display_names[selected_tower_index] + "!")
	
	# Flash the preview tower red to indicate the issue
	if preview_tower:
		var flash_tween = create_tween()
		flash_tween.tween_property(preview_tower, "modulate", Color.RED, 0.1)
		flash_tween.tween_property(preview_tower, "modulate", unaffordable_preview_color, 0.1)

func show_successful_placement_feedback() -> void:
	# We could add celebratory effects here:
	# Particle effect
	# Sound effect
	pass
	
func _on_currency_changed(new_amount: int, change_amount: int) -> void:
	update_affordability()
	
	if preview_tower and visible:
		update_preview_position()

func get_selected_tower_info() -> Dictionary:
	"""Get information about the currently selected tower"""
	return {
		"index": selected_tower_index,
		"name": tower_display_names[selected_tower_index],
		"type": get_current_tower_type(),
		"cost": get_current_tower_cost(),
		"can_afford": can_afford_tower
	}

# Debug function to test the currency integration
func debug_currency_integration() -> void:
	"""Debug function to test currency integration"""
	print("\n=== TOWER PLACEMENT CURRENCY DEBUG ===")
	var tower_info = get_selected_tower_info()
	print("Selected Tower: ", tower_info.name)
	print("Tower Type: ", tower_info.type)
	print("Tower Cost: ", tower_info.cost)
	print("Current Currency: ", CurrencyManager.get_current_currency() if CurrencyManager else "N/A")
	print("Can Afford: ", tower_info.can_afford)
	print("Can Place at Current Position: ", can_place)
	print("Placement Error: ", get_placement_error(current_grid_position))
	print("======================================\n")
