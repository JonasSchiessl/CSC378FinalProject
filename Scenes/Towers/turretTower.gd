extends CharacterBody2D

# Tower properties
@export var attack_range: float = 200.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 0.5

@onready var health_component: HealthComponent = $health_component
@onready var hurtbox_component: HurtboxComponent = $hurtbox_component

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var range_indicator: Node2D = $RangeIndicator
@onready var collision_shape: CollisionShape2D = $PhysicalCollision
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var projectile_emitter = $projectile_emitter
@onready var attack_range_area = $AttackRange

# State management
var is_preview_mode: bool = false
var can_attack: bool = true
var current_target: Node2D = null
var is_destroyed: bool = false
var enemies_in_range: Array[Node2D] = []

# Animation control
var is_shooting: bool = false

# Visual feedback colors
var preview_valid_color: Color = Color(0, 1, 0, 0.5)
var preview_invalid_color: Color = Color(1, 0, 0, 0.5)
var normal_color: Color = Color.WHITE

# Signals
signal tower_destroyed()
signal health_change(new_health: float, max_health: float)

func _ready() -> void:
	# Connect to the game phase system if not in preview
	if not is_preview_mode and GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	
	# Set up enemy detection signals
	if attack_range_area:
		attack_range_area.body_entered.connect(_on_enemy_entered_range)
		attack_range_area.body_exited.connect(_on_enemy_left_range)
	else:
		push_error("Tower: No AttackRange Area2D found! Cannot detect enemies.")
	
	setup_attack_range()
	
	if projectile_emitter:
		projectile_emitter.set_as_player_projectiles()  
	else:
		push_error("Tower: No projectile_emitter found! Cannot attack enemies.")
	
	if GameManager.instance:
		set_enabled(GameManager.instance.is_fight_phase())
	
	# Initialize health bar with component vals
	if health_bar and health_component:
		health_bar.max_value = health_component.max_health
		health_bar.value = health_component.health
		health_bar.visible = false  # Only show when damaged

	if sprite and animation_player:
		animation_player.play("idle")
		sprite.flip_h = false
		
	add_to_group("towers")

# Connect to health component signals 
func connect_health_signals() -> void:
	if health_component:
		# Connect to health change events (should be basically same as player?)
		health_component.health_change.connect(_on_health_component_health_change)
		health_component.health_depleted.connect(_on_health_component_health_depleted)

func setup_attack_range() -> void:
	if not attack_range_area:
		return
		
	var collision_node = attack_range_area.get_node_or_null("AttackCollision")
	if collision_node and collision_node.shape is CircleShape2D:
		collision_node.shape.radius = attack_range
	else:
		push_warning("Tower: Could not find or configure AttackCollision shape")

func _physics_process(delta: float) -> void:
	# Only process combat during fight phase and when not in preview
	if is_preview_mode or not GameManager.instance or not GameManager.instance.is_fight_phase():
		return
	
	# Handle facing direction towards target
	if current_target and is_instance_valid(current_target):
		var direction_to_target = current_target.global_position.x - global_position.x
		if sprite:
			sprite.flip_h = direction_to_target < 0
	
	if can_attack and not enemies_in_range.is_empty():
		attack_nearest_enemy()

func _on_enemy_entered_range(body: Node2D) -> void:
	"""Called when something enters our attack range"""
	if is_preview_mode:
		return
	
	print("Tower: Something entered attack range: ", body.name)
	
	# Check if valid target
	if is_enemy(body):
		enemies_in_range.append(body)		
		if enemies_in_range.size() == 1 and can_attack:
			current_target = body
	else:
		pass

func _on_enemy_left_range(body: Node2D) -> void:
	"""Called when something leaves our attack range"""
	if is_preview_mode:
		return
		
	# Remove from our tracking list if it was there
	if body in enemies_in_range:
		enemies_in_range.erase(body)
		# If this was our current target, find a new one
		if current_target == body:
			current_target = null

# Determine if a node is an enemy we should attack
func is_enemy(node: Node) -> bool:
	"""Determine if a node is a valid target for this tower"""
	
	# Check if the node is in the enemies group (most reliable)
	if node.is_in_group("enemies"):
		return true
	
	# Check collision layer - enemies should be on layer 8
	if node.collision_layer & 8:  # Bitwise check for layer 8
		return true
	
	# REALLY hacky check, but sometimes worked?
	if node.has_method("_on_health_component_health_depleted"):
		return true
	
	return false

# Find and attack the closest enemy from our detected list
func attack_nearest_enemy() -> void:
	if enemies_in_range.is_empty():
		current_target = null
		return
	
	# Clean up any invalid enemies (destroyed, etc.)
	enemies_in_range = enemies_in_range.filter(func(enemy): return is_instance_valid(enemy) and not enemy.is_queued_for_deletion())
	
	if enemies_in_range.is_empty():
		current_target = null
		return
		
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies_in_range:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	current_target = closest_enemy
	if current_target:
		attack_target(current_target)

# Execute an attack on the specified target
func attack_target(target: Node2D) -> void:
	if not can_attack or not target or not is_instance_valid(target):
		return
		
	if not projectile_emitter:
		push_error("Tower: Cannot attack - no projectile_emitter!")
		return
	
	var direction = (target.global_position - global_position).normalized()
	
	if sprite:
		sprite.flip_h = direction.x < 0
	
	start_shooting_animation()
	
	var projectile_fired = projectile_emitter.fire_projectile(direction)
	
	if projectile_fired:
		# Start our attack cooldown
		can_attack = false
		# Use a timer to reset our attack capability
		var cooldown_timer = get_tree().create_timer(attack_cooldown)
		cooldown_timer.timeout.connect(func(): 
			can_attack = true
			stop_shooting_animation()
		)
	else:
		stop_shooting_animation()

