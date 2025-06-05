extends Control

@onready var currency_container: Control = $CurrencyContainer
@onready var currency_label: Label = $CurrencyContainer/CurrencyLabel
@onready var transaction_log: RichTextLabel = $TransactionLog if has_node("TransactionLog") else null
@onready var affordability_indicator: Control = $AffordabilityIndicator if has_node("AffordabilityIndicator") else null
@onready var change_indicator: Label = $CurrencyContainer/ChangeIndicator if has_node("CurrencyContainer/ChangeIndicator") else null

# Animation and visual feedback
var currency_display_tween: Tween
var flash_tween: Tween

@export var show_change_animation: bool = true
@export var show_transaction_log: bool = false
@export var max_log_entries: int = 10

# Color scheme for different types of currency change
var gain_color: Color = Color.GREEN
var loss_color: Color = Color.RED
var neutral_color: Color = Color.WHITE
var insufficient_funds_color: Color = Color.ORANGE

func _ready() -> void:
	# Connect to global currency manager signals
	if CurrencyManager:
		CurrencyManager.currency_changed.connect(_on_currency_changed)
		CurrencyManager.currency_earned.connect(_on_currency_earned)
		CurrencyManager.currency_spent.connect(_on_currency_spent)
		CurrencyManager.purchase_attempted.connect(_on_purchase_attempted)
		
		# Init display with current currency
		update_currency_display(CurrencyManager.get_current_currency())
	else:
		push_error("CurrencyUI: CurrencyManager not found! Make sure it's added as an AutoLoad.")
	
	# Connect to game phase changes to show/hide during appropriate phases
	if GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
		
		set_ui_visibility(GameManager.instance.is_build_phase())
		
	setup_ui_layout()

func setup_ui_layout() -> void:
	"""Configure the initial layout and styling of the currency UI"""
	# Position the currency display in the top-left corner
	if currency_container:
		currency_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		currency_container.position = Vector2(20, 20)
	
	if currency_label:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0, 0, 0, 0.7)  
		style_box.corner_radius_top_left = 5
		style_box.corner_radius_top_right = 5
		style_box.corner_radius_bottom_left = 5
		style_box.corner_radius_bottom_right = 5
		style_box.content_margin_left = 10
		style_box.content_margin_right = 10
		style_box.content_margin_top = 5
		style_box.content_margin_bottom = 5
		
		currency_label.add_theme_stylebox_override("normal", style_box)
	
	if transaction_log:
		transaction_log.visible = show_transaction_log
		transaction_log.custom_minimum_size = Vector2(250, 150)
		transaction_log.position = Vector2(20, 80)

func update_currency_display(amount: int) -> void:
	"""Update the main currency display with the current amount"""
	if not currency_label:
		return
	
	var formatted_currency = format_currency(amount)
	currency_label.text = "💰 " + formatted_currency
	
	# Update text color based on currency amount
	if amount < 50:  # Low funds warning
		currency_label.modulate = insufficient_funds_color
	elif amount < 100:  # Caution level
		currency_label.modulate = Color.YELLOW
	else:  # Normal level
		currency_label.modulate = neutral_color

func format_currency(amount: int) -> String:
	"""Format currency amount with proper separators for readability"""
	var amount_str = str(amount)
	var formatted = ""
	var length = amount_str.length()
	
	for i in range(length):
		formatted += amount_str[i]
		var remaining = length - i - 1
		if remaining > 0 and remaining % 3 == 0:
			formatted += ","
	
	return formatted + " Credits"

# Signal response functions
func _on_currency_changed(new_amount: int, change_amount: int) -> void:
	"""React to currency changes with visual feedback"""
	update_currency_display(new_amount)
	
	# Show change animation if enabled
	if show_change_animation and change_indicator:
		show_currency_change_animation(change_amount)
	
	# Flash the currency display
	flash_currency_display(change_amount > 0)

func _on_currency_earned(amount: int, source: String) -> void:
	"""React to currency being earned"""
	if transaction_log and show_transaction_log:
		add_transaction_log_entry("+" + str(amount) + " from " + source, gain_color)

func _on_currency_spent(amount: int, item_name: String) -> void:
	"""React to currency being spent"""
	if transaction_log and show_transaction_log:
		add_transaction_log_entry("-" + str(amount) + " for " + item_name, loss_color)

func _on_purchase_attempted(item_name: String, cost: int, success: bool) -> void:
	"""React to purchase attempts, especially failed ones"""
	if not success:
		# Show not enough funds feedback
		show_insufficient_funds_feedback(item_name, cost)
		
		if transaction_log and show_transaction_log:
			add_transaction_log_entry("Failed: " + item_name + " (Need " + str(cost) + ")", insufficient_funds_color)

