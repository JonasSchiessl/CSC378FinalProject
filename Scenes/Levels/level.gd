extends Node2D

@onready var player = $Player
@onready var enemy_spawner = $EnemySpawner  
var death_screen: DeathScreen
var build_phase_ui: BuildUI  
var win_ui: WinUI
var tower_container: Node2D

# Game state
var current_phase: GameManager.Phase = GameManager.Phase.BUILD
var is_game_active: bool = false
var current_build_timer: Timer = null

func _ready():
	setup_ui()
	setup_containers()
	setup_connections()
	setup_game_manager()
	start_game()

func setup_ui():
	"""Setup death screen and other UI elements"""
	print("=== SETUP_UI ===")
	
	# Create a CanvasLayer for UI elements
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)
	
	# Add death screen to UI layer
	death_screen = preload("res://Scenes/Player/death_screen.tscn").instantiate()
	ui_layer.add_child(death_screen) 
	death_screen.visible = false  # Hide UI at start
	print("Death screen created")
	
	# Setup build phase UI on UI layer
	print("Loading build_phase_ui...")
	build_phase_ui = preload("res://Scenes/UI/GamePhases/build_phase_ui.tscn").instantiate()
	print("build_phase_ui loaded: ", build_phase_ui)
	
	ui_layer.add_child(build_phase_ui)
	print("build_phase_ui added as child to CanvasLayer")
	print("build_phase_ui size after add: ", build_phase_ui.size)
	print("build_phase_ui position after add: ", build_phase_ui.position)
	print("build_phase_ui visible after add: ", build_phase_ui.visible)
	
	win_ui = preload("res://Scenes/UI/win_ui.tscn").instantiate()
	ui_layer.add_child(win_ui)
	
	# Connect signal
	if build_phase_ui.has_signal("fight_phase_requested"):
		build_phase_ui.fight_phase_requested.connect(_on_fight_phase_requested)
		print("Signal connected successfully")
	else:
		print("ERROR: fight_phase_requested signal not found!")
	
	print("=== SETUP_UI COMPLETE ===")

func setup_containers():
	"""Create containers for game objects"""
	tower_container = Node2D.new()
	tower_container.name = "Towers"
	add_child(tower_container)

func setup_connections():
	"""Connect signals"""
	# Player signals
	$Player.player_death.connect(_on_player_death)
	
	# Enemy spawner signals (if spawner exists)
	if enemy_spawner:
		enemy_spawner.phase_completed.connect(_on_phase_completed)
		enemy_spawner.wave_completed.connect(_on_wave_completed)
		enemy_spawner.all_phases_completed.connect(_on_all_phases_completed)
	else:
		push_warning("No EnemySpawner found! Add one to your scene for wave management.")

func setup_game_manager():
	"""Initialize GameManager if it exists"""
	if GameManager.instance:
		# Connect to phase changes
		GameManager.instance.phase_changed.connect(_on_game_phase_changed)
		print("Connected to GameManager")
	else:
		push_warning("No GameManager found! Creating basic phase management.")
		# Fallback: create basic phase management without GameManager
		setup_basic_phase_management()

func setup_basic_phase_management():
	"""Fallback phase management if no GameManager exists"""
	print("=== SETUP_BASIC_PHASE_MANAGEMENT ===")
	print("Setting up basic phase management")
	current_phase = GameManager.Phase.BUILD
	print("Current phase set to: ", current_phase)
	
	# Check if build_phase_ui exists
	if build_phase_ui:
		print("build_phase_ui exists: ", build_phase_ui.name)
		print("build_phase_ui visible: ", build_phase_ui.visible)
		print("build_phase_ui position: ", build_phase_ui.position)
		
		# Actually start the build phase UI!
		start_build_phase()
	else:
		print("ERROR: build_phase_ui is null!")
	print("=== SETUP_BASIC_PHASE_MANAGEMENT COMPLETE ===")

func start_game():
	"""Start the game"""
	is_game_active = true
	print("Game started!")
	
	# Start with a build phase (no auto-timer)
	if GameManager.instance:
		GameManager.instance.set_phase(GameManager.Phase.BUILD)
		print("Starting with build phase - waiting for player input")
		# Make sure to actually start the build phase UI
		start_build_phase()
	else:
		# Fallback: start build phase without timer
		start_build_phase()

func start_build_phase():
	"""Start a build phase (duration parameter ignored - only button starts combat)"""
	print("Build phase started - waiting for player to start combat")
	current_phase = GameManager.Phase.BUILD
	
	# Show build phase UI
	if build_phase_ui:
		var phase_info = "Build Phase - Prepare for Battle!"
		if enemy_spawner:
			var spawner_info = enemy_spawner.get_phase_info()
			if spawner_info.total_phases > 0:
				phase_info = "Build Phase - Phase %d/%d Coming Up!" % [spawner_info.current_phase, spawner_info.total_phases]
		
		build_phase_ui.show_build_ui(phase_info)

