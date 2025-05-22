# Attack.gd
extends RefCounted
class_name Attack

var attack_damage: float
var knockback_force: Vector2 = Vector2.ZERO
var attack_source: Node2D
var effects: Dictionary = {}  # Status effects applied by this attack

func _init(dmg: float = 1.0, kb: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	attack_damage = dmg
	knockback_force = kb
	attack_source = source

# Apply a status effect to this attack
func apply_effect(effect_name: String, effect_strength: float, effect_duration: float) -> void:
	effects[effect_name] = {
		"strength": effect_strength,
		"duration": effect_duration
	}

# Add damage multiplier for critical hits or other modifiers
func apply_damage_multiplier(multiplier: float) -> void:
	attack_damage *= multiplier

# Add additional knockback
func add_knockback(additional_force: Vector2) -> void:
	knockback_force += additional_force
