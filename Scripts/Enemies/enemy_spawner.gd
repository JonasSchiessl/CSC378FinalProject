extends Node2D

# Spawn area configuration
@export var spawn_area: Area2D  # Reference to the Area2D spawn plane
@export var camera_margin: float = 100.0  # Extra margin outside camera view
@export var max_spawn_attempts: int = 50  # Max attempts to find valid spawn position

@export var phase_json_file: String = "res://Data/Waves/Level1/phases.json"  # Path to your JSON file
@export var use_json_phases: bool = true  # Toggle between JSON and Resource phases

# Enemy types
@onready var parent = get_parent()
@onready var player = parent.get_node_or_null("Player")
@onready var enemy_container

var PoisonRatClass = preload("res://Scenes/Enemies/poison_rat.tscn")
var MeleeRatClass = preload("res://Scenes/Enemies/melee_rat.tscn")
var TowerDestroyerRatClass = preload("res://Scenes/Enemies/tower_destroyer_rat.tscn")

# Phase and wave management
@export var phases: Array[Resource] = []
var current_phase_index: int = 0
var current_wave_index: int = 0
var current_phase: PhaseData
var enemies_alive: int = 0
var phase_active: bool = false
var wave_active: bool = false

# Timers
var wave_timer: Timer
var build_phase_timer: Timer

# Signals
signal phase_completed(phase_index: int)
signal wave_completed(phase_index: int, wave_index: int)
signal all_phases_completed()


func _ready() -> void:
	print("=== ENEMY SPAWNER _ready() ===")
	
	# DON'T connect here - do it deferred
	# Instead, defer the connection
	call_deferred("connect_to_gamemanager")
	
	# Setup timers
	wave_timer = Timer.new()
	add_child(wave_timer)
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	wave_timer.one_shot = true
	
	build_phase_timer = Timer.new()
	add_child(build_phase_timer)
	build_phase_timer.timeout.connect(_on_build_phase_completed)
	build_phase_timer.one_shot = true
	
	# Load phases based on preference
	if use_json_phases:
		load_phases_from_json()
	elif phases.is_empty():
		push_error("no enemy phase data set")
	
	print("Final phases count: ", phases.size())
	debug_phases_detailed()
	
	for i in range(phases.size()):
		var phase = phases[i]
		if phase and phase is PhaseData:
			print("  Phase %d: %s (%d waves)" % [i+1, phase.phase_name, phase.waves.size()])
	
	# Validate spawn area
	if not spawn_area:
		push_error("EnemySpawner: No spawn_area assigned!")
		return
	
	if not spawn_area.get_child(0) is CollisionShape2D:
		push_error("EnemySpawner: spawn_area must have a CollisionShape2D child!")
		return
	
	print("=== ENEMY SPAWNER _ready() COMPLETE ===")
	

func connect_to_gamemanager():
	print("\n=== DEFERRED GAMEMANAGER CONNECTION ===")
	
	if not GameManager.instance:
		print("ERROR: GameManager.instance is null! Retrying in 0.1 seconds...")
		await get_tree().create_timer(0.1).timeout
		connect_to_gamemanager()
		return
	
	print("GameManager found: ", GameManager.instance)
	print("GameManager current phase: ", GameManager.instance.current_phase)
	
	# Check current connections
	var connections = GameManager.instance.phase_changed.get_connections()
	print("Current connections before connecting spawner: ", connections.size())
	
	# Check if we're already connected
	var already_connected = false
	for connection in connections:
		if connection.callable.get_object() == self:
			print("Enemy spawner already connected!")
			already_connected = true
			break
	
	if not already_connected:
		print("Connecting enemy spawner to phase_changed signal...")
		var result = GameManager.instance.phase_changed.connect(_on_phase_changed)
		
		if result == OK:
			print("✅ Enemy spawner connected successfully!")
		else:
			print("❌ Connection failed with error: ", result)
			return
	
	# Verify the connection worked
	connections = GameManager.instance.phase_changed.get_connections()
	print("Total connections after enemy spawner connection: ", connections.size())
	
	var spawner_found = false
	for i in range(connections.size()):
		var connection = connections[i]
		var obj = connection.callable.get_object()
		var method = connection.callable.get_method()
		print("  Connection ", i, ": ", obj.get_script().get_path() if obj.get_script() else obj, " -> ", method)
		
		if obj == self:
			spawner_found = true
			print("    ✅ This is the enemy spawner!")
	
	if not spawner_found:
		print("❌ ERROR: Enemy spawner not found in connections!")
	else:
		print("✅ Enemy spawner successfully connected and verified!")
	
	print("=== DEFERRED CONNECTION COMPLETE ===\n")

