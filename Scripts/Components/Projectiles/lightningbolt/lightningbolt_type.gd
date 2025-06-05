# lightning_projectile_type.gd - ProjectileType for Lightning
extends ProjectileType
class_name LightningProjectileType

# Lightning-specific properties
@export_category("Lightning Properties")
@export var max_chain_count: int = 3
@export var chain_range: float = 200.0
@export var beam_width: float = 8.0
@export var beam_duration: float = 0.3
@export var damage_falloff_per_chain: float = 0.8
@export var shock_application_chance: float = 0.4

# Override default effects to include shock
func _init():
	name = "Lightning Bolt"
	description = "Chains between enemies with electrical damage"
	
	# Set base properties
	base_speed = 0.0  
	base_damage = 8.0
	base_range = 200.0  
	base_knockback = 50.0
	cooldown = 1.5
	
	# Enable shock effect
	can_apply_shock = true
	stun_chance = shock_application_chance
	stun_duration = 0.8
	
	# Lightning color
	projectile_color = Color(0.8, 0.9, 1.0, 1.0)
	
	# Setup default shock effect
	_setup_default_effects()

func _setup_default_effects():
	default_effects.clear()
	add_default_effect("shock", shock_application_chance, 0.8)
