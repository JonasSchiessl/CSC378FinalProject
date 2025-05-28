extends CharacterBody2D
class_name Tower

# Tower properties
@export var attack_range: float = 200.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 0.5

# Health properties
@export var max_health: float = 100.0
@export var current_health: float = 100.0

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var range_indicator: Node2D = $RangeIndicator
@onready var collision_shape: CollisionShape2D = $PhysicalCollision
@onready var health_bar: ProgressBar = $HealthBar
@onready var projectile_emitter = $projectile_emitter
@onready var attack_range_area = $AttackRange

# State management
var is_preview_mode: bool = false
var can_attack: bool = true
var current_target: Node2D = null
var is_destroyed: bool = false
var enemies_in_range: Array[Node2D] = []

# Visual feedback colors
var preview_valid_color: Color = Color(0, 1, 0, 0.5)
var preview_invalid_color: Color = Color(1, 0, 0, 0.5)
var normal_color: Color = Color.WHITE

# Signals
signal tower_destroyed()
signal health_changed(new_health: float, max_health: float)

func _ready() -> void:
	# Initialize the tower's starting state
	current_health = max_health
	
	# Connect to the game phase system if we're not in preview mode
	if not is_preview_mode and GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	
	# Set up enemy detection signals
	if attack_range_area:
		attack_range_area.body_entered.connect(_on_enemy_entered_range)
		attack_range_area.body_exited.connect(_on_enemy_left_range)
	else:
		push_error("Tower: No AttackRange Area2D found! Cannot detect enemies.")
	
	# Set up the attack range collision shape to match our attack_range property
	setup_attack_range()
	
	# Configure the projectile emitter for tower combat
	if projectile_emitter:
		projectile_emitter.set_as_player_projectiles()  # Use player layer so projectiles hit enemies
	else:
		push_error("Tower: No projectile_emitter found! Cannot attack enemies.")
	
	# Set initial enabled state based on current game phase
	if GameManager.instance:
		set_enabled(GameManager.instance.is_fight_phase())
	
	# Set up health bar display
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false  # Only show when damaged

func setup_attack_range() -> void:
	if not attack_range_area:
		return
		
	var collision_node = attack_range_area.get_node_or_null("AttackCollision")
	if collision_node and collision_node.shape is CircleShape2D:
		collision_node.shape.radius = attack_range
	else:
		push_warning("Tower: Could not find or configure AttackCollision shape")

func _physics_process(delta: float) -> void:
	# Only process combat during fight phase and when not in preview mode
	if is_preview_mode or not GameManager.instance or not GameManager.instance.is_fight_phase():
		return
	
	# Attack logic - find and attack the best target from our detected enemies
	if can_attack and not enemies_in_range.is_empty():
		attack_nearest_enemy()

func _on_enemy_entered_range(body: Node2D) -> void:
	"""Called when something enters our attack range"""
	if is_preview_mode:
		return
	
	print("Tower: Something entered attack range: ", body.name)
	
	# Check if this is a valid target
	if is_enemy(body):
		enemies_in_range.append(body)		
		# If this is our first target and we can attack, start attacking immediately
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
	
	# Check for enemy-specific components or methods
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
	
	# Find the closest valid enemy
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies_in_range:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	# Update our target and attack
	current_target = closest_enemy
	if current_target:
		attack_target(current_target)

# Execute an attack on the specified target
func attack_target(target: Node2D) -> void:
	if not can_attack or not target or not is_instance_valid(target):
		return
		
	# Safety check for projectile emitter
	if not projectile_emitter:
		push_error("Tower: Cannot attack - no projectile_emitter!")
		return
	
	# Calculate the direction to shoot
	var direction = (target.global_position - global_position).normalized()
	
	# Attempt to fire a projectile
	var projectile_fired = projectile_emitter.fire_projectile(direction)
	
	if projectile_fired:
		# Start our attack cooldown
		can_attack = false
		
		# Use a timer to reset our attack capability
		var cooldown_timer = get_tree().create_timer(attack_cooldown)
		cooldown_timer.timeout.connect(func(): can_attack = true)
	else:
		# The projectile emitter has its own cooldown, so we just wait and try again next frame
		pass

# Preview mode management - used by the tower placement system
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
		
		# Make the tower transparent
		modulate = preview_valid_color
		
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
		
		# Restore normal appearance
		modulate = normal_color

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

# Damage and destruction system
func take_damage(damage: float) -> void:
	if is_destroyed or is_preview_mode:
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Update health display
	if health_bar:
		health_bar.value = current_health
		health_bar.visible = true
	
	# Emit signal for other systems
	health_changed.emit(current_health, max_health)
	
	# Visual feedback
	flash_damage()
	
	# Check for destruction
	if current_health <= 0:
		destroy()

func flash_damage() -> void:
	var original_modulate = modulate
	modulate = Color(1.5, 0.5, 0.5)  # Flash red
	
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = original_modulate

func destroy() -> void:
	if is_destroyed:
		return
	
	is_destroyed = true
	can_attack = false
	
	tower_destroyed.emit()
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# Utility methods for tower management
func can_be_attacked() -> bool:
	return not is_preview_mode and not is_destroyed and current_health > 0

func heal(amount: float) -> void:
	if is_destroyed:
		return
	
	current_health = min(current_health + amount, max_health)
	
	if health_bar:
		health_bar.value = current_health
		if current_health >= max_health:
			health_bar.visible = false
	
	health_changed.emit(current_health, max_health)
