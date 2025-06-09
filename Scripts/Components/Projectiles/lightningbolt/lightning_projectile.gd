# lightning_projectile.gd - Enhanced with ProjectileType Sound Integration
extends Node2D
class_name LightningProjectile

# Lightning Stat properties
@export var max_chains: int = 3
@export var chain_range: float = 200.0
@export var beam_width: float = 8.0
@export var beam_duration: float = 0.3
@export var damage_falloff: float = 0.8  
@export var shock_chance: float = 0.4  

# Visual properties
@export var lightning_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var lightning_flicker_speed: float = 20.0
@export var branch_probability: float = 0.3  
@export var enable_glow: bool = false
@export var glow_width: float = 1.0 

# Runtime variables
var attack: Attack
var current_chains: int = 0
var hit_enemies: Array[Node2D] = []
var beam_segments: Array[LightningBeam] = []
var is_active: bool = true
var projectile_type: ProjectileType = null  # Store the projectile type

# Collision configuration
var collision_layer: int = 32 
var collision_mask: int = 8    

# Audio players - Create them dynamically based on ProjectileType
var launch_audio_player: AudioStreamPlayer2D = null
var impact_audio_player: AudioStreamPlayer2D = null
@onready var lightning_sound: AudioStreamPlayer2D = $LightningSound if has_node("LightningSound") else null
@onready var impact_particles: GPUParticles2D = $ImpactParticles if has_node("ImpactParticles") else null

