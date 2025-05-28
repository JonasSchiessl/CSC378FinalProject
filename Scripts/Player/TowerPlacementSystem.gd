extends Node2D
class_name TowerPlacementSystem

# References
@export var player: Player  # Reference to the player 
@export var tower_scene: PackedScene  # The tower scene to instantiate
@export var grid_size: float = 64.0  # Size of each grid cell
@export var tower_spacing: int = 1  # Minimum grid cells between towers (1 = 3x3 exclusion zone)

# Preview system
var preview_tower: Node2D = null  # The ghost/preview tower
var current_grid_position: Vector2i = Vector2i.ZERO
var can_place: bool = false

# Visual feedback
@export var valid_placement_color: Color = Color(0, 1, 0, 0.5)  # Green with transparency
@export var invalid_placement_color: Color = Color(1, 0, 0, 0.5)  # Red with transparency

# Tower management
var placed_towers: Array[Node2D] = []  # Keep track of all placed towers
var occupied_positions: Dictionary = {}  # Track which grid positions are occupied

func _ready() -> void:
	# Auto-find player if not set in inspector
	if not player:
		player = get_parent() as Player
		if not player:
			push_error("TowerPlacementSystem: Could not find Player as parent! Make sure this is a child of the Player node.")
			return
	
	# Connect to phase changes
	if GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	
	# Set initial visibility
	visible = GameManager.instance and GameManager.instance.is_build_phase()

func _process(_delta: float) -> void:
	# Only process during build phase
	if not GameManager.instance or not GameManager.instance.is_build_phase():
		return
	
	if not player:
		push_error("TowerPlacementSystem: No player reference set!")
		return
	
	# Update preview position based on mouse
	update_preview_position()
	
	# Redraw debug visualization if needed
	if OS.is_debug_build() and visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	# Only handle input during build phase
	if not GameManager.instance or not GameManager.instance.is_build_phase():
		return
	
	# Place tower on click
	if event.is_action_pressed("placeTower"):  # You'll need to add this to input map (left click)
		attempt_place_tower()
	
	# Cancel placement with right click
	if event.is_action_pressed("cancelPlacement"):  # Right click
		hide_preview()

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
	# This accounts for the player being slightly off-grid
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
	
	#Future: we can add more checks here
	
	return true

# Get detailed reason why placement is invalid (useful for UI feedback)
func get_placement_error(grid_pos: Vector2i) -> String:
	if occupied_positions.has(grid_pos):
		return "Position occupied"
	elif is_too_close_to_tower(grid_pos):
		return "Too close to another tower"
	elif is_on_player(grid_pos):
		return "Cannot place on player"
	else:
		return ""  # Valid placement

# Update the preview tower position
func update_preview_position() -> void:
	# Get mouse position in world
	var mouse_pos = get_global_mouse_position()
	
	# Convert to grid position
	current_grid_position = world_to_grid(mouse_pos)
	
	# Check if placement is valid
	can_place = is_valid_placement(current_grid_position)
	
	# Debug: Print when hovering over player
	if is_on_player(current_grid_position) and OS.is_debug_build():
		print("Preview is on player position - should be RED")
	
	# Show or create preview if needed
	if not preview_tower:
		show_preview()
	
	# Update preview position and appearance
	if preview_tower:
		preview_tower.global_position = grid_to_world(current_grid_position)
		
		# Update color based on validity
		if preview_tower.has_method("set_preview_state"):
			preview_tower.set_preview_state(can_place)
		else:
			# Fallback: just change modulate
			preview_tower.modulate = valid_placement_color if can_place else invalid_placement_color

# Show the preview tower
func show_preview() -> void:
	if not tower_scene:
		push_error("TowerPlacementSystem: No tower scene assigned!")
		return
	
	# Create preview instance
	preview_tower = tower_scene.instantiate()
	add_child(preview_tower)
	
	# Set as preview mode
	if preview_tower.has_method("set_preview_mode"):
		preview_tower.set_preview_mode(true)
	
	# Set initial color based on current validity
	if preview_tower.has_method("set_preview_state"):
		preview_tower.set_preview_state(can_place)
	else:
		# Fallback: set the modulate directly
		preview_tower.modulate = valid_placement_color if can_place else invalid_placement_color

