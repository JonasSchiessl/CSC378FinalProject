extends Node2D
class_name ProjectileEmitter

# Projectile type definitions
@export var projectile_types: Array[ProjectileType] = []
@export var default_projectile_index: int = 0
@export var universal_projectile_scene: PackedScene  # The universal projectile scene
@export var lightning_projectile_scene: PackedScene

# Collision layer configuration
@export var projectile_layer: int = 32  # What layer this emitter's projectiles are on
@export var target_mask: int = 8        # What layer this emitter's projectiles target

# Owner of this component (player/enemy)
@onready var entity = get_parent()

# Current projectile type
var current_projectile_type: ProjectileType

# Cooldown tracking - Dictionary to track last fire time for each projectile type
var last_fire_times: Dictionary = {}

func _ready() -> void:
	# Set default projectile type if available
	if projectile_types.size() > 0 and default_projectile_index < projectile_types.size():
		current_projectile_type = projectile_types[default_projectile_index]
	
	# Initialize cooldown tracking
	for projectile_type in projectile_types:
		last_fire_times[projectile_type.name] = 0.0

# Check if a projectile type is ready to fire (not on cooldown)
func can_fire_projectile(projectile_type: ProjectileType) -> bool:
	if not projectile_type:
		return false
	
	# If no cooldown, always ready
	if projectile_type.cooldown <= 0.0:
		return true
	
	# Check if enough time has passed since last fire
	var current_time = Time.get_time_dict_from_system()
	var current_seconds = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# Use engine time instead for more accuracy
	var engine_time = Time.get_time_dict_from_system()
	var time_since_last = Time.get_time_dict_from_system().second - last_fire_times.get(projectile_type.name, 0.0)
	
	
	var current_game_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var last_fire_time = last_fire_times.get(projectile_type.name, 0.0)
	
	return (current_game_time - last_fire_time) >= projectile_type.cooldown

# Fire a projectile with current type and default settings
func fire_projectile(direction: Vector2) -> bool:
	if not current_projectile_type:
		push_error("No projectile type set!")
		return false
	
	# Check cooldown
	if not can_fire_projectile(current_projectile_type):
		return false  # On cooldown, can't fire
	
	# Check if this is a lightning projectile type
	if current_projectile_type is LightningProjectileType:
		print("Auto-firing lightning projectile!")
		var lightning_type = current_projectile_type as LightningProjectileType
		var success = fire_lightning_projectile(
			direction,
			lightning_type.max_chain_count,
			lightning_type.chain_range,
			lightning_type.base_damage,
			current_projectile_type
		)
		if success:
			# Update last fire time
			last_fire_times[current_projectile_type.name] = Time.get_ticks_msec() / 1000.0
		return success
	
	# Fire regular projectile using the enhanced method
	fire_projectile_advanced_enhanced(direction, current_projectile_type.base_speed, 
			current_projectile_type.base_damage, current_projectile_type.base_range, 
			current_projectile_type.base_knockback, current_projectile_type.default_arc_height, 
			current_projectile_type.default_penetration, current_projectile_type.can_area_effect, 
			current_projectile_type.default_area_radius, current_projectile_type.can_create_lingering, 
			current_projectile_type.default_lingering_type, current_projectile_type.default_lingering_radius,
			current_projectile_type.default_lingering_duration, current_projectile_type.default_lingering_damage,
			current_projectile_type, 
			projectile_layer, 
			target_mask)
	
	# Update last fire time
	last_fire_times[current_projectile_type.name] = Time.get_ticks_msec() / 1000.0
	return true

# Fire a projectile by type name
func fire_projectile_by_name(projectile_name: String, direction: Vector2) -> bool:
	var projectile_type = get_projectile_type_by_name(projectile_name)
	if not projectile_type:
		push_error("Projectile type '" + projectile_name + "' not found!")
		return false
	
	# Check cooldown
	if not can_fire_projectile(projectile_type):
		return false
	
	fire_projectile_with_type(projectile_type, direction)
	
	# Update last fire time
	last_fire_times[projectile_type.name] = Time.get_ticks_msec() / 1000.0
	return true

# Fire a projectile by index
func fire_projectile_by_index(index: int, direction: Vector2) -> bool:
	if index < 0 or index >= projectile_types.size():
		push_error("Projectile index " + str(index) + " out of range!")
		return false
	
	var projectile_type = projectile_types[index]
	
	# Check cooldown
	if not can_fire_projectile(projectile_type):
		return false
	
	fire_projectile_with_type(projectile_type, direction)
	
	# Update last fire time
	last_fire_times[projectile_type.name] = Time.get_ticks_msec() / 1000.0
	return true