func show_currency_change_animation(change_amount: int) -> void:
	"""Animate the currency change with a floating text effect"""
	if not change_indicator:
		return
	
	var prefix = "+" if change_amount > 0 else ""
	change_indicator.text = prefix + str(change_amount)
	change_indicator.modulate = gain_color if change_amount > 0 else loss_color
	
	# Position the indicator near the currency display
	change_indicator.position = currency_label.position + Vector2(150, 0)
	change_indicator.visible = true
	
	if currency_display_tween:
		currency_display_tween.kill()
	
	currency_display_tween = create_tween()
	currency_display_tween.set_parallel(true)  # Allow multiple animations simultaneously
	
	currency_display_tween.tween_property(change_indicator, "position:y", change_indicator.position.y - 30, 1.0)
	currency_display_tween.tween_property(change_indicator, "modulate:a", 0.0, 1.0)
	
	# Hide when animation completes
	currency_display_tween.tween_callback(func(): change_indicator.visible = false)

func flash_currency_display(is_gain: bool) -> void:
	"""Flash the currency display to emphasize changes"""
	if not currency_label:
		return
	
	if flash_tween:
		flash_tween.kill()
	
	flash_tween = create_tween()
	
	var flash_color = gain_color if is_gain else loss_color
	var original_color = currency_label.modulate
	
	# Quick flash effect
	flash_tween.tween_property(currency_label, "modulate", flash_color, 0.1)
	flash_tween.tween_property(currency_label, "modulate", original_color, 0.1)

func show_insufficient_funds_feedback(item_name: String, cost: int) -> void:
	"""Show visual feedback when player can't afford something"""
	# Flash the currency display in warning color
	if currency_label and flash_tween:
		flash_tween.kill()
		flash_tween = create_tween()
		flash_tween.tween_property(currency_label, "modulate", insufficient_funds_color, 0.2)
		flash_tween.tween_property(currency_label, "modulate", neutral_color, 0.2)
	
	# Future: could add more feedback here
	print("Insufficient funds: Need ", cost, " for ", item_name)

# Transaction log management
func add_transaction_log_entry(message: String, color: Color) -> void:
	"""Add an entry to the transaction log with color coding"""
	if not transaction_log:
		return
	
	# Add timestamp to the message
	var timestamp = Time.get_time_string_from_system().substr(0, 8)  # HH:MM:SS format
	var color_hex = color.to_html()
	var formatted_message = "[color=" + color_hex + "][" + timestamp + "] " + message + "[/color]"
	
	# Add to log
	transaction_log.append_text(formatted_message + "\n")
	
	# Limit log size
	var lines = transaction_log.get_parsed_text().split("\n")
	if lines.size() > max_log_entries:
		# Remove oldest entries
		var new_text = ""
		for i in range(lines.size() - max_log_entries, lines.size()):
			if i >= 0 and i < lines.size():
				new_text += lines[i] + "\n"
		transaction_log.clear()
		transaction_log.append_text(new_text)
	
	# Auto-scroll to bottom
	transaction_log.scroll_to_line(transaction_log.get_line_count())

# Game phase integration
func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	"""Show/hide the currency UI based on game phase"""
	match new_phase:
		GameManager.Phase.BUILD:
			set_ui_visibility(true)
		GameManager.Phase.FIGHT:
			set_ui_visibility(false)  # Hide during combat

func set_ui_visibility(is_visible: bool) -> void:
	"""Control the visibility of the currency UI"""
	visible = is_visible
	
	# Future: might want to animate the transition
	if is_visible:
		# Fade in animation
		modulate = Color(1, 1, 1, 0)
		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	else:
		# Fade out animation
		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)

# Utility functions for other systems to use
func show_cost_preview(item_name: String, cost: int) -> void:
	"""Show a preview of what an item would cost (useful for hover effects)"""
	if transaction_log and show_transaction_log:
		var can_afford = CurrencyManager.can_afford(cost)
		var color = gain_color if can_afford else insufficient_funds_color
		var status = "✓" if can_afford else "✗"
		add_transaction_log_entry(status + " " + item_name + " costs " + str(cost), color)

func hide_cost_preview() -> void:
	"""Hide cost preview (when no longer hovering over items)"""
	# Could implement temporary message removal here if needed
	pass

# Debug
func toggle_transaction_log() -> void:
	"""Toggle the visibility of the transaction log"""
	show_transaction_log = !show_transaction_log
	if transaction_log:
		transaction_log.visible = show_transaction_log

func clear_transaction_log() -> void:
	"""Clear all entries from the transaction log"""
	if transaction_log:
		transaction_log.clear()
