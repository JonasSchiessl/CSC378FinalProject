extends CharacterBody2D

@export var speed = 80
@export var attack_damage = 15.0
@export var attack_range = 40.0
@export var knockback_force = 150.0

@onready var parent = get_parent()
@onready var player
# Add these component references
@onready var attack_component = $attack_component
@onready var hitbox_component = $hitbox_component
@onready var health_component = $health_component

# Miguel-added vars for currency stuff
@export var enemy_type: String = "melee_rat"  
@export var currency_reward: int = 15  
@export var bonus_multiplier: float = 1.0 
var reward_granted: bool = false
var death_position: Vector2  

# Attack state tracking
var attack_cooldown: float = 0.0
var attack_cooldown_time: float = 1.5  

func _ready() -> void:
	# Initialize player var based on its place in the scene tree
	if get_parent().get_node_or_null("Player"):
		player = get_parent().get_node("Player")
	elif get_parent().get_parent().get_node_or_null("Player"):
		player = get_parent().get_parent().get_node_or_null("Player")
	
	# Configure attack component for melee damage
	if attack_component:
		attack_component.base_damage = attack_damage
		attack_component.knockback_force = knockback_force
	
	# Activate hitbox for melee combat
	if hitbox_component:
		hitbox_component.active = false  
		# Set collision layers - enemy hitbox should target player hurtbox
		hitbox_component.collision_layer = 4
		hitbox_component.collision_mask = 3

	if CurrencyManager:
		var actual_reward = int(currency_reward * bonus_multiplier)
		CurrencyManager.set_enemy_reward(enemy_type, actual_reward)
	add_to_group("enemies")
	
	# Optional metadata for other systems
	set_meta("enemy_type", enemy_type)
	set_meta("currency_reward", currency_reward)

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	var direction = (player.global_position - global_position).normalized()
	var distance = global_position.distance_to(player.global_position)
	
	# Melee attack range - use existing idle animation for now
	if distance < attack_range and attack_cooldown <= 0:
		perform_attack(direction)
		return
	elif distance < attack_range and attack_cooldown > 0:
		# Stay in place while on cooldown, face the player
		if direction.x < 0:
			$Sprite.flip_h = false
		elif direction.x > 0:
			$Sprite.flip_h = true
		$AnimationPlayer.play("idle")
		
		# Keep hitbox disabled during cooldown
		if hitbox_component:
			hitbox_component.active = false
		return
	else:
		# Disable hitbox when not in attack range
		if hitbox_component:
			hitbox_component.active = false
	
	# Run to the player
	if direction.x < 0: # Run left animation
		$Sprite.flip_h = false
		$AnimationPlayer.play("run")
	elif direction.x > 0: # Run right animation
		$Sprite.flip_h = true
		$AnimationPlayer.play("run")
	velocity = direction * speed
	move_and_slide()

func perform_attack(direction: Vector2) -> void:
	"""Perform immediate melee attack"""
	attack_cooldown = attack_cooldown_time
	
	# Face the player
	if direction.x < 0:
		$Sprite.flip_h = false
	elif direction.x > 0:
		$Sprite.flip_h = true
	
	# Play idle animation for now (until you create attack animation)
	$AnimationPlayer.play("attack")
	
	if hitbox_component:
		hitbox_component.active = true
		hitbox_component.monitoring = true
		
		# Force check for overlapping areas right now
		var overlapping_areas = hitbox_component.get_overlapping_areas()
		
		for area in overlapping_areas:
			if area is HurtboxComponent:
				if attack_component:
					var attack = attack_component.create_attack()
					area.damage(attack)
				else:
					print("ERROR: No attack_component to create attack!")
			else:
				print("Area is not HurtboxComponent, it's: ", area.get_class())
		
		# Disable hitbox after attack duration
		get_tree().create_timer(0.3).timeout.connect(func():
			if hitbox_component and is_instance_valid(hitbox_component):
				hitbox_component.active = false
		)

# Handle health change logic
func _on_health_component_health_change(old_value: Variant, new_value: Variant) -> void:
	# Flashing logic and damage number 
	if new_value < old_value:
		pass

# Handle death logic
func _on_health_component_health_depleted() -> void:	
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
	show_reward_feedback(actual_reward)

func show_reward_feedback(reward_amount: int) -> void:
	"""Show visual feedback for the currency reward"""
	# Create a simple text effect to show the reward
	var reward_label = Label.new()
	reward_label.text = "+" + str(reward_amount)
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.modulate = Color.YELLOW
	
	get_tree().current_scene.add_child(reward_label)
	reward_label.global_position = death_position
	# Create a tween for the fade out effect
	var tween = get_tree().create_tween()
	tween.tween_property(reward_label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_EXPO)
	
	var tween2 = get_tree().create_tween()
	tween2.tween_property(reward_label, "position:y", reward_label.global_position.y-5.0, 1.0)
	
	# Remove the label when the fade animation completes
	tween.tween_callback(func(): 
		if is_instance_valid(reward_label):
			reward_label.queue_free()
	)
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

# Manual reward granting for testing
func grant_test_reward() -> void:
	"""Manually grant a currency reward for testing purposes"""
	if not reward_granted:
		award_kill_reward()