# Fire a projectile with a specific ProjectileType
func fire_projectile_with_type(projectile_type: ProjectileType, direction: Vector2) -> bool:
	if not projectile_type:
		push_error("Invalid projectile type!")
		return false
	
	# Check cooldown
	if not can_fire_projectile(projectile_type):
		return false
	
	fire_projectile_advanced(direction, projectile_type.base_speed, 
							projectile_type.base_damage, projectile_type.base_range, 
							projectile_type.base_knockback, projectile_type.default_arc_height, 
							projectile_type.default_penetration, projectile_type.can_area_effect, 
							projectile_type.default_area_radius, projectile_type.can_create_lingering, 
							projectile_type.default_lingering_type, projectile_type.default_lingering_radius,
							projectile_type.default_lingering_duration, projectile_type.default_lingering_damage,
							projectile_type)
	
	# Update last fire time
	last_fire_times[projectile_type.name] = Time.get_ticks_msec() / 1000.0
	return true
	
func fire_lightning_projectile(direction: Vector2, chains: int = 3, 
								chain_range: float = 200.0, damage: float = 8.0,
								projectile_type_override: ProjectileType = null) -> bool:
	
	var projectile_type_to_use = projectile_type_override if projectile_type_override else current_projectile_type
	
	# Check cooldown if using current projectile type
	if not projectile_type_override and not can_fire_projectile(current_projectile_type):
		return false
	
	if not lightning_projectile_scene:
		push_error("No lightning projectile scene set!")
		return false
	
	# Create lightning projectile instance
	var lightning_projectile = lightning_projectile_scene.instantiate()
	
	# Add to scene first
	get_tree().current_scene.add_child(lightning_projectile)
	
	# Create attack
	var attack = Attack.new(
		damage,
		direction * (projectile_type_to_use.base_knockback if projectile_type_to_use else 50.0),
		entity
	)
	
	# Apply any special effects from projectile type
	if projectile_type_to_use:
		for effect_name in projectile_type_to_use.get_active_effects():
			var strength = projectile_type_to_use.get_effect_strength(effect_name)
			var duration = projectile_type_to_use.get_effect_duration(effect_name)
			attack.apply_effect(effect_name, strength, duration)
	
	# Setup lightning projectile with parameters - PASS THE PROJECTILE TYPE!
	lightning_projectile.setup(attack, global_position, direction, chains, chain_range,
							   projectile_layer, target_mask, projectile_type_to_use)
	
	# Update last fire time if using current projectile type
	if not projectile_type_override and current_projectile_type:
		last_fire_times[current_projectile_type.name] = Time.get_ticks_msec() / 1000.0
	
	return true

# Full control over projectile parameters with optional projectile type override
func fire_projectile_advanced(direction: Vector2, speed: float, damage: float, 
							proj_range: float, knockback: float, arc_height: float = 0.0,
							penetration: int = 0, area_effect: bool = false,
							area_radius: float = 100.0, lingering: bool = false,
							lingering_type: String = "fire", lingering_radius: float = 100.0,
							lingering_duration: float = 5.0, lingering_damage: float = 1.0,
							projectile_type_override: ProjectileType = null,
							override_collision_layer: int = -1,
							override_collision_mask: int = -1) -> void:
	
	var projectile_type_to_use = projectile_type_override if projectile_type_override else current_projectile_type
	
	if not universal_projectile_scene:
		push_error("No universal projectile scene set!")
		return
	
	# Create projectile instance from universal scene
	var projectile = universal_projectile_scene.instantiate()
	
	# Create attack
	var attack = Attack.new(
		damage,
		direction * knockback,
		entity
	)
	
	# Apply any special effects from projectile type
	if projectile_type_to_use:
		for effect_name in projectile_type_to_use.default_effects.keys():
			var effect_data = projectile_type_to_use.default_effects[effect_name]
			attack.apply_effect(effect_name, effect_data.strength, effect_data.duration)
	
	# IMPORTANT: Add to scene FIRST, then set position
	get_tree().current_scene.add_child(projectile)
	
	# Set initial position AFTER adding to scene tree
	# Use global_position to ensure correct world positioning
	projectile.global_position = global_position
	
	# Determine collision layers to use
	var use_collision_layer = override_collision_layer if override_collision_layer != -1 else projectile_layer
	var use_collision_mask = override_collision_mask if override_collision_mask != -1 else target_mask
	
	
	# Set up projectile with all parameters AFTER positioning
	projectile.setup(attack, direction, speed, proj_range, arc_height, 
					penetration, area_effect, area_radius,
					lingering, lingering_type, lingering_radius,
					lingering_duration, lingering_damage, projectile_type_to_use,
					use_collision_layer, use_collision_mask)
	
	# Set lingering effect scene if needed
	if lingering and projectile.create_lingering_effect and projectile_type_to_use and projectile_type_to_use.lingering_effect_scene:
		projectile.lingering_effect_scene = projectile_type_to_use.lingering_effect_scene