# Hide the preview tower
func hide_preview() -> void:
	if preview_tower:
		preview_tower.queue_free()
		preview_tower = null

# Attempt to place a tower at current position
func attempt_place_tower() -> void:
	if not can_place:
		# Provide specific feedback about why placement failed
		if occupied_positions.has(current_grid_position):
			print("Cannot place tower: Position already occupied!")
		elif is_too_close_to_tower(current_grid_position):
			print("Cannot place tower: Too close to another tower!")
		elif is_on_player(current_grid_position):
			print("Cannot place tower: Cannot place on player!")
		else:
			print("Cannot place tower here!")
		return
	
	if not tower_scene:
		push_error("TowerPlacementSystem: No tower scene assigned!")
		return
	
	# Create the actual tower
	var new_tower = tower_scene.instantiate()
	
	# CRITICAL: Add tower to the game world, not to the player!
	var game_root = get_tree().current_scene
	game_root.add_child(new_tower)
	
	# IMPORTANT: Use global_position to place the tower in world space
	# This ensures the position is absolute, not relative to any parent
	var world_position = grid_to_world(current_grid_position)
	new_tower.global_position = world_position
	
	# Mark position as occupied
	occupied_positions[current_grid_position] = new_tower
	placed_towers.append(new_tower)
	
	#Initialize the tower
	if new_tower.has_method("initialize"):
		new_tower.initialize()
	
	print("Tower placed at world position: ", world_position)
	
	# Update debug visualization if in debug mode
	if OS.is_debug_build():
		queue_redraw()
	

# Handle phase changes
func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	match new_phase:
		GameManager.Phase.BUILD:
			visible = true
			# Show preview again if needed
		GameManager.Phase.FIGHT:
			visible = false
			hide_preview()

# Get all placed towers
func get_all_towers() -> Array[Node2D]:
	return placed_towers

# Remove a tower (if needed)
func remove_tower(tower: Node2D) -> void:
	# Find and remove from occupied positions
	for pos in occupied_positions:
		if occupied_positions[pos] == tower:
			occupied_positions.erase(pos)
			break
	
	# Remove from placed towers array
	placed_towers.erase(tower)
	
	# Remove from scene
	tower.queue_free()
	
	# Update debug visualization
	if OS.is_debug_build():
		queue_redraw()

"""
# Debug visualization (optional - remove in production)
func _draw() -> void:
	if not visible or not GameManager.instance or not GameManager.instance.is_build_phase():
		return
	
	# Draw exclusion zones around existing towers (helpful for debugging)
	if OS.is_debug_build():  # Only in debug builds
		# Draw tower exclusion zones
		for tower_pos in occupied_positions:
			var world_pos = grid_to_world(tower_pos)
			var local_pos = to_local(world_pos)
			
			# Draw the exclusion zone
			var exclusion_size = (tower_spacing * 2 + 1) * grid_size
			var rect = Rect2(
				local_pos - Vector2(exclusion_size / 2, exclusion_size / 2),
				Vector2(exclusion_size, exclusion_size)
			)
			draw_rect(rect, Color(1, 0, 0, 0.1))  # Light red fill
			draw_rect(rect, Color(1, 0, 0, 0.3), false, 2.0)  # Red outline
		
		# Draw player's grid position (blue square)
		if player:
			var player_grid_pos = world_to_grid(player.global_position)
			var player_world_pos = grid_to_world(player_grid_pos)
			var player_local_pos = to_local(player_world_pos)
			
			var player_rect = Rect2(
				player_local_pos - Vector2(grid_size / 2, grid_size / 2),
				Vector2(grid_size, grid_size)
			)
			draw_rect(player_rect, Color(0, 0, 1, 0.2))  # Light blue fill
			draw_rect(player_rect, Color(0, 0, 1, 0.5), false, 3.0)  # Blue outline
"""
