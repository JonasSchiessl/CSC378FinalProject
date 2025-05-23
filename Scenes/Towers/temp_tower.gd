extends CharacterBody2D  
class_name TempTower

# Tower properties
@export var attack_range: float = 200.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0

# Health properties
@export var max_health: float = 100.0
@export var current_health: float = 100.0

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var range_indicator: Node2D = $RangeIndicator  # Optional visual for range
@onready var collision_shape: CollisionShape2D = $PhysicalCollision
@onready var health_bar: ProgressBar = $HealthBar  # Optional health display

# State
var is_preview_mode: bool = false
var can_attack: bool = true
var current_target: Node2D = null
var is_destroyed: bool = false

# Colors for preview state
var preview_valid_color: Color = Color(0, 1, 0, 0.5)
var preview_invalid_color: Color = Color(1, 0, 0, 0.5)
var normal_color: Color = Color.WHITE

# Signals
signal tower_destroyed()
signal health_changed(new_health: float, max_health: float)

func _ready() -> void:
	# Initialize health
	current_health = max_health
	
	# Connect to phase changes if not in preview mode
	if not is_preview_mode and GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	
	# Set initial state based on current phase
	if GameManager.instance:
		set_enabled(GameManager.instance.is_fight_phase())
	
	# Update health bar if it exists
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _physics_process(delta: float) -> void:
	# Only process combat during fight phase and when not in preview
	if is_preview_mode or not GameManager.instance or not GameManager.instance.is_fight_phase():
		return
	
	# Look for targets and attack
	if can_attack:
		find_and_attack_target()

# Set the tower to preview mode (transparent, no functionality)
func set_preview_mode(preview: bool) -> void:
	is_preview_mode = preview
	
	if is_preview_mode:
		# Disable collision and combat functionality
		set_physics_process(false)
		if has_node("Area2D"):
			$Area2D.monitoring = false
		
		# IMPORTANT: Disable physical collision during preview
		if collision_shape:
			collision_shape.disabled = true
		
		# Make transparent
		modulate = preview_valid_color
		
		# Hide health bar during preview
		if health_bar:
			health_bar.visible = false
	else:
		# Enable functionality
		set_physics_process(true)
		if has_node("Area2D"):
			$Area2D.monitoring = true
		
		# Enable physical collision for placed tower
		if collision_shape:
			collision_shape.disabled = false
		
		# Restore normal appearance
		modulate = normal_color
		
		# Show health bar
		if health_bar:
			health_bar.visible = true

# Update preview appearance based on placement validity
func set_preview_state(is_valid: bool) -> void:
	if not is_preview_mode:
		return
	
	modulate = preview_valid_color if is_valid else preview_invalid_color

# Initialize the tower after placement
func initialize() -> void:
	is_preview_mode = false
	modulate = normal_color
	
	# Enable all functionality
	set_physics_process(true)
	
	# Show range indicator briefly (optional)
	if range_indicator:
		show_range_indicator()

# Show range indicator temporarily
func show_range_indicator() -> void:
	if not range_indicator:
		return
	
	range_indicator.visible = true
	
	# Hide after 2 seconds
	await get_tree().create_timer(2.0).timeout
	range_indicator.visible = false

# Find and attack nearest enemy
func find_and_attack_target() -> void:
	# Get all enemies in range (you'll need to implement enemy detection)
	var enemies_in_range = get_enemies_in_range()
	
	if enemies_in_range.is_empty():
		current_target = null
		return
	
	# Find closest enemy
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies_in_range:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	current_target = closest_enemy
	
	# Attack the target
	if current_target:
		attack_target(current_target)

# Get all enemies within attack range
func get_enemies_in_range() -> Array:
	var enemies = []
	
	# Method 1: Using Area2D (recommended)
	if has_node("Area2D"):
		var area = $Area2D
		for body in area.get_overlapping_bodies():
			# Check if it's an enemy (you'll need to define how to identify enemies)
			if body.has_method("is_enemy") and body.is_enemy():
				enemies.append(body)
	
	# Method 2: Manual distance check (fallback)
	# You'd need to get all enemies in the scene and check distances
	
	return enemies

# Attack the current target
func attack_target(target: Node2D) -> void:
	if not can_attack:
		return
	
	# Disable attacking during cooldown
	can_attack = false
	
	# Create projectile or instant damage (implement based on your preference)
	# For now, let's do instant damage
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	
	# Visual feedback - rotate toward target
	look_at(target.global_position)
	
	# You could also spawn a projectile here similar to your player's fireball
	# fire_projectile_at(target)
	
	# Start cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# Enable or disable the tower based on game phase
func set_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	
	# You might want to show/hide certain visual elements
	# or play animations based on the phase

# Handle phase changes
func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	match new_phase:
		GameManager.Phase.BUILD:
			set_enabled(false)
			# Maybe show construction animation or dim the tower
		GameManager.Phase.FIGHT:
			set_enabled(true)
			# Activate combat systems

# Take damage from attacks
func take_damage(damage: float) -> void:
	if is_destroyed or is_preview_mode:
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Update health bar
	if health_bar:
		health_bar.value = current_health
	
	# Emit signal for other systems to react
	health_changed.emit(current_health, max_health)
	
	# Visual feedback for taking damage
	flash_damage()
	
	# Check if tower is destroyed
	if current_health <= 0:
		destroy()

# Visual feedback when taking damage
func flash_damage() -> void:
	var original_modulate = modulate
	modulate = Color(1.5, 0.5, 0.5)  # Flash red
	
	await get_tree().create_timer(0.1).timeout
	modulate = original_modulate

# Destroy the tower
func destroy() -> void:
	if is_destroyed:
		return
	
	is_destroyed = true
	can_attack = false
	
	# Emit destruction signal
	tower_destroyed.emit()
	
	# Play destruction effects (you can add particles, sounds, etc.)
	# For now, let's do a simple fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	
	# Disable collision immediately
	if collision_shape:
		collision_shape.disabled = true

# Check if this tower can be attacked (useful for enemy AI)
func can_be_attacked() -> bool:
	return not is_preview_mode and not is_destroyed and current_health > 0

# Optional: Method to upgrade the tower
func upgrade() -> void:
	attack_damage *= 1.5
	attack_range *= 1.2
	attack_cooldown *= 0.8
	max_health *= 1.2
	
	# Heal to new max health when upgraded
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	# Update visuals to show upgrade
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter
