# projectile_emitter.gd
extends Node2D
class_name ProjectileEmitter

# Projectile properties
@export var projectile_scene: PackedScene
@export var base_speed: float = 300.0
@export var base_damage: float = 5.0
@export var base_range: float = 1000.0
@export var base_knockback: float = 100.0

# Special properties
@export var can_arc: bool = false
@export var default_arc_height: float = 0.0
@export var can_penetrate: bool = false
@export var default_penetration: int = 0
@export var can_area_effect: bool = false
@export var default_area_radius: float = 100.0

# Lingering effect properties
@export var can_create_lingering: bool = false
@export var lingering_effect_scene: PackedScene
@export var default_lingering_type: String = "fire"
@export var default_lingering_radius: float = 100.0
@export var default_lingering_duration: float = 5.0
@export var default_lingering_damage: float = 1.0

# Owner of this component (player/enemy)
@onready var entity = get_parent()

# Fire a projectile with default settings
func fire_projectile(direction: Vector2) -> void:
	fire_projectile_advanced(direction, base_speed, base_damage, base_range, 
							  base_knockback, default_arc_height, default_penetration,
							  false, default_area_radius,
							  false, default_lingering_type, default_lingering_radius,
							  default_lingering_duration, default_lingering_damage)


# Full control over projectile parameters
func fire_projectile_advanced(direction: Vector2, speed: float, damage: float, 
							 proj_range: float, knockback: float, arc_height: float = 0.0,
							 penetration: int = 0, area_effect: bool = false,
							 area_radius: float = 100.0, lingering: bool = false,
							 lingering_type: String = "fire", lingering_radius: float = 100.0,
							 lingering_duration: float = 5.0, lingering_damage: float = 1.0) -> void:
	# Create projectile instance
	var projectile = projectile_scene.instantiate()
	
	# Create attack
	var attack = Attack.new(
		damage,
		direction * knockback,
		entity
	)
	
	# Set up projectile with all parameters
	projectile.setup(attack, direction, speed, proj_range, arc_height, 
					 penetration, area_effect, area_radius,
					 lingering, lingering_type, lingering_radius,
					 lingering_duration, lingering_damage)
	
	# Set lingering effect scene if needed
	if lingering and projectile.create_lingering_effect:
		projectile.lingering_effect_scene = lingering_effect_scene
	
	# Add to scene
	get_tree().current_scene.add_child(projectile)
	
	# Set initial position at entity
	projectile.global_position = global_position
