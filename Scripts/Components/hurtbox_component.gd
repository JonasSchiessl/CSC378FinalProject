# hurtbox_component.gd
extends Area2D
class_name HurtboxComponent

@export var health_component: HealthComponent

# Get reference to status effect component if it exists
var status_effect_component: StatusEffectComponent = null

func _ready() -> void:
	# Try to find status effect component in parent
	if get_parent().has_node("status_effect_component"):
		status_effect_component = get_parent().get_node("status_effect_component")

func damage(attack: Attack) -> void:
	if health_component:
		# Apply base damage
		health_component.damage(attack)
		
		# Apply any status effects using the enhanced system
		if status_effect_component and attack.effects.size() > 0:
			for effect_name in attack.effects:
				var effect = attack.effects[effect_name]
				
				# Get strength and duration from the effect data
				var strength = effect.get("strength", 1.0)
				var duration = effect.get("duration", 1.0)
				
				# Apply the appropriate status effect with proper parameters
				match effect_name:
					"burn", "burning":
						status_effect_component.apply_burning(strength, duration)
					"poison":
						status_effect_component.apply_poison(strength, duration)
					"ice", "freeze":
						# Ice effect is typically a slow effect
						status_effect_component.apply_speed_modifier(strength, duration)
					"lightning", "shock":
						# Lightning could be a stun effect
						if randf() < strength:
							status_effect_component.apply_stun(duration)
					_:
						# Custom effect handling
						print("Unknown status effect: ", effect_name)

# Alternative damage function that takes individual effect parameters
func damage_with_effects(attack: Attack, additional_effects: Dictionary = {}) -> void:
	if health_component:
		# Apply base damage
		health_component.damage(attack)
		
		# Apply additional effects passed as parameters
		if status_effect_component and additional_effects.size() > 0:
			for effect_name in additional_effects:
				var effect_data = additional_effects[effect_name]
				var strength = effect_data.get("strength", 1.0)
				var duration = effect_data.get("duration", 1.0)
				
				apply_status_effect(effect_name, strength, duration)

# Helper function to apply status effects by name
func apply_status_effect(effect_name: String, strength: float, duration: float) -> void:
	if not status_effect_component:
		return
	
	match effect_name:
		"burn", "burning", "fire":
			status_effect_component.apply_burning(strength, duration)
		"poison", "toxic":
			status_effect_component.apply_poison(strength, duration)
		"ice", "freeze", "chill":
			# Ice effects typically slow the target
			status_effect_component.apply_speed_modifier(strength, duration)
		"lightning", "electric":
			# Lightning effects typically stun
			if randf() < strength:
				status_effect_component.apply_stun(duration)
		_:
			print("Warning: Unknown status effect '%s' - skipping" % effect_name)

# Apply effects from a ProjectileType's default effects
func apply_projectile_type_effects(projectile_type: ProjectileType) -> void:
	if not status_effect_component or not projectile_type:
		return
	
	for effect_name in projectile_type.get_active_effects():
		var strength = projectile_type.get_effect_strength(effect_name)
		var duration = projectile_type.get_effect_duration(effect_name)
		apply_status_effect(effect_name, strength, duration)

# Debug function to test status effects
func debug_apply_effect(effect_name: String, strength: float = 1.0, duration: float = 3.0) -> void:
	print("DEBUG: Applying %s (strength: %.2f, duration: %.1fs)" % [effect_name, strength, duration])
	apply_status_effect(effect_name, strength, duration)
