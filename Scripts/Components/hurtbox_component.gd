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
		
		# Apply any status effects
		if status_effect_component and attack.effects.size() > 0:
			for effect_name in attack.effects:
				var effect = attack.effects[effect_name]
				
				match effect_name:
					"slow":
						status_effect_component.apply_speed_modifier(effect.strength, effect.duration)
					"burn":
						status_effect_component.apply_burning(effect.strength, effect.duration)
					"poison":
						status_effect_component.apply_poison(effect.strength, effect.duration)
					"stun":
						# Apply stun with chance based on strength
						if randf() < effect.strength:
							status_effect_component.apply_stun(effect.duration)
					"armor_reduction":
						status_effect_component.apply_armor_reduction(effect.strength, effect.duration)