func start_phases() -> void:
	"""Start the phase/wave system"""
	if phases.is_empty():
		push_error("EnemySpawner: No phases configured!")
		return
	
	current_phase_index = 0
	current_wave_index = 0
	start_next_phase()

func start_next_phase() -> void:
	"""Start the current phase"""
	if current_phase_index >= phases.size():
		print("All phases completed!")
		all_phases_completed.emit()
		return
	
	current_phase = phases[current_phase_index]
	current_wave_index = 0
	phase_active = true
	
	print("Starting %s with %d waves" % [current_phase.phase_name, current_phase.waves.size()])
	
	# Create enemy container for this phase
	enemy_container = Node2D.new()
	enemy_container.name = "Phase_%d_Enemies" % (current_phase_index + 1)
	parent.add_child(enemy_container)
	
	start_next_wave()

func start_next_wave() -> void:
	"""Start the current wave"""
	if not phase_active or current_wave_index >= current_phase.waves.size():
		complete_phase()
		return
	
	var wave = current_phase.waves[current_wave_index]
	wave_active = true
	
	var total_enemies = 0
	for group in wave.enemy_groups:
		total_enemies += group.enemy_count
	
	print("Starting wave %d/%d: %d enemies in %d groups" % [
		current_wave_index + 1, 
		current_phase.waves.size(),
		total_enemies,
		wave.enemy_groups.size()
	])
	
	spawn_wave(wave)

func spawn_wave(wave: WaveData) -> void:
	"""Spawn all enemies in a wave according to the spawn pattern"""
	match wave.spawn_pattern:
		WaveData.SpawnPattern.SEQUENTIAL:
			spawn_wave_sequential(wave)
		WaveData.SpawnPattern.SIMULTANEOUS:
			spawn_wave_simultaneous(wave)
		WaveData.SpawnPattern.RANDOM_MIX:
			spawn_wave_random_mix(wave)

func spawn_wave_sequential(wave: WaveData) -> void:
	"""Spawn enemy groups one after another"""
	var total_delay = 0.0
	
	for group in wave.enemy_groups:
		total_delay += group.group_delay
		
		for i in range(group.enemy_count):
			var spawn_delay = total_delay + (i * wave.spawn_delay)
			get_tree().create_timer(spawn_delay).timeout.connect(
				func(): spawn_single_enemy(group.enemy_type)
			)
		
		# Add time for this group to finish spawning before next group starts
		total_delay += (group.enemy_count - 1) * wave.spawn_delay

func spawn_wave_simultaneous(wave: WaveData) -> void:
	"""Spawn all enemy groups at the same time"""
	for group in wave.enemy_groups:
		for i in range(group.enemy_count):
			var spawn_delay = group.group_delay + (i * wave.spawn_delay)
			get_tree().create_timer(spawn_delay).timeout.connect(
				func(): spawn_single_enemy(group.enemy_type)
			)

func spawn_wave_random_mix(wave: WaveData) -> void:
	"""Randomly mix enemies from all groups"""
	# Create a list of all enemies to spawn
	var spawn_list: Array[String] = []
	for group in wave.enemy_groups:
		for i in range(group.enemy_count):
			spawn_list.append(group.enemy_type)
	
	# Shuffle the list
	spawn_list.shuffle()
	
	# Spawn with delays
	for i in range(spawn_list.size()):
		var spawn_delay = i * wave.spawn_delay
		var enemy_type = spawn_list[i]
		get_tree().create_timer(spawn_delay).timeout.connect(
			func(): spawn_single_enemy(enemy_type)
		)

func spawn_single_enemy(enemy_type: String) -> void:
	"""Spawn a single enemy at a valid position"""
	if not enemy_container:
		return
	
	var spawn_position = get_valid_spawn_position()
	if spawn_position == Vector2.ZERO:
		print("Failed to find valid spawn position for %s" % enemy_type)
		return
	
	var enemy_scene: PackedScene
	match enemy_type:
		"poison_rat":
			enemy_scene = PoisonRatClass
		"melee_rat":
			enemy_scene = MeleeRatClass
		"tower_destroyer_rat":
			enemy_scene = TowerDestroyerRatClass
		_:
			push_error("Unknown enemy type: %s" % enemy_type)
			return
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_position
	enemy_container.add_child(enemy)
	
	# Connect to enemy death to track when wave is complete
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)
	elif enemy.has_node("health_component"):
		var health_comp = enemy.get_node("health_component")
		if health_comp.has_signal("health_depleted"):
			health_comp.health_depleted.connect(_on_enemy_died)
	
	enemies_alive += 1
	print("Spawned %s at %s (Enemies alive: %d)" % [enemy_type, spawn_position, enemies_alive])

