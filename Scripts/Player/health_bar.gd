extends TextureProgressBar
class_name HealthBar

# Optional: Add some visual effects
@export var flash_color: Color = Color.RED
@export var flash_duration: float = 0.2

func _ready() -> void:
	# Set initial values if needed
	min_value = 0.0
	# max_value and value should be set by the entity using this health bar

# Update the health bar when health changes
func update_health(current_health: float, max_health: float) -> void:
	max_value = max_health
	value = current_health
	
	# Optional: Flash effect when taking damage
	if current_health < value:
		flash_damage()
	
	# Show/hide based on health percentage
	if current_health >= max_health:
		visible = false  # Hide when at full health
	else:
		visible = true   # Show when damaged

# Optional: Visual feedback for damage
func flash_damage() -> void:
	var original_modulate = modulate
	modulate = flash_color
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, flash_duration)

# Optional: Smooth health bar animation
func animate_to_health(current_health: float, max_health: float, duration: float = 0.3) -> void:
	max_value = max_health
	
	var tween = create_tween()
	tween.tween_property(self, "value", current_health, duration)
	
	# Show/hide logic
	if current_health >= max_health:
		tween.tween_callback(func(): visible = false)
	else:
		visible = true
