extends Node2D
class_name HealthComponent

# Initialize exports
@export var max_health := 10
 
# Initialize varaibles
var health : float

# Initialize signals
signal health_depleted
signal health_change(old_value, new_value)

func _ready() -> void:
	health = max_health

# Function takes in an attack and updates the health
func damage(attack: Attack) -> void:
	# Save current health value 
	var old_value = health
	# Update health value according to attack damage
	health -= attack.attack_damage
	# Emit the old value and damage value used elsewhere (Ui etc..)
	health_change.emit(old_value,health)
	
	# If health is below 0 emit signal to handle inside player/enemy/building scripts
	if health <= 0:
		health_depleted.emit()
