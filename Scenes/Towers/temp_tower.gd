extends CharacterBody2D
class_name Tower

# Tower properties - these control the tower's combat behavior
@export var attack_range: float = 200.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 0.5

# Health properties - towers can be destroyed by enemies
@export var max_health: float = 100.0
@export var current_health: float = 100.0

# Visual components - these handle the tower's appearance and UI
@onready var sprite: Sprite2D = $Sprite2D
@onready var range_indicator: Node2D = $RangeIndicator
@onready var collision_shape: CollisionShape2D = $PhysicalCollision
@onready var health_bar: ProgressBar = $HealthBar
@onready var projectile_emitter = $projectile_emitter
@onready var attack_range_area = $AttackRange

# State management - these track what the tower is currently doing
var is_preview_mode: bool = false
var can_attack: bool = true
var current_target: Node2D = null
var is_destroyed: bool = false
var enemies_in_range: Array[Node2D] = []  # Keep track of all enemies we can attack

# Visual feedback colors
var preview_valid_color: Color = Color(0, 1, 0, 0.5)
var preview_invalid_color: Color = Color(1, 0, 0, 0.5)
var normal_color: Color = Color.WHITE

# Signals for communication with other systems
signal tower_destroyed()
signal health_changed(new_health: float, max_health: float)

func _ready() -> void:
	# Initialize the tower's starting state
	current_health = max_health
	
	# Connect to the game phase system if we're not in preview mode
	if not is_preview_mode and GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	
	# Set up enemy detection signals - this is the key improvement!
	# Instead of constantly checking for enemies, we listen for when they enter/leave our range
	if attack_range_area:
		attack_range_area.body_entered.connect(_on_enemy_entered_range)
		attack_range_area.body_exited.connect(_on_enemy_left_range)
		print("Tower: Connected attack range signals")
	else:
		push_error("Tower: No AttackRange Area2D found! Cannot detect enemies.")
	
	# Set up the attack range collision shape to match our attack_range property
	setup_attack_range()
	
	# Configure the projectile emitter for tower combat
	if projectile_emitter:
		projectile_emitter.set_as_player_projectiles()  # Use player layer so projectiles hit enemies
		print("Tower: Projectile emitter configured")
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
	# Debug collision layers
	print("=== TOWER COLLISION DEBUG ===")
	print("Tower physical collision layer: ", collision_layer)
	print("Tower physical collision mask: ", collision_mask)
	if attack_range_area:
		print("Tower attack range collision layer: ", attack_range_area.collision_layer)
		print("Tower attack range collision mask: ", attack_range_area.collision_mask)
	print("==============================")

func setup_attack_range() -> void:
	"""Configure the attack range collision shape to match our attack_range property"""
	if not attack_range_area:
		return
		
	var collision_node = attack_range_area.get_node_or_null("AttackCollision")
	if collision_node and collision_node.shape is CircleShape2D:
		collision_node.shape.radius = attack_range
		print("Tower: Attack range set to ", attack_range)
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
	"""Enhanced version with detailed logging for debugging"""
	if is_preview_mode:
		print("Tower: Ignoring range entry - in preview mode")
		return
	
	print("Tower: Something entered attack range: ", body.name, " (", body.get_class(), ")")
	print("  - Global position: ", body.global_position)
	print("  - Collision layer: ", body.collision_layer if body.get("collision_layer") != null else "N/A")
	print("  - Is in enemies group: ", body.is_in_group("enemies"))
	
	# Check if this is a valid target using our enhanced detection
	if is_enemy(body):
		enemies_in_range.append(body)
		print("Tower: ✓ VALID TARGET added to list - Total targets: ", enemies_in_range.size())
		
		# If this is our first target and we can attack, start attacking immediately
		if enemies_in_range.size() == 1 and can_attack:
			current_target = body
			print("Tower: Set as current target: ", body.name)
	else:
		print("Tower: ✗ NOT a valid target, ignoring")

func _on_enemy_left_range(body: Node2D) -> void:
	"""Enhanced version with detailed logging for debugging"""
	if is_preview_mode:
		return
	
	print("Tower: Something left attack range: ", body.name)
	
	# Remove from our tracking list if it was there
	if body in enemies_in_range:
		enemies_in_range.erase(body)
		print("Tower: Removed from target list - Remaining targets: ", enemies_in_range.size())
		
		# If this was our current target, find a new one
		if current_target == body:
			current_target = null
			print("Tower: Cleared current target, will find new one")
	if is_preview_mode:
		return
		
	# Remove the enemy from our tracking list
	if body in enemies_in_range:
		enemies_in_range.erase(body)
		print("Tower: Enemy left range - ", body.name, " (Remaining enemies: ", enemies_in_range.size(), ")")
		
		# If this was our current target, find a new one
		if current_target == body:
			current_target = null

