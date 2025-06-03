# status_effect_component.gd - FIXED VERSION
extends Node
class_name StatusEffectComponent

# Entity this component belongs to
@onready var entity = get_parent()

# Active effects tracking
var active_effects: Dictionary = {}

# Initialize visual effect node references (optional)
@onready var effect_particles = $EffectParticles if has_node("EffectParticles") else null
@onready var burning_particles = $BurningParticles if has_node("BurningParticles") else null
@onready var poison_particles = $PoisonParticles if has_node("PoisonParticles") else null
@onready var ice_particles = $IceParticles if has_node("IceParticles") else null

# Signal when effects are applied/removed
signal effect_applied(effect_name: String, strength: float, duration: float)
signal effect_removed(effect_name: String)

func _ready() -> void:
	# Connect to health component signal (optional)
	if entity.has_node("health_component"):
		var health_comp = entity.get_node("health_component")
		health_comp.health_depleted.connect(_on_health_depleted)

# FIXED: Handle movement speed modifications
func apply_speed_modifier(amount: float, duration: float) -> void:
	# Skip if entity doesn't have move_speed
	if not entity.get("move_speed"):
		return
		
	var effect_id = "speed_modifier"
	var original_speed = entity.move_speed
	
	# FIXED: Clear existing effect timer if any
	_clear_existing_effect(effect_id, original_speed)
	
	# Apply effect
	entity.move_speed *= amount
	
	# Create timer to restore speed
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(entity) and entity.get("move_speed"):
			entity.move_speed = original_speed
		_cleanup_effect(effect_id, timer)
	)
	timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": timer,
		"original_value": original_speed,
		"strength": amount,
		"duration": duration
	}
	
	# Visual effect
	_apply_visual_effect(effect_id, amount, duration)
	
	# Enable ice particles if available
	if ice_particles and amount < 1.0:
		ice_particles.emitting = true
		get_tree().create_timer(duration).timeout.connect(func(): 
			if is_instance_valid(ice_particles):
				ice_particles.emitting = false
		)
	
	# Emit signal
	effect_applied.emit(effect_id, amount, duration)

# FIXED: Handle burning damage over time with proper tick counting
func apply_burning(damage_per_second: float, duration: float) -> void:
	# Skip if entity doesn't have health_component
	if not entity.has_node("health_component"):
		return
		
	var health_component = entity.get_node("health_component")
	var effect_id = "burning"
	var tick_interval = 0.5  # Damage every 0.5 seconds
	var total_ticks = int(duration / tick_interval)
	var damage_per_tick = damage_per_second * tick_interval
	
	# FIXED: Clear existing effect timer if any
	_clear_existing_effect(effect_id)
	
	# Create a timer for burning damage
	var tick_count = 0
	var burn_timer = Timer.new()
	add_child(burn_timer)
	burn_timer.wait_time = tick_interval
	burn_timer.one_shot = false  # Allow repeating
	
	# Connect the timeout signal
	burn_timer.timeout.connect(func():
		# Apply damage
		var burn_attack = Attack.new(damage_per_tick, Vector2.ZERO, null)
		health_component.damage(burn_attack)
		
		tick_count += 1
		
		# Check if effect should end AFTER incrementing
		if tick_count >= total_ticks or not is_instance_valid(entity) or not is_instance_valid(health_component):
			_cleanup_effect(effect_id, burn_timer)
			if burning_particles and is_instance_valid(burning_particles):
				burning_particles.emitting = false
			return
	)
	
	# Start the timer
	burn_timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": burn_timer,
		"ticks_remaining": total_ticks,
		"damage_per_tick": damage_per_tick,
		"duration": duration,
		"tick_count": 0,
		"total_ticks": total_ticks
	}
	
	# Visual effect
	_apply_visual_effect(effect_id, damage_per_second, duration)
	
	# Enable burning particles if available
	if burning_particles:
		burning_particles.emitting = true
		# Create a separate timer to stop particles after duration
		get_tree().create_timer(duration).timeout.connect(func(): 
			if is_instance_valid(burning_particles):
				burning_particles.emitting = false
		)
	
	# Emit signal
	effect_applied.emit(effect_id, damage_per_second, duration)

# FIXED: Handle poison damage over time with proper tick counting
func apply_poison(damage_per_second: float, duration: float) -> void:
	# Skip if entity doesn't have health_component
	if not entity.has_node("health_component"):
		return
		
	var health_component = entity.get_node("health_component")
	var effect_id = "poison"
	var tick_interval = 0.5  # Damage every 0.5 seconds
	var total_ticks = int(duration / tick_interval)
	var damage_per_tick = damage_per_second * tick_interval
	
	# FIXED: Clear existing effect timer if any
	_clear_existing_effect(effect_id)
	
	# Create a timer for poison damage
	var tick_count = 0
	var poison_timer = Timer.new()
	add_child(poison_timer)
	poison_timer.wait_time = tick_interval
	poison_timer.one_shot = false  # Allow repeating
	
	# Connect the timeout signal
	poison_timer.timeout.connect(func():
		# Apply damage
		var poison_attack = Attack.new(damage_per_tick, Vector2.ZERO, null)
		health_component.damage(poison_attack)
		
		tick_count += 1
		
		# Check if effect should end AFTER incrementing
		if tick_count >= total_ticks or not is_instance_valid(entity) or not is_instance_valid(health_component):
			_cleanup_effect(effect_id, poison_timer)
			if poison_particles and is_instance_valid(poison_particles):
				poison_particles.emitting = false
			return
	)
	
	# Start the timer
	poison_timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": poison_timer,
		"ticks_remaining": total_ticks,
		"damage_per_tick": damage_per_tick,
		"duration": duration,
		"tick_count": 0,
		"total_ticks": total_ticks
	}
	
	# Visual effect
	_apply_visual_effect(effect_id, damage_per_second, duration)
	
	# Enable poison particles if available
	if poison_particles:
		poison_particles.emitting = true
		# Create a separate timer to stop particles after duration
		get_tree().create_timer(duration).timeout.connect(func(): 
			if is_instance_valid(poison_particles):
				poison_particles.emitting = false
		)
	
	# Emit signal
	effect_applied.emit(effect_id, damage_per_second, duration)