func get_valid_spawn_position() -> Vector2:
	"""Get a spawn position within the area but outside camera view"""
	
	if not spawn_area or not player:
		return Vector2.ZERO
	
	var collision_shape = spawn_area.get_child(0) as CollisionShape2D
	if not collision_shape:
		return Vector2.ZERO
	
	var shape = collision_shape.shape
	var camera = get_viewport().get_camera_2d()
	
	if not camera:
		# Fallback if no camera
		return get_random_position_in_shape(shape, spawn_area.global_transform)
	
	# Get camera bounds
	var camera_pos = camera.global_position
	var zoom = camera.zoom
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_size = viewport_size / zoom
	
	var camera_rect = Rect2(
		camera_pos - camera_size / 2 - Vector2.ONE * camera_margin,
		camera_size + Vector2.ONE * camera_margin * 2
	)
	
	# Try to find a position outside camera view
	for attempt in range(max_spawn_attempts):
		var test_position = get_random_position_in_shape(shape, spawn_area.global_transform)
		
		# Check if position is outside camera view
		if not camera_rect.has_point(test_position):
			return test_position
	
	# Fallback: return any valid position in the area
	print("Warning: Could not find spawn position outside camera view, using fallback")
	return get_random_position_in_shape(shape, spawn_area.global_transform)

func get_random_position_in_shape(shape: Shape2D, transform: Transform2D) -> Vector2:
	"""Get a random position within a shape"""
	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		var size = rect_shape.size
		var local_pos = Vector2(
			randf_range(-size.x / 2, size.x / 2),
			randf_range(-size.y / 2, size.y / 2)
		)
		return transform * local_pos
	
	elif shape is CircleShape2D:
		var circle_shape = shape as CircleShape2D
		var radius = circle_shape.radius
		var angle = randf() * TAU
		var distance = sqrt(randf()) * radius  # Uniform distribution in circle
		var local_pos = Vector2(cos(angle), sin(angle)) * distance
		return transform * local_pos
	
	else:
		# Fallback for other shapes - use bounding box
		push_warning("Unsupported shape type for spawning, using transform position")
		return transform.origin

func _on_enemy_died() -> void:
	"""Called when an enemy dies"""
	enemies_alive -= 1
	print("Enemy died. Enemies remaining: %d" % enemies_alive)
	
	# Check if wave is complete
	if enemies_alive <= 0 and wave_active:
		complete_wave()

func complete_wave() -> void:
	"""Complete the current wave and start next one"""
	wave_active = false
	var completed_wave = current_phase.waves[current_wave_index]
	
	print("Wave %d/%d completed!" % [current_wave_index + 1, current_phase.waves.size()])
	wave_completed.emit(current_phase_index, current_wave_index)
	
	current_wave_index += 1
	
	# Start next wave after delay
	if current_wave_index < current_phase.waves.size():
		var next_wave = current_phase.waves[current_wave_index]
		if next_wave.wave_delay > 0:
			print("Starting next wave in %.1f seconds..." % next_wave.wave_delay)
			wave_timer.wait_time = next_wave.wave_delay
			wave_timer.start()
		else:
			start_next_wave()
	else:
		complete_phase()

func _on_wave_timer_timeout() -> void:
	"""Start next wave after timer"""
	start_next_wave()

func complete_phase() -> void:
	"""Complete the current phase"""
	phase_active = false
	
	print("%s completed!" % current_phase.phase_name)
	phase_completed.emit(current_phase_index)
	
	# Clean up enemy container
	if is_instance_valid(enemy_container):
		enemy_container.queue_free()
		enemy_container = null
	
	current_phase_index += 1
	
	# Start build phase
	if current_phase_index < phases.size():
		start_build_phase()
	else:
		print("All phases completed!")
		all_phases_completed.emit()

func start_build_phase() -> void:
	"""Start build phase between combat phases"""
	var build_duration = current_phase.build_phase_duration if current_phase else 30.0
	
	print("Starting build phase for %.1f seconds" % build_duration)
	
	# Switch to build phase
	if GameManager.instance:
		GameManager.instance.set_phase(GameManager.Phase.BUILD)
	
	build_phase_timer.wait_time = build_duration
	build_phase_timer.start()