# Determine if a node is an enemy we should attack
func is_enemy(node: Node) -> bool:
	"""Determine if a node is a valid target for this tower"""
	
	# In test mode, also consider the player as a valid target
	if test_mode_enabled and can_target_player:
		if node is Player or node.name.to_lower().contains("player"):
			print("Tower: Detected player as valid target (TEST MODE)")
			return true
	
	# Normal enemy detection logic
	if node.is_in_group("enemies"):
		print("Tower: Detected enemy in group 'enemies': ", node.name)
		return true
	
	# Check collision layer - enemies should be on layer 8
	if node.collision_layer & 8:  # Bitwise check for layer 8
		print("Tower: Detected enemy on collision layer 8: ", node.name)
		return true
	
	# Check for enemy-specific components or methods
	if node.has_method("_on_health_component_health_depleted"):
		print("Tower: Detected enemy with health component: ", node.name)
		return true
	
	# If we get here, this is not a valid target
	print("Tower: Node ", node.name, " is NOT considered a valid target")
	print("  - Is in enemies group: ", node.is_in_group("enemies"))
	print("  - Collision layer: ", node.collision_layer if node.get("collision_layer") != null else "N/A")
	print("  - Has health method: ", node.has_method("_on_health_component_health_depleted"))
	
	return false
	# Method 1: Check if the node is in the enemies group (most reliable)
	if node.is_in_group("enemies"):
		return true
	
	# Method 2: Check collision layer - enemies should be on layer 8
	if node.collision_layer & 8:  # Bitwise check for layer 8
		return true
	
	# Method 3: Check for enemy-specific components or methods
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
		print("Tower: Fired projectile at ", target.name)
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
	print("Tower: Initializing at position ", global_position)
	set_preview_mode(false)
	setup_attack_range()

# Enable or disable tower functionality based on game phase
func set_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	
	if attack_range_area:
		attack_range_area.monitoring = enabled
	
	if enabled:
		can_attack = true
		print("Tower: Enabled for combat")
	else:
		can_attack = false
		current_target = null
		enemies_in_range.clear()
		print("Tower: Disabled for build phase")

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
	"""Provide visual feedback when the tower takes damage"""
	var original_modulate = modulate
	modulate = Color(1.5, 0.5, 0.5)  # Flash red
	
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = original_modulate

func destroy() -> void:
	"""Handle tower destruction"""
	if is_destroyed:
		return
	
	is_destroyed = true
	can_attack = false
	
	print("Tower: Destroyed!")
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
	
	# Test mode variables - add these to your Tower class variables section
var test_mode_enabled: bool = false
var can_target_player: bool = false

# Add this function to your Tower class to enable player testing
func enable_player_targeting_test() -> void:
	"""Enable test mode where towers can detect and shoot at the player"""
	test_mode_enabled = true
	can_target_player = true
	
	print("Tower: Player targeting test mode ENABLED")
	print("Tower: Will now treat player as a valid target")
	
	# Temporarily modify our collision mask to also detect player (layer 4)
	if attack_range_area:
		# Add player layer (4) to our detection mask while keeping enemy layer (8)
		attack_range_area.collision_mask = 8 | 4  # Binary OR to include both layers
		print("Tower: Attack range now detects layers: ", attack_range_area.collision_mask)

func disable_player_targeting_test() -> void:
	"""Disable test mode and return to normal enemy-only targeting"""
	test_mode_enabled = false
	can_target_player = false
	
	print("Tower: Player targeting test mode DISABLED")
	
	# Restore normal collision mask (enemies only)
	if attack_range_area:
		attack_range_area.collision_mask = 8  # Only enemy layer
		print("Tower: Attack range restored to enemy-only detection")

func _input(event: InputEvent) -> void:
	"""Handle test mode input - only for debugging"""
	if not OS.is_debug_build():
		return  # Only allow in debug builds
		
	# Toggle player targeting test with T key
	if event.is_action_pressed("ui_accept"):  # Space bar - you can change this
		if test_mode_enabled:
			disable_player_targeting_test()
		else:
			enable_player_targeting_test()
	
	# Force attack current target with F key (for testing)
	if event.is_action_pressed("ui_cancel") and current_target:  # Escape key
		print("Tower: FORCED ATTACK on ", current_target.name)
		attack_target(current_target)

# Add this function to manually trigger detection testing
func test_detection_range() -> void:
	"""Manually test what's currently in our detection range"""
	if not attack_range_area:
		print("Tower: No attack range area to test!")
		return
		
	print("\n=== TOWER DETECTION RANGE TEST ===")
	print("Tower position: ", global_position)
	print("Attack range monitoring: ", attack_range_area.monitoring)
	print("Attack range collision_mask: ", attack_range_area.collision_mask)
	
	var overlapping_bodies = attack_range_area.get_overlapping_bodies()
	print("Total overlapping bodies: ", overlapping_bodies.size())
	
	for i in range(overlapping_bodies.size()):
		var body = overlapping_bodies[i]
		print("  Body ", i, ": ", body.name, " (", body.get_class(), ")")
		print("    Position: ", body.global_position)
		print("    Distance: ", global_position.distance_to(body.global_position))
		print("    Collision layer: ", body.collision_layer if body.get("collision_layer") != null else "N/A")
		print("    Is valid target: ", is_enemy(body))
	
	print("Currently tracked enemies: ", enemies_in_range.size())
	for enemy in enemies_in_range:
		if is_instance_valid(enemy):
			print("  - ", enemy.name, " at ", enemy.global_position)
	
	print("Current target: ", current_target.name if current_target else "None")
	print("Can attack: ", can_attack)
	print("=== END TEST ===\n")