func start_shooting_animation() -> void:
	if not sprite:
		return
		
	is_shooting = true
	animation_player.play("shooting")
	
	var shooting_duration = get_tree().create_timer(0.2)
	shooting_duration.timeout.connect(func():
		if not can_attack:
			stop_shooting_animation()
	)

func stop_shooting_animation() -> void:
	if not sprite:
		return
		
	is_shooting = false
	animation_player.play("idle")

# Preview mode management used by tower placement system
func set_preview_mode(preview: bool) -> void:
	is_preview_mode = preview
	
	if is_preview_mode:
		# Disable all functionality during preview
		set_physics_process(false)
		
		# Disable collision detection
		if attack_range_area:
			attack_range_area.monitoring = false
		if collision_shape:
			collision_shape.disabled = true
		
		# Disable hurtbox during preview mode
		if hurtbox_component:
			hurtbox_component.monitoring = false
		
		# Make the tower transparent
		modulate = preview_valid_color
		
		if sprite and animation_player:
			animation_player.play("idle")
			sprite.flip_h = false
		
		# Hide UI elements
		if health_bar:
			health_bar.visible = false
	else:
		# Enable full functionality for placed towers
		set_physics_process(true)
		
		# Enable collision detection
		if attack_range_area:
			attack_range_area.monitoring = true
		if collision_shape:
			collision_shape.disabled = false
		
		# Enable hurtbox for placed towers
		if hurtbox_component:
			hurtbox_component.monitoring = true
		
		# Restore normal appearance
		modulate = normal_color
		
		if sprite and animation_player:
			animation_player.play("idle")
		
		# Connect health signals now that the tower is placed
		connect_health_signals()

# Update preview appearance based on placement validity
func set_preview_state(is_valid: bool) -> void:
	if is_preview_mode:
		modulate = preview_valid_color if is_valid else preview_invalid_color

# Initialize the tower after it's been placed
func initialize() -> void:
	set_preview_mode(false)
	setup_attack_range()

# Enable or disable tower functionality based on game phase
func set_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	
	if attack_range_area:
		attack_range_area.monitoring = enabled
	
	# Also enable/disable hurtbox based on game phase
	if hurtbox_component:
		hurtbox_component.monitoring = enabled
	
	if enabled:
		can_attack = true
	else:
		can_attack = false
		current_target = null
		enemies_in_range.clear()

# Handle game phase changes
func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	match new_phase:
		GameManager.Phase.BUILD:
			set_enabled(false)
		GameManager.Phase.FIGHT:
			set_enabled(true)

func _on_health_component_health_change(old_value: Variant, new_value: Variant) -> void:
	print("Tower health changed from ", old_value, " to ", new_value)
	
	if health_bar and health_component:
		health_bar.value = new_value
		health_bar.visible = true  # Show health bar when damaged
		
		# Hide health bar if at full health
		if new_value >= health_component.max_health:
			health_bar.visible = false
	
	# Emit signal for other systems and stuff
	health_change.emit(new_value, health_component.max_health)
	
	# Make the tower look destroyed by changing the sprite frame
	if health_bar.value == 0:
		sprite.texture = load("res://Assets/Tower/turret-sprites-2.png")
	elif health_bar.value <= health_component.max_health/2:
		sprite.texture = load("res://Assets/Tower/turret-sprites-1.png")
	
	"""
	# Visual feedback for damage (if we want it)
	if new_value < old_value:
		flash_damage()
	"""
	
func _on_health_component_health_depleted() -> void:
	print("Tower destroyed!")
	
	# Hide health bar
	if health_bar:
		health_bar.visible = false
	
	# Handle tower destruction
	destroy()

# Kept the old take_damage method for backwards compatibility, but it routes through the health component now or whateva
func take_damage(damage: float) -> void:
	if is_destroyed or is_preview_mode:
		return
	
	if health_component:
		# Create a basic attack object and apply it through the health component
		# This maintains compatibility with any existing code that calls take_damage directly
		var attack = Attack.new()
		attack.damage = damage
		health_component.damage(attack)
	else:
		# Warn of no health component for debug
		push_warning("Tower: No health component found, using fallback damage system")

"""
func flash_damage() -> void:
	var original_modulate = modulate
	modulate = Color(1.5, 0.5, 0.5)  # Flash red
	
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = original_modulate
"""

func destroy() -> void:
	if is_destroyed:
		return
	
	is_destroyed = true
	can_attack = false
	
	if sprite and animation_player:
		animation_player.stop()
		sprite.flip_h = false
	
	tower_destroyed.emit()
	
	if collision_shape:
		collision_shape.disabled = true
	
	# Disable hurtbox when destroyed
	if hurtbox_component:
		hurtbox_component.monitoring = false
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# Utility method for tower management
func can_be_attacked() -> bool:
	return not is_preview_mode and not is_destroyed and health_component and health_component.health > 0

func heal(amount: float) -> void:
	if is_destroyed or not health_component:
		return
	
	# Use the health component's heal method if it exists, otherwise modify directly
	if health_component.has_method("heal"):
		health_component.heal(amount)
	else:
		health_component.health = min(health_component.health + amount, health_component.max_health)

# Future: Status effects if we want it
func set_effect_tint(color: Color, duration: float) -> void:
	modulate = color
	get_tree().create_timer(duration).timeout.connect(func(): 
		if is_instance_valid(self):
			modulate = Color.WHITE
	)

# Future: Stun effects if we want it 
func set_stun_state(is_stunned: bool) -> void:
	can_attack = !is_stunned
	# Could also disable other tower abilities here
