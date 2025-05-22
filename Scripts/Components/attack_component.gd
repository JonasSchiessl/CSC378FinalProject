extends Node2D
class_name AttackComponent

@export var base_damage: float = 1.0
@export var knockback_force: float = 100.0

# Owner of this component (player or enemy)
@onready var entity = get_parent()

# Creates an attack instance with current properties
func create_attack() -> Attack:
	var attack = Attack.new(
		base_damage,
		Vector2.RIGHT * knockback_force,  # Adjust direction based on entity facing
		entity
	)
	return attack

# Example of performing an attack by finding hitboxes in an area
func perform_attack(attack_area: Area2D) -> void:
	var hitboxes = attack_area.get_overlapping_areas()
	var attack = create_attack()
	
	for hitbox in hitboxes:
		if hitbox is HitboxComponent:
			hitbox.damage(attack)
