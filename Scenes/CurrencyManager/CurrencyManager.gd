extends Node

# Core currency state - this persists across all scenes and rounds
var current_currency: int = 300  

# Configuration for different rewards and costs
var enemy_kill_rewards: Dictionary = {
	"basic_enemy": 10,
	"strong_enemy": 25,
	"boss_enemy": 100,
	"poison_rat": 15 
}

var tower_costs: Dictionary = {
	"basic_tower": 100,
	"advanced_tower": 250,
	"special_tower": 500
}

var building_costs: Dictionary = {
	"wall": 25,
	"trap": 75,
	"upgrade": 150
}

# Signals for communication with other systems
signal currency_changed(new_amount: int, change_amount: int)
signal currency_spent(amount: int, item_name: String)
signal currency_earned(amount: int, source: String)
signal purchase_attempted(item_name: String, cost: int, success: bool)

# Settings that can be modified during gameplay
var currency_multiplier: float = 1.0  # For temporary bonuses or difficulty scaling
var save_file_path: String = "user://currency_save.dat"

func _ready() -> void:
	# Load saved currency when the game starts
	reset_currency_to_default()
	
	# Connect to game events that might affect currency
	if GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	
	print("CurrencyManager initialized with ", current_currency, " currency")

# Core currency operations
func get_current_currency() -> int:
	"""Get the current currency amount"""
	return current_currency

func can_afford(cost: int) -> bool:
	"""Check if the player can afford a specific cost"""
	return current_currency >= cost

func can_afford_item(item_name: String, item_type: String = "tower") -> bool:
	"""Check if the player can afford a specific item by name"""
	var cost = get_item_cost(item_name, item_type)
	return can_afford(cost)

func get_item_cost(item_name: String, item_type: String = "tower") -> int:
	"""Get the cost of a specific item"""
	match item_type:
		"tower":
			return tower_costs.get(item_name, 100)  # Default to 100 if not found
		"building":
			return building_costs.get(item_name, 50)
		_:
			push_warning("Unknown item type: " + item_type)
			return 100

# Currency modification functions
func add_currency(amount: int, source: String = "unknown") -> void:
	"""Add currency with optional source tracking"""
	# Apply any multipliers (for bonuses, difficulty, etc.)
	var actual_amount = int(amount * currency_multiplier)
	
	var old_amount = current_currency
	current_currency += actual_amount
	
	# Emit signals to notify other systems
	currency_changed.emit(current_currency, actual_amount)
	currency_earned.emit(actual_amount, source)
	
	# Auto-save after earning currency
	save_currency()
	
	print("Currency earned: +", actual_amount, " from ", source, " (Total: ", current_currency, ")")

func spend_currency(amount: int, item_name: String = "unknown") -> bool:
	"""Attempt to spend currency, returns true if successful"""
	if not can_afford(amount):
		# Failed purchase - emit signal for UI feedback
		purchase_attempted.emit(item_name, amount, false)
		print("Purchase failed: Not enough currency (Need: ", amount, ", Have: ", current_currency, ")")
		return false
	
	var old_amount = current_currency
	current_currency -= amount
	
	# Emit signals to notify other systems
	currency_changed.emit(current_currency, -amount)
	currency_spent.emit(amount, item_name)
	purchase_attempted.emit(item_name, amount, true)
	
	# Auto-save after spending currency
	save_currency()
	
	print("Currency spent: -", amount, " on ", item_name, " (Remaining: ", current_currency, ")")
	return true

# Wrapper functions for common operations
func try_buy_tower(tower_type: String = "basic_tower") -> bool:
	"""Attempt to buy a tower, returns true if successful"""
	var cost = get_item_cost(tower_type, "tower")
	return spend_currency(cost, tower_type)

func try_buy_item(item_name: String, item_type: String) -> bool:
	"""Generic purchase function for any item type"""
	var cost = get_item_cost(item_name, item_type)
	return spend_currency(cost, item_name)

