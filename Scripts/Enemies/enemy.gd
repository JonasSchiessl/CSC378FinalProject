extends CharacterBody2D

@export var speed = 1
@onready var projectile_emitter = $projectile_emitter
@onready var parent = get_parent()
@onready var player

# Miguel-added vars for currency stuff
@export var enemy_type: String = "poison_rat"  # Identifies this enemy type for rewards
@export var currency_reward: int = 10  # Override the default reward if needed
@export var bonus_multiplier: float = 1.0  # Allow for special bonuses (events, difficulty, etc.)
var reward_granted: bool = false
var death_position: Vector2  # Store where the enemy died for visual effects

func _ready() -> void:
	# Initialize player var based on its place in the scene tree
	if get_parent().get_node_or_null("Player"):
		player = get_parent().get_node("Player")
	elif get_parent().get_parent().get_node_or_null("Player"):
		player = get_parent().get_parent().get_node_or_null("Player")
	
	# Create projectile_timer, which fires projectiles at the player on timeout
	var projectile_timer : Timer = Timer.new()
	add_child(projectile_timer)
	projectile_timer.wait_time = 3
	projectile_timer.timeout.connect(func(): fire_projectile())
	projectile_timer.start()
	
	#Miguel-added currency code
	if CurrencyManager:
		var actual_reward = int(currency_reward * bonus_multiplier)
		CurrencyManager.set_enemy_reward(enemy_type, actual_reward)
	add_to_group("enemies")
	
	# Optional metadata for other systems
	set_meta("enemy_type", enemy_type)
	set_meta("currency_reward", currency_reward)


func _physics_process(delta: float) -> void:
	if global_position.distance_to(player.global_position) < 100:
		$AnimationPlayer.play("idle")
		return
	var direction = (player.global_position - global_position).normalized()
	if direction.x < 0: # Run left animation
		$Sprite.flip_h = false
		$AnimationPlayer.play("run")
	elif direction.x > 0: # Run right animation
		$Sprite.flip_h = true
		$AnimationPlayer.play("run")
	global_position += direction * speed
	move_and_slide()
	

func fire_projectile():
	var direction = (player.global_position - global_position).normalized()
	projectile_emitter.fire_projectile(direction)

# Handle health change logic
func _on_health_component_health_change(old_value: Variant, new_value: Variant) -> void:
	print("Enemy took damage! Health: ", old_value, " -> ", new_value)
	
	# Flashing logic and damage number 
	if new_value < old_value:
		pass
		
# Handle death logic
func _on_health_component_health_depleted() -> void:
	print("Enemy died!")
	
	if reward_granted:
		return
		
	death_position = global_position
	
	award_kill_reward()
	
	reward_granted = true
	
	# Stop movement and attacks
	set_physics_process(false)
	queue_free()


#Miguel added funcs for currency functionality
func award_kill_reward() -> void:
	"""Award currency for killing this enemy"""
	if not CurrencyManager:
		print("Warning: No CurrencyManager found, cannot award kill reward")
		return
	
	var actual_reward = int(currency_reward * bonus_multiplier)
	
	CurrencyManager.award_enemy_kill(enemy_type)
	
	print("Awarded ", actual_reward, " currency for killing ", enemy_type)
	
	show_reward_feedback(actual_reward)
	

func show_reward_feedback(reward_amount: int) -> void:
	"""Show visual feedback for the currency reward"""
	print("Creating reward feedback for amount: ", reward_amount)
	
	# Create a simple text effect to show the reward
	var reward_label = Label.new()
	reward_label.text = "+" + str(reward_amount)
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.modulate = Color.YELLOW
	
	get_tree().current_scene.add_child(reward_label)
	reward_label.global_position = death_position
	print("Added reward label at position: ", death_position)
	
	# Create a tween for the fade out effect
	var tween = get_tree().create_tween()
	tween.tween_property(reward_label, "modulate:a", 0.0, 3.0)
	
	# Remove the label when the fade animation completes
	tween.tween_callback(func(): 
		print("Fade animation complete - removing reward label")
		if is_instance_valid(reward_label):
			reward_label.queue_free()
	)
	
	print("Fade animation started - will fade out over 3 seconds")
	
# Configuration functions for easy balancing
func set_enemy_type(new_type: String) -> void:
	"""Set the enemy type for reward purposes"""
	enemy_type = new_type
	set_meta("enemy_type", enemy_type)
	
	if CurrencyManager:
		var actual_reward = int(currency_reward * bonus_multiplier)
		CurrencyManager.set_enemy_reward(enemy_type, actual_reward)

func set_currency_reward(new_reward: int) -> void:
	"""Set the base currency reward for this enemy"""
	currency_reward = new_reward
	set_meta("currency_reward", currency_reward)
	
	if CurrencyManager:
		var actual_reward = int(currency_reward * bonus_multiplier)
		CurrencyManager.set_enemy_reward(enemy_type, actual_reward)

func set_bonus_multiplier(multiplier: float) -> void:
	"""Set a bonus multiplier for this enemy (for events, difficulty scaling, etc.)"""
	bonus_multiplier = multiplier
	
	if CurrencyManager:
		var actual_reward = int(currency_reward * bonus_multiplier)
		CurrencyManager.set_enemy_reward(enemy_type, actual_reward)

# Debug functionality
func get_current_reward() -> int:
	"""Get the current currency reward this enemy would give"""
	return int(currency_reward * bonus_multiplier)

func get_enemy_type() -> String:
	"""Get the enemy type identifier"""
	return enemy_type

func debug_currency_reward() -> void:
	"""Debug function to test the currency reward system"""
	print("\n=== ENEMY CURRENCY DEBUG ===")
	print("Enemy Type: ", enemy_type)
	print("Base Reward: ", currency_reward)
	print("Bonus Multiplier: ", bonus_multiplier)
	print("Actual Reward: ", get_current_reward())
	print("Reward Granted: ", reward_granted)
	print("Global Currency: ", CurrencyManager.get_current_currency() if CurrencyManager else "N/A")
	print("============================\n")

# Manual reward granting for testing
func grant_test_reward() -> void:
	"""Manually grant a currency reward for testing purposes"""
	if not reward_granted:
		award_kill_reward()
		print("Test reward granted!")
	else:
		print("Reward already granted for this enemy")