# Lightning beam visual component with procedural crackling
class LightningBeam extends Line2D:
	var flicker_timer: float = 0.0
	var crackling_timer: float = 0.0
	var base_width: float
	var lifetime: float = 0.0
	var max_lifetime: float
	var branches: Array[Line2D] = []
	var base_points: PackedVector2Array 
	var crackling_speed: float = 30.0  
	var intensity_variation: float = 0.4  
	var enable_glow: bool =  false
	
	func _init(start_pos: Vector2, end_pos: Vector2, width: float, color: Color, duration: float, glow_width: float, enable_glow: bool):
		# Set basic Line2D properties first
		default_color = color
		self.width = width
		base_width = width
		max_lifetime = duration
		z_index = 100  
		
		# Lightning line style
		end_cap_mode = Line2D.LINE_CAP_ROUND
		joint_mode = Line2D.LINE_JOINT_ROUND
		antialiased = true
		
		# Make sure the line is visible
		visible = true
		
		# Store the basic path
		base_points = PackedVector2Array([start_pos, end_pos])
		points = base_points
		
		#print("Created crackling lightning from ", start_pos, " to ", end_pos)
		
		# Generate initial crackling pattern
		call_deferred("generate_crackling_path")
		
		if enable_glow:
			# Create glow effect
			call_deferred("create_glow_effect", start_pos, end_pos, width, color, glow_width)

	func generate_crackling_path():
		if base_points.size() < 2:
			return
			
		var start = base_points[0]
		var end = base_points[1]
		var direction = (end - start).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)
		var distance = start.distance_to(end)
		
		# Clear and rebuild with crackling effect
		clear_points()
		add_point(start)
		
		# Create multiple segments with random crackling
		var segments = max(4, int(distance / 20.0))
		var max_offset = distance * 0.08  # Maximum crackling offset
		
		for i in range(1, segments):
			var t = float(i) / float(segments)
			var base_point = start.lerp(end, t)
			
			# Add multiple layers of crackling noise
			var primary_offset = sin(t * PI * 3.0 + lifetime * crackling_speed) * max_offset
			var secondary_offset = sin(t * PI * 7.0 + lifetime * crackling_speed * 2.3) * max_offset * 0.3
			var tertiary_offset = sin(t * PI * 13.0 + lifetime * crackling_speed * 4.1) * max_offset * 0.1
			
			var total_offset = (primary_offset + secondary_offset + tertiary_offset) * intensity_variation
			var crackling_point = base_point + perpendicular * total_offset
			
			add_point(crackling_point)
		
		add_point(end)
		
		# Randomly create/update branches
		update_crackling_branches()

	func update_crackling_branches():
		# Clean up old branches
		for branch in branches:
			if is_instance_valid(branch):
				branch.queue_free()
		branches.clear()
		
		# Don't create branches for very short lightning
		if points.size() < 4:
			return
			
		# Create new crackling branches
		var branch_count = randi_range(1, 3)
		for i in range(branch_count):
			if randf() < 0.6: 
				create_crackling_branch()

	func create_crackling_branch():
		if points.size() < 3:
			return
			
		var branch_start_idx = randi_range(1, points.size() - 2)
		var branch_start = points[branch_start_idx]
		
		# Create branch direction with some randomness
		var main_direction = (points[-1] - points[0]).normalized()
		var branch_angle = randf_range(-PI/3, PI/3) 
		var branch_direction = main_direction.rotated(branch_angle)
		
		var branch_length = randf_range(30.0, 80.0)
		var branch_end = branch_start + branch_direction * branch_length
		
		# Create the branch with its own crackling
		var branch = Line2D.new()
		branch.width = width * randf_range(0.3, 0.7)
		branch.default_color = Color(default_color.r, default_color.g, default_color.b, randf_range(0.4, 0.8))
		branch.z_index = z_index - 1
		branch.end_cap_mode = Line2D.LINE_CAP_ROUND
		branch.antialiased = true
		
		# Add crackling to the branch
		var segments = max(2, int(branch_length / 15.0))
		branch.add_point(branch_start)
		
		for i in range(1, segments):
			var t = float(i) / float(segments)
			var base_point = branch_start.lerp(branch_end, t)
			var perpendicular = Vector2(-branch_direction.y, branch_direction.x)
			var offset = sin(t * PI * 5.0 + lifetime * crackling_speed * 3.0) * 8.0
			var crackling_point = base_point + perpendicular * offset
			branch.add_point(crackling_point)
		
		branch.add_point(branch_end)
		
		get_tree().current_scene.add_child(branch)
		branches.append(branch)

	func create_glow_effect(start_pos: Vector2, end_pos: Vector2, base_width: float, base_color: Color, glow_width: float):
		# Create a wider, more transparent line behind the main lightning for glow
		var glow = Line2D.new()
		glow.points = PackedVector2Array([start_pos, end_pos])
		glow.width = base_width * glow_width  
		glow.default_color = Color(base_color.r, base_color.g, base_color.b, 0.2)  # More transparent
		glow.z_index = z_index - 2  
		glow.antialiased = true
		glow.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		get_tree().current_scene.add_child(glow)
		
		# Make the glow fade out with the main lightning
		var glow_timer = get_tree().create_timer(max_lifetime)
		glow_timer.timeout.connect(func():
			if is_instance_valid(glow):
				glow.queue_free()
		)

	func _process(delta: float):
		lifetime += delta
		crackling_timer += delta
		flicker_timer += delta
		
		# Update crackling pattern continuously
		if crackling_timer >= 0.02:  # Update crackling 50 times per second
			generate_crackling_path()
			crackling_timer = 0.0
		
		# Intensity flicker
		if flicker_timer >= 0.01:  # Very fast flicker
			var intensity_factor = randf_range(0.8, 1.2)
			width = base_width * intensity_factor
			
			# Randomly vary the alpha for electric crackling effect
			var alpha_variation = randf_range(0.7, 1.0)
			default_color.a = alpha_variation
			
			# Update branch intensities
			for branch in branches:
				if is_instance_valid(branch):
					branch.width *= randf_range(0.8, 1.2)
					branch.default_color.a *= randf_range(0.6, 1.0)
			
			flicker_timer = 0.0
		
		# Fade out over time
		var fade_progress = lifetime / max_lifetime
		if fade_progress > 0.7:  # Start fading at 70% of lifetime
			var fade_amount = 1.0 - ((fade_progress - 0.7) / 0.3)
			default_color.a *= fade_amount
			width *= fade_amount
			
			for branch in branches:
				if is_instance_valid(branch):
					branch.default_color.a *= fade_amount
					branch.width *= fade_amount
		
		# Clean up when done
		if lifetime >= max_lifetime:
			for branch in branches:
				if is_instance_valid(branch):
					branch.queue_free()
			queue_free()

