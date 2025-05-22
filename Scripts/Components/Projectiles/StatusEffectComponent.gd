# status_effect_component.gd
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

# Handle movement speed modifications
func apply_speed_modifier(amount: float, duration: float) -> void:
	# Skip if entity doesn't have move_speed
	if not entity.get("move_speed"):
		return
		
	var effect_id = "speed_modifier"
	var original_speed = entity.move_speed
	
	# Clear existing effect timer if any
	if active_effects.has(effect_id):
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
			active_effects[effect_id].timer.queue_free()
	
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
		active_effects.erase(effect_id)
		timer.queue_free()
		effect_removed.emit(effect_id)
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
	if entity.has_method("set_visual_effect"):
		if amount < 1.0:  # Slow
			entity.set_visual_effect("slow", duration)
		else:  # Speed up
			entity.set_visual_effect("speed_up", duration)
	else:
		# Default visual - tint the entity
		if entity.has_method("set_effect_tint"):
			entity.set_effect_tint(Color(0.7, 0.7, 1.0), duration)  # Blue tint for slow
	
	# Enable ice particles if available
	if ice_particles and amount < 1.0:
		ice_particles.emitting = true
		get_tree().create_timer(duration).timeout.connect(func(): 
			if is_instance_valid(ice_particles):
				ice_particles.emitting = false
		)
	
	# Emit signal
	effect_applied.emit(effect_id, amount, duration)

# Handle burning damage over time
func apply_burning(damage_per_second: float, duration: float) -> void:
	# Skip if entity doesn't have health_component
	if not entity.has_node("health_component"):
		return
		
	var health_component = entity.get_node("health_component")
	var effect_id = "burning"
	var total_ticks = int(duration / 0.5)  # Damage every 0.5 seconds
	var damage_per_tick = damage_per_second * 0.5
	
	# Clear existing effect timer if any
	if active_effects.has(effect_id):
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
			active_effects[effect_id].timer.queue_free()
	
	# Create a timer for burning damage
	var tick_count = 0
	var burn_timer = Timer.new()
	add_child(burn_timer)
	burn_timer.wait_time = 0.5
	burn_timer.timeout.connect(func():
		tick_count += 1
		if tick_count > total_ticks or not is_instance_valid(entity) or not is_instance_valid(health_component):
			if is_instance_valid(burn_timer):
				burn_timer.queue_free()
			active_effects.erase(effect_id)
			effect_removed.emit(effect_id)
			return
		
		# Apply damage directly to health component
		var burn_attack = Attack.new(damage_per_tick, Vector2.ZERO, null)
		health_component.damage(burn_attack)
	)
	burn_timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": burn_timer,
		"ticks_remaining": total_ticks,
		"damage_per_tick": damage_per_tick,
		"duration": duration
	}
	
	# Visual effect
	if entity.has_method("set_visual_effect"):
		entity.set_visual_effect("burning", duration)
	else:
		# Default visual - tint the entity
		if entity.has_method("set_effect_tint"):
			entity.set_effect_tint(Color(1.0, 0.6, 0.3), duration)  # Orange tint
	
	# Enable burning particles if available
	if burning_particles:
		burning_particles.emitting = true
		get_tree().create_timer(duration).timeout.connect(func(): 
			if is_instance_valid(burning_particles):
				burning_particles.emitting = false
		)
	
	# Emit signal
	effect_applied.emit(effect_id, damage_per_second, duration)

