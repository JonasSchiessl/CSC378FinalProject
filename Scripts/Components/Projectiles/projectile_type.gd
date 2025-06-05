extends Resource
class_name ProjectileType

# Basic identification
@export_category("Basic Configuration")
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

# ENHANCED: Status effects with configurable durations and strengths
@export_category("Status Effects")
@export var default_effects: Dictionary = {}

# Status effect configuration helpers
@export_subgroup("Burning Effect")
@export var can_apply_burning: bool = false
@export var burning_damage_per_second: float = 2.0
@export var burning_duration: float = 3.0

@export_subgroup("Poison Effect")
@export var can_apply_poison: bool = false
@export var poison_damage_per_second: float = 1.5
@export var poison_duration: float = 4.0

@export_subgroup("Freeze Effect")
@export var can_apply_freeze: bool = false
@export var slow_strength: float = 0.5  # 50% speed reduction
@export var slow_duration: float = 2.0

@export_subgroup("Shock Effect")
@export var can_apply_shock: bool = false
@export var stun_chance: float = 0.3  # 30% chance
@export var stun_duration: float = 0.8

# Cost/Requirements (optional, for gameplay balancing)
@export_category("Requirements")
@export var mana_cost: int = 0
@export var cooldown: float = 0.0
@export var required_level: int = 1

var _effects_initialized: bool = false

func get_default_effects() -> Dictionary:
	if not _effects_initialized:
		_setup_default_effects()
		_effects_initialized = true
	return default_effects
	
# Setup default effects based on export variables
func _setup_default_effects() -> void:
	default_effects.clear()
	
	if can_apply_burning:
		add_default_effect("burning", burning_damage_per_second, burning_duration)
	
	if can_apply_poison:
		add_default_effect("poison", poison_damage_per_second, poison_duration)
	
	if can_apply_freeze:
		add_default_effect("freeze", slow_strength, slow_duration)
	
	if can_apply_shock:
		add_default_effect("shock", stun_chance, stun_duration)

# Helper function to create a default effect with proper structure
func add_default_effect(effect_name: String, strength: float, duration: float) -> void:
	default_effects[effect_name] = {
		"strength": strength,
		"duration": duration,
		"enabled": true
	}

# Helper function to remove a default effect
func remove_default_effect(effect_name: String) -> void:
	if default_effects.has(effect_name):
		default_effects.erase(effect_name)

# Check if this projectile type has a specific effect
func has_effect(effect_name: String) -> bool:
	return default_effects.has(effect_name) and default_effects[effect_name].get("enabled", false)

# Get effect data for a specific effect
func get_effect_data(effect_name: String) -> Dictionary:
	if default_effects.has(effect_name):
		return default_effects[effect_name]
	return {}

# Get effect strength (damage per second, slow amount, etc.)
func get_effect_strength(effect_name: String) -> float:
	var effect_data = get_effect_data(effect_name)
	return effect_data.get("strength", 0.0)

# Get effect duration
func get_effect_duration(effect_name: String) -> float:
	var effect_data = get_effect_data(effect_name)
	return effect_data.get("duration", 0.0)

# Enable/disable a specific effect
func set_effect_enabled(effect_name: String, enabled: bool) -> void:
	if default_effects.has(effect_name):
		default_effects[effect_name]["enabled"] = enabled

# Modify effect parameters
func modify_effect(effect_name: String, new_strength: float, new_duration: float) -> void:
	if default_effects.has(effect_name):
		default_effects[effect_name]["strength"] = new_strength
		default_effects[effect_name]["duration"] = new_duration
	else:
		add_default_effect(effect_name, new_strength, new_duration)

# Get all active effects as a list
func get_active_effects() -> Array[String]:
	var active: Array[String] = []
	for effect_name in default_effects.keys():
		if default_effects[effect_name].get("enabled", false):
			active.append(effect_name)
	return active

# Debug function to print all effects
func debug_print_effects() -> void:
	print("=== PROJECTILE TYPE EFFECTS DEBUG ===")
	print("Projectile: ", name)
	for effect_name in default_effects.keys():
		var effect_data = default_effects[effect_name]
		print("  %s: Strength=%.2f, Duration=%.1fs, Enabled=%s" % [
			effect_name.capitalize(),
			effect_data.get("strength", 0.0),
			effect_data.get("duration", 0.0),
			effect_data.get("enabled", false)
		])
	print("=====================================")

# Validate effect configuration
func validate_effects() -> bool:
	var is_valid = true
	for effect_name in default_effects.keys():
		var effect_data = default_effects[effect_name]
		if not effect_data.has("strength") or not effect_data.has("duration"):
			push_error("Effect '%s' missing required properties" % effect_name)
			is_valid = false
		if effect_data.get("strength", 0.0) < 0:
			push_error("Effect '%s' has negative strength" % effect_name)
			is_valid = false
		if effect_data.get("duration", 0.0) <= 0:
			push_error("Effect '%s' has invalid duration" % effect_name)
			is_valid = false
	return is_valid
