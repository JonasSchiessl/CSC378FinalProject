extends Node2D
class_name TowerPlacementSystem

# References
@export var player: Player  # Reference to the player (optional if using auto-find)
@export var tower_scene: PackedScene  # The tower scene to instantiate
@export var grid_size: float = 64.0  # Size of each grid cell
@export var placement_range: int = 1  # How many cells away from player (1 = 3x3 grid)

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
		# Since TowerPlacementSystem is a child of Player, get the parent
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

# Check if a grid position is within placement range of the player
func is_within_placement_range(grid_pos: Vector2i) -> bool:
	var player_grid_pos = world_to_grid(player.global_position)
	var distance = abs(grid_pos.x - player_grid_pos.x) + abs(grid_pos.y - player_grid_pos.y)
	
	# Check if within the placement range (Manhattan distance)
	return (abs(grid_pos.x - player_grid_pos.x) <= placement_range and 
			abs(grid_pos.y - player_grid_pos.y) <= placement_range)

# Check if a position is valid for placement
func is_valid_placement(grid_pos: Vector2i) -> bool:
	# Check if within range
	if not is_within_placement_range(grid_pos):
		return false
	
	# Check if position is already occupied
	if occupied_positions.has(grid_pos):
		return false
	
	# You can add more checks here (e.g., terrain type, obstacles)
	
	return true

# Update the preview tower position
func update_preview_position() -> void:
	# Get mouse position in world
	var mouse_pos = get_global_mouse_position()
	
	# Convert to grid position
	current_grid_position = world_to_grid(mouse_pos)
	
	# Check if placement is valid
	can_place = is_valid_placement(current_grid_position)
	
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
	else:
		# Fallback: just make it transparent
		preview_tower.modulate = valid_placement_color

# Hide the preview tower
func hide_preview() -> void:
	if preview_tower:
		preview_tower.queue_free()
		preview_tower = null

# Attempt to place a tower at current position
func attempt_place_tower() -> void:
	if not can_place:
		# Play error sound or show feedback
		print("Cannot place tower here!")
		return
	
	if not tower_scene:
		push_error("TowerPlacementSystem: No tower scene assigned!")
		return
	
	# Create the actual tower
	var new_tower = tower_scene.instantiate()
	
	# Add to the scene tree (to parent of this system, or a dedicated container)
	get_parent().add_child(new_tower)
	
	# Set position
	new_tower.global_position = grid_to_world(current_grid_position)
	
	# Mark position as occupied
	occupied_positions[current_grid_position] = new_tower
	placed_towers.append(new_tower)
	
	# Initialize the tower (if it has an init method)
	if new_tower.has_method("initialize"):
		new_tower.initialize()
	
	print("Tower placed at grid position: ", current_grid_position)
	
	# You might want to hide preview after placement or keep it for continuous placement
	# hide_preview()

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
