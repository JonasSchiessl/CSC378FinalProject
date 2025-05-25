extends Resource
class_name ProjectileType

# Basic identification
@export var name: String = "Basic Projectile"
@export var description: String = ""
@export var icon: Texture2D

# Visual configuration
@export_category("Visual Configuration")
@export var sprite_frames: SpriteFrames
@export var projectile_color: Color = Color.WHITE
@export var particle_material: ParticleProcessMaterial
@export var particle_texture: Texture2D

# Audio configuration
@export_category("Audio Configuration")
@export var launch_sound: AudioStream
@export var impact_sound: AudioStream
@export var loop_sound: AudioStream

# Base properties
@export_category("Base Properties")
@export var base_speed: float = 300.0
@export var base_damage: float = 5.0
@export var base_range: float = 1000.0
@export var base_knockback: float = 100.0

# Special properties
@export_category("Special Properties")
@export var can_arc: bool = false
@export var default_arc_height: float = 0.0
@export var can_penetrate: bool = false
@export var default_penetration: int = 0
@export var can_area_effect: bool = false
@export var default_area_radius: float = 100.0

# Lingering effect properties
@export_category("Lingering Effects")
@export var can_create_lingering: bool = false
@export var lingering_effect_scene: PackedScene
@export var default_lingering_type: String = "fire"
@export var default_lingering_radius: float = 100.0
@export var default_lingering_duration: float = 5.0
@export var default_lingering_damage: float = 1.0

# Status effects that this projectile applies by default
@export_category("Status Effects")
@export var default_effects: Dictionary = {}

# Cost/Requirements (optional, for gameplay balancing)
@export_category("Requirements")
@export var mana_cost: int = 0
@export var cooldown: float = 0.0
@export var required_level: int = 1

# Helper function to create a default effect
func add_default_effect(effect_name: String, strength: float, duration: float) -> void:
	default_effects[effect_name] = {
		"strength": strength,
		"duration": duration
	}

# Helper function to remove a default effect
func remove_default_effect(effect_name: String) -> void:
	if default_effects.has(effect_name):
		default_effects.erase(effect_name)

# Check if this projectile type has a specific effect
func has_effect(effect_name: String) -> bool:
	return default_effects.has(effect_name)

# Get effect data for a specific effect
func get_effect_data(effect_name: String) -> Dictionary:
	if default_effects.has(effect_name):
		return default_effects[effect_name]
	return {}