# FIXED: Handle stun effect
func apply_stun(duration: float) -> void:
	var effect_id = "stun"
	
	# Early exit for enemies without appropriate methods
	if not entity.has_method("set_stun_state"):
		# Fallback: just slow down extremely if entity has move_speed
		if entity.get("move_speed"):
			apply_speed_modifier(0.1, duration)  # 90% slow
		return
	
	# Clear existing effect timer if any
	_clear_existing_effect(effect_id)
	
	# Apply stun effect to entity
	entity.set_stun_state(true)
	
	# Create timer to remove stun
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(entity) and entity.has_method("set_stun_state"):
			entity.set_stun_state(false)
		_cleanup_effect(effect_id, timer)
	)
	timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": timer,
		"duration": duration
	}
	
	# Visual effect
	_apply_visual_effect(effect_id, 1.0, duration)
	
	# Emit signal
	effect_applied.emit(effect_id, 1.0, duration)

# Helper function to clear existing effects
func _clear_existing_effect(effect_id: String, original_value: Variant = null, stat_name: String = "") -> void:
	if active_effects.has(effect_id):
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
			# Restore original value if provided
			if original_value != null and stat_name != "":
				if is_instance_valid(entity):
					entity.set(stat_name, original_value)
			elif active_effects[effect_id].has("original_value") and active_effects[effect_id].has("stat_name"):
				if is_instance_valid(entity):
					entity.set(active_effects[effect_id].stat_name, active_effects[effect_id].original_value)
			elif effect_id == "speed_modifier" and active_effects[effect_id].has("original_value"):
				if is_instance_valid(entity) and entity.get("move_speed"):
					entity.move_speed = active_effects[effect_id].original_value
			
			active_effects[effect_id].timer.stop()
			active_effects[effect_id].timer.queue_free()
		active_effects.erase(effect_id)

# Helper function to cleanup effect
func _cleanup_effect(effect_id: String, timer: Timer) -> void:
	active_effects.erase(effect_id)
	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	effect_removed.emit(effect_id)

# Helper function to apply visual effects
func _apply_visual_effect(effect_id: String, strength: float, duration: float) -> void:
	if entity.has_method("set_visual_effect"):
		entity.set_visual_effect(effect_id, duration)
	else:
		# Default visual - tint the entity
		if entity.has_method("set_effect_tint"):
			var tint_color: Color
			match effect_id:
				"speed_modifier":
					tint_color = Color(0.7, 0.7, 1.0) if strength < 1.0 else Color(1.0, 1.0, 0.7)
				"burning":
					tint_color = Color(1.0, 0.6, 0.3)  # Orange tint
				"poison":
					tint_color = Color(0.6, 1.0, 0.6)  # Green tint
				"stun":
					tint_color = Color(1.0, 1.0, 0.5)  # Yellow tint
				"armor_reduction":
					tint_color = Color(0.8, 0.8, 0.2)  # Yellow-brown tint
				_:
					tint_color = Color.WHITE
			
			entity.set_effect_tint(tint_color, duration)

# Check if an effect is currently active
func has_effect(effect_name: String) -> bool:
	return active_effects.has(effect_name)

# Get information about an active effect
func get_effect_data(effect_name: String) -> Dictionary:
	if active_effects.has(effect_name):
		return active_effects[effect_name]
	return {}

# Get remaining duration for an effect
func get_effect_remaining_duration(effect_name: String) -> float:
	if not active_effects.has(effect_name):
		return 0.0
	
	var effect_data = active_effects[effect_name]
	if effect_data.has("timer") and is_instance_valid(effect_data.timer):
		return effect_data.timer.time_left
	return 0.0

# FIXED: Clean up effects when entity dies
func _on_health_depleted() -> void:
	# Stop all effects
	for effect_id in active_effects.keys():
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
			active_effects[effect_id].timer.stop()
			active_effects[effect_id].timer.queue_free()
	
	# Clear effects dictionary
	active_effects.clear()
	
	# Stop all particle effects
	if burning_particles:
		burning_particles.emitting = false
	if poison_particles:
		poison_particles.emitting = false
	if ice_particles:
		ice_particles.emitting = false

# FIXED: Clear all effects (useful for phase changes)
func clear_all_effects() -> void:
	print("StatusEffectComponent: Clearing all active effects")
	_on_health_depleted()  # Reuse the cleanup logic
