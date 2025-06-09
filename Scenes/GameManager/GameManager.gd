extends Node
class_name GameManager

# Singleton pattern
static var instance: GameManager

# Game phases
enum Phase {
	BUILD,
	FIGHT
}

var current_phase: Phase = Phase.BUILD

# Signals for phase changes
signal phase_changed(new_phase: Phase)
signal build_phase_started()
signal fight_phase_started()

func _ready() -> void:
	# Set up singleton
	instance = self
	
	# Start in build phase
	set_phase(Phase.BUILD)

func _input(event: InputEvent) -> void:
	# Toggle between phases with Tab key for now
	if event.is_action_pressed("togglePhase"): 
		toggle_phase()

# Set the current phase
func set_phase(new_phase: Phase) -> void:
	print("=== GameManager.set_phase() called ===")
	print("Current phase: ", current_phase)
	print("New phase: ", new_phase)
	
	if current_phase == new_phase:
		print("Phase unchanged, returning early")
		return
	
	print("Changing phase from ", current_phase, " to ", new_phase)
	current_phase = new_phase
	
	# Check signal connections
	var connections = phase_changed.get_connections()
	print("Number of connections to phase_changed signal: ", connections.size())
	for i in range(connections.size()):
		var connection = connections[i]
		print("  Connection ", i, ": ", connection.callable.get_object().get_script().get_path(), " -> ", connection.callable.get_method())
	
	print("Emitting phase_changed signal...")
	phase_changed.emit(new_phase)
	print("Signal emitted!")
	
	match new_phase:
		Phase.BUILD:
			print("Entering BUILD phase")
			build_phase_started.emit()
		Phase.FIGHT:
			print("Entering FIGHT phase") 
			fight_phase_started.emit()
	
	print("=== GameManager.set_phase() complete ===\n")


func toggle_phase() -> void:
	if current_phase == Phase.BUILD:
		set_phase(Phase.FIGHT)
	else:
		set_phase(Phase.BUILD)


func is_build_phase() -> bool:
	return current_phase == Phase.BUILD


func is_fight_phase() -> bool:
	return current_phase == Phase.FIGHT