func _on_build_phase_completed() -> void:
	"""Called when build phase timer expires"""
	print("Build phase completed, starting next combat phase")
	
	# Switch back to fight phase
	if GameManager.instance:
		GameManager.instance.set_phase(GameManager.Phase.FIGHT)
	
	start_next_phase()

func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	print("\n🎯 ENEMY SPAWNER RECEIVED PHASE_CHANGED SIGNAL!")
	print("New phase: ", GameManager.Phase.keys()[new_phase])
	print("Current spawner state:")
	print("  phase_active: ", phase_active)
	print("  wave_active: ", wave_active)
	print("  current_phase_index: ", current_phase_index)
	
	match new_phase:
		GameManager.Phase.FIGHT:
			print("🚀 Processing FIGHT phase in spawner...")
			if not phase_active and not wave_active and current_phase_index == 0:
				print("🚀 Starting enemy spawning system...")
				start_phases()
			else:
				print("⚠️ Spawner already active, skipping start_phases()")
		GameManager.Phase.BUILD:
			print("🔧 Processing BUILD phase in spawner...")
			if wave_timer and wave_timer.is_inside_tree():
				wave_timer.stop()
				print("Stopped wave timer")
	
	print("🎯 PHASE SIGNAL PROCESSING COMPLETE!\n")

func force_next_wave() -> void:
	"""Force start the next wave (for testing)"""
	if wave_active:
		complete_wave()
	else:
		start_next_wave()

func force_next_phase() -> void:
	"""Force start the next phase (for testing)"""
	if phase_active:
		complete_phase()
	else:
		start_next_phase()

func skip_build_phase() -> void:
	"""Skip the current build phase (for testing)"""
	if build_phase_timer.time_left > 0:
		build_phase_timer.stop()
		_on_build_phase_completed()

func get_phase_info() -> Dictionary:
	"""Get current phase/wave information"""
	var info = {
		"current_phase": current_phase_index + 1,
		"total_phases": phases.size(),
		"current_wave": current_wave_index + 1,
		"total_waves_in_phase": 0,
		"enemies_alive": enemies_alive,
		"phase_active": phase_active,
		"wave_active": wave_active,
		"build_time_left": build_phase_timer.time_left
	}
	
	# Fix: Check if current_phase exists and get its wave count
	if current_phase != null and current_phase is PhaseData:
		info.total_waves_in_phase = current_phase.waves.size()
		print("DEBUG: Current phase has ", current_phase.waves.size(), " waves")
	elif current_phase_index < phases.size() and phases[current_phase_index] != null:
		# Fallback: get from phases array
		var phase = phases[current_phase_index]
		if phase is PhaseData:
			info.total_waves_in_phase = phase.waves.size()
			print("DEBUG: Phase from array has ", phase.waves.size(), " waves")
	else:
		print("DEBUG: No current phase available or invalid phase")
	
	print("DEBUG: get_phase_info() returning: ", info)
	return info

func load_phases_from_json() -> void:
	"""Load phase configuration from JSON file"""
	print("Loading phases from JSON: ", phase_json_file)
	
	if not FileAccess.file_exists(phase_json_file):
		push_error("JSON phase file not found: " + phase_json_file)
		print("Falling back to default phases...")
		create_default_phase()  # Create a fallback phase
		return
	
	var file = FileAccess.open(phase_json_file, FileAccess.READ)
	if not file:
		push_error("Could not open JSON phase file: " + phase_json_file)
		create_default_phase()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	print("JSON file loaded, content length: ", json_text.length())
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Error parsing JSON phase file: " + json.get_error_message())
		create_default_phase()
		return
	
	var data = json.data
	if not data.has("phases"):
		push_error("JSON file missing 'phases' array")
		create_default_phase()
		return
	
	# Clear existing phases
	phases.clear()
	
	print("Processing ", data.phases.size(), " phases from JSON...")
	
	# Convert JSON data to phase objects
	for phase_data in data.phases:
		var phase = create_phase_from_json(phase_data)
		if phase:
			phases.append(phase)
			print("Successfully added phase: ", phase.phase_name, " with ", phase.waves.size(), " waves")
		else:
			print("Failed to create phase from JSON data")
	
	if phases.is_empty():
		print("No phases were successfully loaded, creating default phase")
		create_default_phase()
	else:
		print("Loaded ", phases.size(), " phases from JSON successfully!")