# Handle poison damage over time
func apply_poison(damage_per_second: float, duration: float) -> void:
	# Skip if entity doesn't have health_component
	if not entity.has_node("health_component"):
		return
		
	var health_component = entity.get_node("health_component")
	var effect_id = "poison"
	var total_ticks = int(duration / 0.5)
	var damage_per_tick = damage_per_second * 0.5
	
	# Clear existing effect timer if any
	if active_effects.has(effect_id):
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
			active_effects[effect_id].timer.queue_free()
	
	# Create a timer for poison damage
	var tick_count = 0
	var poison_timer = Timer.new()
	add_child(poison_timer)
	poison_timer.wait_time = 0.5
	poison_timer.timeout.connect(func():
		tick_count += 1
		if tick_count > total_ticks or not is_instance_valid(entity) or not is_instance_valid(health_component):
			if is_instance_valid(poison_timer):
				poison_timer.queue_free()
			active_effects.erase(effect_id)
			effect_removed.emit(effect_id)
			return
		
		# Apply damage
		var poison_attack = Attack.new(damage_per_tick, Vector2.ZERO, null)
		health_component.damage(poison_attack)
	)
	poison_timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": poison_timer,
		"ticks_remaining": total_ticks,
		"damage_per_tick": damage_per_tick,
		"duration": duration
	}
	
	# Visual effect
	if entity.has_method("set_visual_effect"):
		entity.set_visual_effect("poison", duration)
	else:
		# Default visual - tint the entity
		if entity.has_method("set_effect_tint"):
			entity.set_effect_tint(Color(0.6, 1.0, 0.6), duration)  # Green tint
	
	# Enable poison particles if available
	if poison_particles:
		poison_particles.emitting = true
		get_tree().create_timer(duration).timeout.connect(func(): 
			if is_instance_valid(poison_particles):
				poison_particles.emitting = false
		)
	
	# Emit signal
	effect_applied.emit(effect_id, damage_per_second, duration)

# Handle stun effect
func apply_stun(duration: float) -> void:
	var effect_id = "stun"
	
	# Early exit for enemies without appropriate methods
	if not entity.has_method("set_stun_state"):
		# Fallback: just slow down extremely if entity has move_speed
		if entity.get("move_speed"):
			apply_speed_modifier(0.1, duration)  # 90% slow
		return
	
	# Clear existing effect timer if any
	if active_effects.has(effect_id):
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
			active_effects[effect_id].timer.queue_free()
	
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
		active_effects.erase(effect_id)
		timer.queue_free()
		effect_removed.emit(effect_id)
	)
	timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": timer,
		"duration": duration
	}
	
	# Visual effect
	if entity.has_method("set_visual_effect"):
		entity.set_visual_effect("stun", duration)
	else:
		# Default visual - tint the entity
		if entity.has_method("set_effect_tint"):
			entity.set_effect_tint(Color(1.0, 1.0, 0.5), duration)  # Yellow tint
	
	# Emit signal
	effect_applied.emit(effect_id, 1.0, duration)

# Handle armor reduction
func apply_armor_reduction(amount: float, duration: float) -> void:
	# Skip if entity doesn't have armor/defense stat
	if not entity.get("defense") and not entity.get("armor"):
		return
		
	var effect_id = "armor_reduction"
	var stat_name = "defense" if entity.get("defense") != null else "armor"
	var original_value = entity.get(stat_name)
	
	# Clear existing effect timer if any
	if active_effects.has(effect_id):
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
			active_effects[effect_id].timer.queue_free()
	
	# Apply effect - reduce armor by percentage
	entity.set(stat_name, original_value * (1.0 - amount))
	
	# Create timer to restore armor
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(entity):
			entity.set(stat_name, original_value)
		active_effects.erase(effect_id)
		timer.queue_free()
		effect_removed.emit(effect_id)
	)
	timer.start()
	
	# Store effect data
	active_effects[effect_id] = {
		"timer": timer,
		"original_value": original_value,
		"stat_name": stat_name,
		"strength": amount,
		"duration": duration
	}
	
	# Visual effect
	if entity.has_method("set_visual_effect"):
		entity.set_visual_effect("armor_break", duration)
	else:
		# Default visual - tint the entity
		if entity.has_method("set_effect_tint"):
			entity.set_effect_tint(Color(0.8, 0.8, 0.2), duration)  # Yellow-brown tint
	
	# Emit signal
	effect_applied.emit(effect_id, amount, duration)

# Check if an effect is currently active
func has_effect(effect_name: String) -> bool:
	return active_effects.has(effect_name)

# Get information about an active effect
func get_effect_data(effect_name: String) -> Dictionary:
	if active_effects.has(effect_name):
		return active_effects[effect_name]
	return {}

# Clean up effects when entity dies
func _on_health_depleted() -> void:
	# Stop all effects
	for effect_id in active_effects.keys():
		if active_effects[effect_id].has("timer") and is_instance_valid(active_effects[effect_id].timer):
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
