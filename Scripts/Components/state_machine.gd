extends Node
class_name StateMachine

# Current active state
var current_state: State = null
var current_state_name: String = ""

# All available states
var states: Dictionary = {}

# The entity that owns this state machine
@onready var entity: Node = get_parent()

# Pause the state machine
var paused: bool = false

# Add a new state to the state machine
func add_state(state_name: String, state: State) -> void:
	states[state_name] = state

# Change to a new state
func change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_error("State '" + new_state_name + "' does not exist in the state machine!")
		return
	
	# Exit current state
	if current_state:
		current_state.exit()
	
	# Enter new state
	current_state_name = new_state_name
	current_state = states[current_state_name]
	current_state.enter()

# Initialize the state machine with a starting state
func initialize(initial_state: String) -> void:
	change_state(initial_state)

# Process current state
func _process(delta: float) -> void:
	if paused or not current_state:
		return
	
	current_state.process(delta)
	
	# Check for transitions
	var new_state = current_state.check_transitions()
	if new_state != "":
		change_state(new_state)

# Physics process current state
func _physics_process(delta: float) -> void:
	if paused or not current_state:
		return
	
	current_state.physics_process(delta)

# Forward input events to current state
func _input(event: InputEvent) -> void:
	if paused or not current_state:
		return
	
	current_state.input(event)

# Get current state name
func get_current_state() -> String:
	return current_state_name