func setup(new_attack: Attack, start_position: Vector2, initial_direction: Vector2,
		   chains: int = max_chains, range: float = chain_range,
		   proj_collision_layer: int = collision_layer, proj_collision_mask: int = collision_mask,
		   proj_type: ProjectileType = null) -> void:
	
	attack = new_attack
	max_chains = chains
	chain_range = range
	collision_layer = proj_collision_layer
	collision_mask = proj_collision_mask
	projectile_type = proj_type  # Store the projectile type
	
	global_position = start_position
	
	# Setup audio players based on ProjectileType
	setup_audio_players()
	
	# Play launch sound if available
	play_launch_sound()
	
	# Start the lightning chain from the emitter position
	fire_lightning_chain(start_position, initial_direction, null)

func setup_audio_players() -> void:
	"""Setup audio players based on the ProjectileType's sound configuration"""
	if not projectile_type:
		return
	
	# Setup launch sound player
	if projectile_type.launch_sound:
		launch_audio_player = AudioStreamPlayer2D.new()
		launch_audio_player.stream = projectile_type.launch_sound
		launch_audio_player.name = "LaunchAudioPlayer"
		add_child(launch_audio_player)
	
	# Setup impact sound player
	if projectile_type.impact_sound:
		impact_audio_player = AudioStreamPlayer2D.new()
		impact_audio_player.stream = projectile_type.impact_sound
		impact_audio_player.name = "ImpactAudioPlayer"
		add_child(impact_audio_player)

func play_launch_sound() -> void:
	"""Play the launch sound from ProjectileType"""
	if launch_audio_player and launch_audio_player.stream:
		launch_audio_player.play()
		print("Playing lightning launch sound")
	elif lightning_sound:
		# Fallback to the default lightning sound
		lightning_sound.play()

func play_impact_sound(position: Vector2) -> void:
	"""Play the impact sound at a specific position"""
	if impact_audio_player and impact_audio_player.stream:
		# Create a temporary audio player at the impact position
		var temp_audio = AudioStreamPlayer2D.new()
		temp_audio.stream = impact_audio_player.stream
		temp_audio.global_position = position
		get_tree().current_scene.add_child(temp_audio)
		temp_audio.play()
		
		# Clean up the temporary audio player after it finishes
		temp_audio.finished.connect(func():
			if is_instance_valid(temp_audio):
				temp_audio.queue_free()
		)
		
		print("Playing lightning impact sound at ", position)

func fire_lightning_chain(start_pos: Vector2, search_direction: Vector2, last_target: Node2D) -> void:
	if current_chains >= max_chains or not is_active:
		return
	
	# Find the next target
	var target = find_next_target(start_pos, search_direction, last_target)
	
	if not target:
		# No more targets found, end the chain
		call_deferred("finish_lightning")
		return
	
	var target_pos = target.global_position
	
	print("Lightning chain ", current_chains, ": from ", start_pos, " to ", target_pos)
	
	# Create visual lightning beam directly in the world
	var beam = LightningBeam.new(start_pos, target_pos, beam_width, lightning_color, beam_duration, enable_glow, glow_width)
	get_tree().current_scene.add_child(beam)  # Add to scene root instead of self
	beam_segments.append(beam)
	
	# Calculate damage for this chain (with falloff)
	var chain_damage = attack.attack_damage * pow(damage_falloff, current_chains)
	
	# Create attack for this chain
	var chain_attack = Attack.new(
		chain_damage,
		(target_pos - start_pos).normalized() * attack.knockback_force.length(),
		attack.attack_source
	)
	
	# Apply shock effect
	if randf() < shock_chance:
		chain_attack.apply_effect("shock", shock_chance, 0.8)
	
	# Apply damage to target
	if target.has_method("damage"):
		target.damage(chain_attack)
	elif target.has_node("hurtbox_component"):
		var hurtbox = target.get_node("hurtbox_component")
		hurtbox.damage(chain_attack)
	
	# Add to hit enemies list
	hit_enemies.append(target)
	current_chains += 1
	
	# Show impact effect with sound
	show_impact_effect(target_pos)
	
	# Continue chain after a short delay for visual effect
	if current_chains < max_chains:
		get_tree().create_timer(0.08).timeout.connect(_continue_chain.bind(target_pos))
	else:
		call_deferred("finish_lightning")