func create_phase_from_json(phase_data: Dictionary) -> PhaseData:
	"""Create a PhaseData object from JSON data"""
	print("Creating phase from JSON: ", phase_data.get("phase_name", "Unnamed"))
	
	var phase = PhaseData.new()
	
	phase.phase_name = phase_data.get("phase_name", "Unnamed Phase")
	phase.build_phase_duration = phase_data.get("build_phase_duration", 30.0)
	phase.phase_description = phase_data.get("phase_description", "")
	
	print("  Phase name: ", phase.phase_name)
	print("  Build duration: ", phase.build_phase_duration)
	
	# Create waves
	if phase_data.has("waves") and phase_data.waves is Array:
		print("  Processing ", phase_data.waves.size(), " waves")
		for wave_data in phase_data.waves:
			if wave_data is Dictionary:
				var wave = create_wave_from_json(wave_data)
				if wave:
					phase.waves.append(wave)
					print("    Added wave: ", wave.wave_name, " with ", wave.enemy_groups.size(), " groups")
				else:
					print("    Failed to create wave")
			else:
				print("    Wave data is not a Dictionary!")
	else:
		print("  No waves found in phase data!")
	
	print("  Final phase has ", phase.waves.size(), " waves")
	return phase

func create_wave_from_json(wave_data: Dictionary) -> WaveData:
	"""Create a WaveData object from JSON data"""
	print("    Creating wave: ", wave_data.get("wave_name", "Unnamed"))
	
	var wave = WaveData.new()
	
	wave.wave_name = wave_data.get("wave_name", "")
	wave.spawn_delay = wave_data.get("spawn_delay", 1.0)
	wave.wave_delay = wave_data.get("wave_delay", 5.0)
	
	# Set spawn pattern
	var pattern_string = wave_data.get("spawn_pattern", "SEQUENTIAL")
	match pattern_string:
		"SEQUENTIAL":
			wave.spawn_pattern = WaveData.SpawnPattern.SEQUENTIAL
		"SIMULTANEOUS":
			wave.spawn_pattern = WaveData.SpawnPattern.SIMULTANEOUS
		"RANDOM_MIX":
			wave.spawn_pattern = WaveData.SpawnPattern.RANDOM_MIX
		_:
			wave.spawn_pattern = WaveData.SpawnPattern.SEQUENTIAL
			print("      Unknown spawn pattern: ", pattern_string, ", using SEQUENTIAL")
	
	print("      Spawn pattern: ", pattern_string)
	print("      Spawn delay: ", wave.spawn_delay)
	print("      Wave delay: ", wave.wave_delay)
	
	# Create enemy groups
	if wave_data.has("enemy_groups") and wave_data.enemy_groups is Array:
		print("      Processing ", wave_data.enemy_groups.size(), " enemy groups")
		for group_data in wave_data.enemy_groups:
			if group_data is Dictionary:
				var group = create_group_from_json(group_data)
				if group:
					wave.enemy_groups.append(group)
					print("        Added group: ", group.enemy_count, "x ", group.enemy_type)
				else:
					print("        Failed to create group")
			else:
				print("        Group data is not a Dictionary!")
	else:
		print("      No enemy groups found in wave data!")
	
	print("      Final wave has ", wave.enemy_groups.size(), " groups")
	return wave

func create_group_from_json(group_data: Dictionary) -> EnemyGroup:
	"""Create an EnemyGroup object from JSON data"""
	var enemy_group = EnemyGroup.new()
	
	enemy_group.enemy_type = group_data.get("enemy_type", "poison_rat")
	enemy_group.enemy_count = group_data.get("enemy_count", 1)
	enemy_group.group_delay = group_data.get("group_delay", 0.0)
	
	print("          Creating group: ", enemy_group.enemy_count, "x ", enemy_group.enemy_type, " (delay: ", enemy_group.group_delay, ")")
	
	# Validate enemy count
	if enemy_group.enemy_count <= 0:
		print("          WARNING: Enemy count is ", enemy_group.enemy_count, ", setting to 1")
		enemy_group.enemy_count = 1
	
	return enemy_group