func fire_projectile_advanced_enhanced(direction: Vector2, speed: float, damage: float, 
									   proj_range: float, knockback: float, arc_height: float = 0.0,
									   penetration: int = 0, area_effect: bool = false,
									   area_radius: float = 100.0, lingering: bool = false,
									   lingering_type: String = "fire", lingering_radius: float = 100.0,
									   lingering_duration: float = 5.0, lingering_damage: float = 1.0,
									   projectile_type_override: ProjectileType = null,
									   override_collision_layer: int = -1,
									   override_collision_mask: int = -1,
									   # New lightning parameters
									   chains: int = 0, chain_range: float = 200.0) -> void:
	
	var projectile_type_to_use = projectile_type_override if projectile_type_override else current_projectile_type
	
	# Check if this is a lightning projectile type
	if projectile_type_to_use and projectile_type_to_use is LightningProjectileType:
		var lightning_type = projectile_type_to_use as LightningProjectileType
		fire_lightning_projectile(direction, lightning_type.max_chain_count, 
								   lightning_type.chain_range, damage, projectile_type_to_use)
		return
	
	# Check if chains parameter suggests lightning behavior
	if chains > 0:
		fire_lightning_projectile(direction, chains, chain_range, damage, projectile_type_to_use)
		return
	
	var projectile_type_to_use_final = projectile_type_override if projectile_type_override else current_projectile_type
	
	if not universal_projectile_scene:
		push_error("No universal projectile scene set!")
		return
	
	# Create projectile instance from universal scene
	var projectile = universal_projectile_scene.instantiate()
	
	# Create attack
	var attack = Attack.new(
		damage,
		direction * knockback,
		entity
	)
	
	# Apply any special effects from projectile type
	if projectile_type_to_use_final:
		for effect_name in projectile_type_to_use_final.default_effects.keys():
			var effect_data = projectile_type_to_use_final.default_effects[effect_name]
			attack.apply_effect(effect_name, effect_data.strength, effect_data.duration)
	
	# IMPORTANT: Add to scene FIRST, then set position
	get_tree().current_scene.add_child(projectile)
	
	# Set initial position AFTER adding to scene tree
	# Use global_position to ensure correct world positioning
	projectile.global_position = global_position
	
	# Determine collision layers to use
	var use_collision_layer = override_collision_layer if override_collision_layer != -1 else projectile_layer
	var use_collision_mask = override_collision_mask if override_collision_mask != -1 else target_mask
	
	
	# Set up projectile with all parameters AFTER positioning
	projectile.setup(attack, direction, speed, proj_range, arc_height, 
					penetration, area_effect, area_radius,
					lingering, lingering_type, lingering_radius,
					lingering_duration, lingering_damage, projectile_type_to_use_final,
					use_collision_layer, use_collision_mask)
	
	# Set lingering effect scene if needed
	if lingering and projectile.create_lingering_effect and projectile_type_to_use_final and projectile_type_to_use_final.lingering_effect_scene:
		projectile.lingering_effect_scene = projectile_type_to_use_final.lingering_effect_scene

# Get remaining cooldown time for a projectile type
func get_cooldown_remaining(projectile_type: ProjectileType) -> float:
	if not projectile_type or projectile_type.cooldown <= 0.0:
		return 0.0
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_fire_time = last_fire_times.get(projectile_type.name, 0.0)
	var time_passed = current_time - last_fire_time
	
	return max(0.0, projectile_type.cooldown - time_passed)

# Get remaining cooldown time for current projectile type
func get_current_cooldown_remaining() -> float:
	return get_cooldown_remaining(current_projectile_type)

# Change current projectile type by name
func set_projectile_type(projectile_name: String) -> void:
	var projectile_type = get_projectile_type_by_name(projectile_name)
	if projectile_type:
		current_projectile_type = projectile_type
	else:
		push_error("Projectile type '" + projectile_name + "' not found!")

# Change current projectile type by index
func set_projectile_type_by_index(index: int) -> void:
	if index >= 0 and index < projectile_types.size():
		current_projectile_type = projectile_types[index]
	else:
		push_error("Projectile index " + str(index) + " out of range!")

# Get projectile type by name
func get_projectile_type_by_name(projectile_name: String) -> ProjectileType:
	for projectile_type in projectile_types:
		if projectile_type.name == projectile_name:
			return projectile_type
	return null

# Get all available projectile type names
func get_available_projectile_names() -> Array[String]:
	var names: Array[String] = []
	for projectile_type in projectile_types:
		names.append(projectile_type.name)
	return names

# Get current projectile type name
func get_current_projectile_name() -> String:
	return current_projectile_type.name if current_projectile_type else ""

# Cycle to next projectile type
func cycle_projectile_type() -> void:
	if projectile_types.size() <= 1:
		return
	
	var current_index = projectile_types.find(current_projectile_type)
	var next_index = (current_index + 1) % projectile_types.size()
	current_projectile_type = projectile_types[next_index]

func set_as_player_projectiles() -> void:
	projectile_layer = 32  # Player projectile layer
	target_mask = 8        # Enemy layer

func set_as_enemy_projectiles() -> void:
	projectile_layer = 64  # Enemy projectile layer
	target_mask = 4        # Player layer
