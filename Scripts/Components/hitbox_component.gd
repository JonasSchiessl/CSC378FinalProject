extends Area2D
class_name HitboxComponent

@export var attack_component: AttackComponent
var active: bool = false

func _ready() -> void:
	# Connect to the area_entered signal
	area_entered.connect(_on_area_entered)
	
	# Disable by default until an attack happens

# Called when this hitbox enters a hurtbox
func _on_area_entered(area: Area2D) -> void:
	print("HITBOX ENTERED AREA: ", area)
	if not active:
		return
	
	if area is HurtboxComponent:
		print("AREA IS HURTBOX")
		# Create an attack and apply it to the hurtbox
		var attack = attack_component.create_attack()
		area.damage(attack)