func start_combat_phase():
	"""Start a combat phase"""
	print("=== START_COMBAT_PHASE ===")
	print("Combat phase started!")
	current_phase = GameManager.Phase.FIGHT
	
	# Hide build phase UI
	if build_phase_ui:
		build_phase_ui.hide_build_ui()
		print("Build UI hidden")
	
	# Check enemy spawner
	if enemy_spawner:
		print("Enemy spawner found: ", enemy_spawner.name)
		print("Enemy spawner position: ", enemy_spawner.position)
		
		# Check if spawner has phases configured
		if enemy_spawner.has_method("get_phase_info"):
			var phase_info = enemy_spawner.get_phase_info()
			print("Spawner phase info: ", phase_info)
		
		# Check if spawner has phases array
		if "phases" in enemy_spawner:
			print("Spawner phases: ", enemy_spawner.phases)
			print("Number of phases: ", enemy_spawner.phases.size())
		
		print("Starting enemy spawner...")
	else:
		print("ERROR: No enemy_spawner found!")
	
	if GameManager.instance:
		print("Setting GameManager to FIGHT phase")
		GameManager.instance.set_phase(GameManager.Phase.FIGHT)
	elif enemy_spawner:
		print("No GameManager - manually starting spawner")
		# Fallback: manually start spawner if no GameManager
		if enemy_spawner.has_method("start_phases"):
			enemy_spawner.start_phases()
			print("Called enemy_spawner.start_phases()")
		else:
			print("ERROR: enemy_spawner has no start_phases() method!")
	else:
		print("ERROR: No GameManager AND no enemy_spawner!")
	
	print("=== START_COMBAT_PHASE COMPLETE ===")

func _on_fight_phase_requested():
	"""Called when player presses Start Fight button"""
	print("Fight phase requested by player!")
	
	# No timer to stop since we don't use auto-timers anymore
	current_build_timer = null
	
	# Start combat phase immediately
	start_combat_phase()

func _on_game_phase_changed(new_phase: GameManager.Phase):
	"""Handle phase changes from GameManager"""
	current_phase = new_phase
	
	match new_phase:
		GameManager.Phase.BUILD:
			print("Switched to BUILD phase")
			start_build_phase()
			
		GameManager.Phase.FIGHT:
			print("Switched to FIGHT phase")
			# Hide build UI
			if build_phase_ui:
				build_phase_ui.hide_build_ui()

func _on_phase_completed(phase_index: int):
	"""Called when an enemy phase completes"""
	print("Enemy phase %d completed! Build phase starting..." % (phase_index + 1))
	
	# Add any phase completion rewards, UI updates, etc.
	# The spawner will automatically handle the build phase timing

func _on_wave_completed(phase_index: int, wave_index: int):
	"""Called when a wave completes"""
	print("Wave %d of phase %d completed!")
	
	# Add wave completion effects, currency rewards, etc.
	# Maybe show a brief UI notification

func _on_all_phases_completed():
	"""Called when all enemy phases are defeated - VICTORY!"""
	print("🎉 VICTORY! All enemy phases defeated!")
	handle_victory()

func handle_victory():
	"""Handle victory condition"""
	is_game_active = false
	win_ui.start_UI()
	player.set_physics_process(false)  
	player.set_process(false) 
	player.set_process_input(false)
	player.get_node("AnimatedSprite2D").pause()
	# You can add victory screen, final score, etc.
	print("Level completed successfully!")

func load_next_level():
	"""Load the next level (example)"""
	# get_tree().change_scene_to_file("res://Scenes/Levels/level_2.tscn")
	pass

func _on_player_death():
	"""Handle player death"""
	print("Player died!")
	is_game_active = false
	death_screen.show_death_screen()
	
	# Stop enemy spawning
	if enemy_spawner:
		enemy_spawner.phase_active = false
		enemy_spawner.wave_active = false

func restart_level():
	"""Restart the current level"""
	get_tree().reload_current_scene()

func skip_to_combat():
	"""Skip to combat phase (for testing)"""
	if GameManager.instance:
		GameManager.instance.set_phase(GameManager.Phase.FIGHT)
	else:
		start_combat_phase()

func skip_wave():
	"""Skip current wave (for testing)"""
	if enemy_spawner:
		enemy_spawner.force_next_wave()

func skip_phase():
	"""Skip current phase (for testing)"""
	if enemy_spawner:
		enemy_spawner.force_next_phase()

func get_game_status() -> Dictionary:
	"""Get current game status for debugging"""
	var status = {
		"game_active": is_game_active,
		"current_phase": GameManager.Phase.keys()[current_phase] if current_phase < GameManager.Phase.size() else "UNKNOWN",
		"player_alive": is_instance_valid(player) and player.get_node("health_component").health > 0,
		"spawner_info": {}
	}
	
	if enemy_spawner:
		status.spawner_info = enemy_spawner.get_phase_info()
	
	return status

func print_game_status():
	"""Print current game status"""
	var status = get_game_status()
	print("=== LEVEL GAME STATUS ===")
	print("Game Active: %s" % status.game_active)
	print("Current Phase: %s" % status.current_phase)
	print("Player Alive: %s" % status.player_alive)
	
	if enemy_spawner:
		print("\n--- Enemy Spawner ---")
		enemy_spawner.print_debug_info()
	
	print("========================")

# Input handling for debug commands (optional)
func _input(event: InputEvent):
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:  # Debug info
				print_game_status()
			KEY_F2:  # Skip wave
				skip_wave()
			KEY_F3:  # Skip phase
				skip_phase()
			KEY_F4:  # Skip to combat
				skip_to_combat()