# Enemy kill reward system
func award_enemy_kill(enemy_type: String = "basic_enemy") -> void:
	"""Award currency for killing an enemy"""
	var reward = enemy_kill_rewards.get(enemy_type, 10)  # Default to 10 if type not found
	add_currency(reward, "enemy_kill:" + enemy_type)

func award_enemy_kill_by_node(enemy_node: Node) -> void:
	"""Award currency based on an enemy node's properties"""
	var enemy_type = "basic_enemy"  # Default
	
	# Try to determine enemy type from the node
	if enemy_node.has_method("get_enemy_type"):
		enemy_type = enemy_node.get_enemy_type()
	elif enemy_node.has_meta("enemy_type"):
		enemy_type = enemy_node.get_meta("enemy_type")
	elif enemy_node.name.to_lower().contains("poison"):
		enemy_type = "poison_rat"
	# Add more detection logic as needed
	
	award_enemy_kill(enemy_type)

# Configuration management functions
func set_enemy_reward(enemy_type: String, reward: int) -> void:
	"""Set the reward amount for a specific enemy type"""
	enemy_kill_rewards[enemy_type] = reward
	print("Set reward for ", enemy_type, " to ", reward)

func set_tower_cost(tower_type: String, cost: int) -> void:
	"""Set the cost for a specific tower type"""
	tower_costs[tower_type] = cost
	print("Set cost for ", tower_type, " to ", cost)

func set_currency_multiplier(multiplier: float) -> void:
	"""Set a global currency multiplier (for bonuses, difficulty scaling, etc.)"""
	currency_multiplier = multiplier
	print("Currency multiplier set to ", multiplier)

# Persistence functions
func save_currency() -> void:
	"""Save current currency to file"""
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		var save_data = {
			"currency": current_currency,
			"multiplier": currency_multiplier,
			"enemy_rewards": enemy_kill_rewards,
			"tower_costs": tower_costs,
			"building_costs": building_costs
		}
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_currency() -> void:
	"""Load currency from file if it exists"""
	if not FileAccess.file_exists(save_file_path):
		print("No save file found, using default currency")
		return
	
	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if file:
		var save_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(save_string)
		
		if parse_result == OK:
			var save_data = json.data
			current_currency = save_data.get("currency", current_currency)
			currency_multiplier = save_data.get("multiplier", currency_multiplier)
			
			# Load configuration if saved
			if save_data.has("enemy_rewards"):
				enemy_kill_rewards = save_data.enemy_rewards
			if save_data.has("tower_costs"):
				tower_costs = save_data.tower_costs
			if save_data.has("building_costs"):
				building_costs = save_data.building_costs
			
			print("Currency loaded: ", current_currency)
		else:
			print("Failed to parse save file")

func reset_currency(amount: int = 500) -> void:
	"""Reset currency to a specific amount (useful for testing or new games)"""
	current_currency = amount
	currency_changed.emit(current_currency, 0)
	save_currency()
	print("Currency reset to ", amount)

# Debug and testing functions
func add_debug_currency(amount: int = 1000) -> void:
	"""Add currency for testing purposes"""
	add_currency(amount, "debug")

func print_currency_info() -> void:
	"""Print detailed information about the currency system state"""
	print("\n=== CURRENCY SYSTEM INFO ===")
	print("Current Currency: ", current_currency)
	print("Currency Multiplier: ", currency_multiplier)
	print("\nEnemy Kill Rewards:")
	for enemy_type in enemy_kill_rewards:
		print("  ", enemy_type, ": ", enemy_kill_rewards[enemy_type])
	print("\nTower Costs:")
	for tower_type in tower_costs:
		print("  ", tower_type, ": ", tower_costs[tower_type])
	print("============================\n")

# Game phase integration
func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	"""React to game phase changes"""
	match new_phase:
		GameManager.Phase.BUILD:
			# Maybe apply build phase bonuses or reset multipliers
			pass
		GameManager.Phase.FIGHT:
			# Maybe apply combat bonuses
			pass

func reset_currency_to_default() -> void:
	current_currency = 300  # Starting amount
	currency_multiplier = 1.0
	print("Currency reset to default: ", current_currency)
