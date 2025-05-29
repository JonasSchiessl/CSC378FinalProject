extends CharacterBody2D
class_name Player

# Components
@onready var attack_component = $attack_component
@onready var hitbox_component = $hitbox_component
@onready var health_component = $health_component
@onready var hurtbox_component = $hurtbox_component
@onready var animated_sprite = $AnimatedSprite2D
@onready var state_machine = $StateMachine
@onready var projectile_emitter = $projectile_emitter
@onready var status_effect_component = $status_effect_component

# Movement Variables
@export var move_speed: float = 200.0 # Movement Speed
var facing_direction: Vector2 = Vector2.RIGHT # Direction sprite is facing
var aim_direction: Vector2 = Vector2.RIGHT  # Direction player is aiming (mouse)
var movement_vector: Vector2 = Vector2.ZERO  # Current input direction

# Projectile Variables
var current_projectile_index: int = 0

func _ready() -> void:
	# Create states
	var idle_state = PlayerIdleState.new(self)
	var move_state = PlayerMoveState.new(self)
	
	# Add states to state machine
	state_machine.add_state("idle", idle_state)
	state_machine.add_state("move", move_state)
	
	# Initialize state machine
	state_machine.initialize("idle")

func _input(event: InputEvent) -> void:
	# Handle movement input always
	handle_movement_input(event)
	
	# Only handle combat inputs during fight phase
	if GameManager.instance and GameManager.instance.is_fight_phase():
		# Handle mouse input for aiming
		if event is InputEventMouseMotion:
			update_aim_direction()
		
		# Handle projectile attacks
		if event.is_action_pressed("fire"):
			var success = projectile_emitter.fire_projectile(aim_direction)
			if not success:
				# Optional: Show feedback that weapon is on cooldown
				var remaining_cooldown = projectile_emitter.get_current_cooldown_remaining()
				print("Weapon on cooldown! %.1f seconds remaining" % remaining_cooldown)
		
		# Handle specific projectile selection (1-9 keys)
		for i in range(9):
			if event.is_action_pressed("projectile_" + str(i + 1)):
				select_projectile(i)
				break


	
func _physics_process(delta: float) -> void:
	# Update movement_vector based on current input state
	update_movement_vector()
	
	# Apply movement
	move_and_slide()

# Updates the aim direction based on mouse position
func update_aim_direction() -> void:
	# Get mouse position in world coordinates
	var mouse_pos = get_global_mouse_position()
	
	# Calculate direction from player to mouse
	aim_direction = (mouse_pos - global_position).normalized()

# Handle key press/release events
func handle_movement_input(event: InputEvent) -> void:
	if event.is_action_released("move_left") or event.is_action_released("move_right"):
		# Reset horizontal velocity
		velocity.x = 0
	
	if event.is_action_released("move_up") or event.is_action_released("move_down"):
		# Reset vertical velocity
		velocity.y = 0

# Get the current movement input direction (no parameters needed)
func get_movement_input() -> Vector2:
	return movement_vector

# Update the movement vector based on current key states
func update_movement_vector() -> void:
	movement_vector = Vector2.ZERO
	
	# Get WASD input direction based on current key states
	if Input.is_action_pressed("move_left"):
		movement_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		movement_vector.x += 1
	if Input.is_action_pressed("move_up"):
		movement_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		movement_vector.y += 1
	
	# Normalize for consistent speed in all directions
	if movement_vector.length() > 1.0:
		movement_vector = movement_vector.normalized()

# Update sprite facing based on movement direction
func update_sprite_facing(move_input: Vector2) -> void:
	if move_input.x != 0:
		# Update facing direction
		facing_direction.x = move_input.x
		
		# Update sprite orientation
		if facing_direction.x > 0:
			# Moving right, so flip the sprite
			animated_sprite.flip_h = false
		else:
			# Moving left, no need to flip
			animated_sprite.flip_h = true

# Returns the direction player is aiming (for attacks)
func get_aim_direction() -> Vector2:
	return aim_direction

# Returns the direction player is moving (for movement abilities)
func get_facing_direction() -> Vector2:
	return facing_direction

# Helper method for status effect visuals
func set_effect_tint(color: Color, duration: float) -> void:
	modulate = color
	get_tree().create_timer(duration).timeout.connect(func(): 
		modulate = Color.WHITE
	)

# This is called by the StatusEffectComponent for stun effects
func set_stun_state(is_stunned: bool) -> void:
	set_process_input(!is_stunned)
	# You could also pause state machine or add other stun behavior here

# Switch to next available projectile
func switch_projectile() -> void:
	if projectile_emitter.projectile_types.size() <= 1:
		return  # No switching needed if only one or no projectiles
	
	current_projectile_index = (current_projectile_index + 1) % projectile_emitter.projectile_types.size()
	projectile_emitter.set_projectile_type_by_index(current_projectile_index)
	
	# Optional: Show UI feedback
	var projectile_name = projectile_emitter.get_current_projectile_name()
	print("Switched to: " + projectile_name)

# Select specific projectile by index
func select_projectile(index: int) -> void:
	if index < 0 or index >= projectile_emitter.projectile_types.size():
		return  # Invalid index
	
	current_projectile_index = index
	projectile_emitter.set_projectile_type_by_index(index)
	
	# Optional: Show UI feedback
	var projectile_name = projectile_emitter.get_current_projectile_name()
	print("Selected: " + projectile_name)

# Fire specific projectile by name
func fire_projectile_by_name(projectile_name: String) -> void:
	projectile_emitter.fire_projectile_by_name(projectile_name, aim_direction)