func find_next_target(start_pos: Vector2, preferred_direction: Vector2, exclude_target: Node2D) -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var best_target: Node2D = null
	var best_score: float = -1.0
	
	# Get all potential targets in range
	var potential_targets = get_enemies_in_range(start_pos, chain_range)
	
	for enemy in potential_targets:
		# Skip if already hit or is the exclude target
		if hit_enemies.has(enemy) or enemy == exclude_target:
			continue
		
		# Skip if not valid
		if not is_instance_valid(enemy):
			continue
		
		var enemy_pos = enemy.global_position
		var distance = start_pos.distance_to(enemy_pos)
		
		# Check if there's a clear line of sight
		var query = PhysicsRayQueryParameters2D.create(start_pos, enemy_pos)
		query.collision_mask = 1  # Only check walls/obstacles (layer 1)
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		
		# If ray hits something before reaching the enemy, skip
		if result and result.collider != enemy:
			continue
		
		# Calculate score based on distance and direction preference
		var direction_to_enemy = (enemy_pos - start_pos).normalized()
		var direction_score = 1.0
		
		if preferred_direction != Vector2.ZERO:
			direction_score = preferred_direction.dot(direction_to_enemy) * 0.5 + 0.5
		
		var distance_score = 1.0 - (distance / chain_range)
		var total_score = direction_score * 0.3 + distance_score * 0.7
		
		if total_score > best_score:
			best_score = total_score
			best_target = enemy
	
	return best_target

func get_enemies_in_range(center: Vector2, range: float) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	
	# Get all nodes in the "enemies" group
	var enemy_nodes = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemy_nodes:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		
		var enemy_node = enemy as Node2D
		var distance = center.distance_to(enemy_node.global_position)
		
		if distance <= range:
			enemies.append(enemy_node)
	
	return enemies

func _continue_chain(target_pos: Vector2) -> void:
	if not is_instance_valid(self) or not is_active:
		return
	
	# Continue from the position, find_next_target will avoid already hit enemies
	fire_lightning_chain(target_pos, Vector2.ZERO, null)

func finish_lightning() -> void:
	is_active = false
	
	# Wait for all visual effects to finish before cleaning up
	var max_beam_duration = beam_duration
	get_tree().create_timer(max_beam_duration + 0.1).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

func set_collision_layers(layer: int, mask: int) -> void:
	collision_layer = layer
	collision_mask = mask

func show_impact_effect(position: Vector2) -> void:
	# Play impact sound at the impact position
	play_impact_sound(position)
	
	# Create impact particles
	if impact_particles:
		var particles_instance = impact_particles.duplicate()
		get_tree().current_scene.add_child(particles_instance)
		particles_instance.global_position = position
		particles_instance.emitting = true
		
		# Clean up particles after emission
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(particles_instance):
				particles_instance.queue_free()
		)
	
	# Create a small electric burst effect
	var burst = LightningBeam.new(position, position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 
									beam_width * 0.5, lightning_color, 0.2, enable_glow, glow_width)
	get_tree().current_scene.add_child(burst)  # Add to scene root
