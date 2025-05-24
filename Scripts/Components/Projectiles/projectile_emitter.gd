extends Node2D
class_name ProjectileEmitter

# Projectile type definitions
@export var projectile_types: Array[ProjectileType] = []
@export var default_projectile_index: int = 0
@export var universal_projectile_scene: PackedScene  # The universal projectile scene

# Owner of this component (player/enemy)
@onready var entity = get_parent()

# Current projectile type
var current_projectile_type: ProjectileType

func _ready() -> void:
	# Set default projectile type if available
	if projectile_types.size() > 0 and default_projectile_index < projectile_types.size():
		current_projectile_type = projectile_types[default_projectile_index]

# Fire a projectile with current type and default settings
func fire_projectile(direction: Vector2) -> void:
	if not current_projectile_type:
		push_error("No projectile type set!")
		return
	
	fire_projectile_advanced(direction, current_projectile_type.base_speed, 
							current_projectile_type.base_damage, current_projectile_type.base_range, 
							current_projectile_type.base_knockback, current_projectile_type.default_arc_height, 
							current_projectile_type.default_penetration, current_projectile_type.can_area_effect, 
							current_projectile_type.default_area_radius, current_projectile_type.can_create_lingering, 
							current_projectile_type.default_lingering_type, current_projectile_type.default_lingering_radius,
							current_projectile_type.default_lingering_duration, current_projectile_type.default_lingering_damage)

# Fire a projectile by type name
func fire_projectile_by_name(projectile_name: String, direction: Vector2) -> void:
	var projectile_type = get_projectile_type_by_name(projectile_name)
	if not projectile_type:
		push_error("Projectile type '" + projectile_name + "' not found!")
		return
	
	fire_projectile_with_type(projectile_type, direction)

# Fire a projectile by index
func fire_projectile_by_index(index: int, direction: Vector2) -> void:
	if index < 0 or index >= projectile_types.size():
		push_error("Projectile index " + str(index) + " out of range!")
		return
	
	fire_projectile_with_type(projectile_types[index], direction)

# Fire a projectile with a specific ProjectileType
func fire_projectile_with_type(projectile_type: ProjectileType, direction: Vector2) -> void:
	if not projectile_type:
		push_error("Invalid projectile type!")
		return
	
	fire_projectile_advanced(direction, projectile_type.base_speed, 
							projectile_type.base_damage, projectile_type.base_range, 
							projectile_type.base_knockback, projectile_type.default_arc_height, 
							projectile_type.default_penetration, projectile_type.can_area_effect, 
							projectile_type.default_area_radius, projectile_type.can_create_lingering, 
							projectile_type.default_lingering_type, projectile_type.default_lingering_radius,
							projectile_type.default_lingering_duration, projectile_type.default_lingering_damage,
							projectile_type)

# Full control over projectile parameters with optional projectile type override
func fire_projectile_advanced(direction: Vector2, speed: float, damage: float, 
							proj_range: float, knockback: float, arc_height: float = 0.0,
							penetration: int = 0, area_effect: bool = false,
							area_radius: float = 100.0, lingering: bool = false,
							lingering_type: String = "fire", lingering_radius: float = 100.0,
							lingering_duration: float = 5.0, lingering_damage: float = 1.0,
							projectile_type_override: ProjectileType = null) -> void:
	
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
	
	# Set up projectile with all parameters AFTER positioning
	projectile.setup(attack, direction, speed, proj_range, arc_height, 
					penetration, area_effect, area_radius,
					lingering, lingering_type, lingering_radius,
					lingering_duration, lingering_damage, projectile_type_to_use)
	
	# Set lingering effect scene if needed
	if lingering and projectile.create_lingering_effect and projectile_type_to_use and projectile_type_to_use.lingering_effect_scene:
		projectile.lingering_effect_scene = projectile_type_to_use.lingering_effect_scene

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
