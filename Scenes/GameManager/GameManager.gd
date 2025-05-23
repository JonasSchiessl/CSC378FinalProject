extends Node
class_name GameManager

# Singleton pattern - accessible from anywhere via GameManager
static var instance: GameManager

# Game phases
enum Phase {
	BUILD,
	FIGHT
}

# Current phase
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
	# Toggle between phases with Tab key (you can change this)
	if event.is_action_pressed("togglePhase"):  # You'll need to add this to input map
		toggle_phase()

# Set the current phase
func set_phase(new_phase: Phase) -> void:
	if current_phase == new_phase:
		return
	
	current_phase = new_phase
	phase_changed.emit(new_phase)
	
	match new_phase:
		Phase.BUILD:
			print("Entering BUILD phase")
			build_phase_started.emit()
		Phase.FIGHT:
			print("Entering FIGHT phase")
			fight_phase_started.emit()

# Toggle between phases
func toggle_phase() -> void:
	if current_phase == Phase.BUILD:
		set_phase(Phase.FIGHT)
	else:
		set_phase(Phase.BUILD)

# Check if we're in build phase
func is_build_phase() -> bool:
	return current_phase == Phase.BUILD

# Check if we're in fight phase
func is_fight_phase() -> bool:
	return current_phase == Phase.FIGHT