func create_default_phase() -> void:
	"""Create a default phase for testing when JSON fails"""
	print("Creating default test phase...")
	
	phases.clear()
	
	var phase = PhaseData.new()
	phase.phase_name = "Default Test Phase"
	phase.build_phase_duration = 20.0
	phase.phase_description = "Fallback phase for testing"
	
	var wave = WaveData.new()
	wave.wave_name = "Test Wave"
	wave.spawn_delay = 1.0
	wave.wave_delay = 3.0
	wave.spawn_pattern = WaveData.SpawnPattern.SEQUENTIAL
	
	var enemy_group = EnemyGroup.new()
	enemy_group.enemy_type = "poison_rat"
	enemy_group.enemy_count = 3
	enemy_group.group_delay = 0.0
	
	wave.enemy_groups.append(enemy_group)
	phase.waves.append(wave)
	phases.append(phase)
	
	print("Default phase created with ", phase.waves.size(), " waves")

# Optional: Save current phases to JSON (for easy editing)
func save_phases_to_json(file_path: String = "res://Data/phases_export.json") -> void:
	"""Export current phases to JSON format"""
	var data = {"phases": []}
	
	for phase in phases:
		if not phase is PhaseData:
			continue
			
		var phase_dict = {
			"phase_name": phase.phase_name,
			"build_phase_duration": phase.build_phase_duration,
			"phase_description": phase.phase_description,
			"waves": []
		}
		
		for wave in phase.waves:
			if not wave is WaveData:
				continue
				
			var pattern_string = "SEQUENTIAL"
			match wave.spawn_pattern:
				WaveData.SpawnPattern.SEQUENTIAL:
					pattern_string = "SEQUENTIAL"
				WaveData.SpawnPattern.SIMULTANEOUS:
					pattern_string = "SIMULTANEOUS"
				WaveData.SpawnPattern.RANDOM_MIX:
					pattern_string = "RANDOM_MIX"
			
			var wave_dict = {
				"wave_name": wave.wave_name,
				"spawn_delay": wave.spawn_delay,
				"wave_delay": wave.wave_delay,
				"spawn_pattern": pattern_string,
				"enemy_groups": []
			}
			
			for group in wave.enemy_groups:
				if not group is EnemyGroup:
					continue
					
				var group_dict = {
					"enemy_type": group.enemy_type,
					"enemy_count": group.enemy_count,
					"group_delay": group.group_delay
				}
				
				wave_dict.enemy_groups.append(group_dict)
			
			phase_dict.waves.append(wave_dict)
		
		data.phases.append(phase_dict)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Phases exported to: ", file_path)
	else:
		push_error("Could not save phases to: " + file_path)

func debug_phases_detailed():
	print("\n=== DETAILED PHASE DEBUG ===")
	print("Total phases loaded: ", phases.size())
	
	for i in range(phases.size()):
		var phase = phases[i]
		print("Phase ", i, ":")
		if not phase:
			print("  - Phase is NULL!")
			continue
		if not phase is PhaseData:
			print("  - Phase is not PhaseData type!")
			continue
			
		print("  - Name: ", phase.phase_name)
		print("  - Build duration: ", phase.build_phase_duration)
		print("  - Waves count: ", phase.waves.size())
		
		for j in range(phase.waves.size()):
			var wave = phase.waves[j]
			print("    Wave ", j, ":")
			if not wave:
				print("      - Wave is NULL!")
				continue
			if not wave is WaveData:
				print("      - Wave is not WaveData type!")
				continue
				
			print("      - Name: ", wave.wave_name)
			print("      - Spawn delay: ", wave.spawn_delay)
			print("      - Wave delay: ", wave.wave_delay)
			print("      - Enemy groups: ", wave.enemy_groups.size())
			
			for k in range(wave.enemy_groups.size()):
				var group = wave.enemy_groups[k]
				print("        Group ", k, ":")
				if not group:
					print("          - Group is NULL!")
					continue
				if not group is EnemyGroup:
					print("          - Group is not EnemyGroup type!")
					continue
					
				print("          - Type: ", group.enemy_type)
				print("          - Count: ", group.enemy_count)
				print("          - Delay: ", group.group_delay)
	
	print("=== END DETAILED DEBUG ===\n")

func print_debug_info() -> void:
	"""Print current spawner status"""
	var info = get_phase_info()
	print("=== ENEMY SPAWNER DEBUG ===")
	print("Phase: %d/%d" % [info.current_phase, info.total_phases])
	print("Wave: %d/%d" % [info.current_wave, info.total_waves_in_phase])
	print("Enemies alive: %d" % info.enemies_alive)
	print("Phase active: %s" % info.phase_active)
	print("Wave active: %s" % info.wave_active)
	print("Build time left: %.1f" % info.build_time_left)
	print("==========================")
