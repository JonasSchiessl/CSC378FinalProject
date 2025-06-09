extends Control

@export var animation_duration := 0.3

# Panel references
@onready var settings_panel = $Settings  
@onready var credits_panel = $Credits   

# Overlay references
@onready var settings_overlay = $SettingsOverlay
@onready var credits_overlay = $CreditsOverlay
@onready var heart_monitor = $AnimatedSprite2D

# Store original panel states
var settings_original_pos: Vector2
var settings_original_size: Vector2
var credits_original_pos: Vector2
var credits_original_size: Vector2

var screen_size: Vector2
var current_expanded_panel = null

func _ready():
	heart_monitor.play("default")
	screen_size = get_viewport().get_visible_rect().size
	
	# Store original panel transforms
	if settings_panel:
		settings_original_pos = settings_panel.position
		settings_original_size = settings_panel.size
	
	if credits_panel:
		credits_original_pos = credits_panel.position
		credits_original_size = credits_panel.size
	
	# Initially hide overlays
	if settings_overlay:
		settings_overlay.visible = false
		settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if credits_overlay:
		credits_overlay.visible = false
		credits_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	setup_overlay_connections()

func setup_overlay_connections():
	# Connect back buttons in overlays
	if settings_overlay:
		var back_button = settings_overlay.get_node_or_null("SettingsContent/BackButton")
		if back_button:
			back_button.pressed.connect(_on_settings_back)
	
	if credits_overlay:
		var back_button = credits_overlay.get_node_or_null("CreditsContent/BackButton")
		if back_button:
			back_button.pressed.connect(_on_credits_back)

func on_start_button_is_pressed() -> void:
	$Select.play()
	get_tree().change_scene_to_file("res://Scenes/Levels/Level.tscn")

func on_settings_button_is_pressed() -> void:
	$Select.play()
	if current_expanded_panel == settings_panel:
		# Already expanded settings, close it
		close_current_panel()
	else:
		# Close any other expanded panel first
		if current_expanded_panel:
			close_current_panel()
			await get_tree().create_timer(animation_duration).timeout
		
		# Expand settings panel
		expand_panel_to_fullscreen(settings_panel, "settings")

func on_credits_button_is_pressed() -> void:
	$Select.play()
	if current_expanded_panel == credits_panel:
		# Already expanded credits, close it
		close_current_panel()
	else:
		# Close any other expanded panel first
		if current_expanded_panel:
			close_current_panel()
			await get_tree().create_timer(animation_duration).timeout
		
		# Expand credits panel
		expand_panel_to_fullscreen(credits_panel, "credits")

func expand_panel_to_fullscreen(panel: Control, panel_type: String):
	if not panel:
		return
	
	current_expanded_panel = panel
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Bring panel to front
	panel.z_index = 10
	
	# Animate to fullscreen
	tween.tween_property(panel, "position", Vector2.ZERO, animation_duration)
	tween.tween_property(panel, "size", screen_size, animation_duration)
	
	# Show overlay after panel animation completes
	tween.tween_callback(show_overlay.bind(panel_type)).set_delay(animation_duration)

func close_current_panel():
	$Select.play()
	if not current_expanded_panel:
		return
	
	var panel = current_expanded_panel
	var panel_type = "settings" if panel == settings_panel else "credits"
	
	# Hide overlay first
	hide_overlay(panel_type)
	
	# Wait for overlay to fade out, then animate panel back
	await get_tree().create_timer(animation_duration).timeout
	
	# Get original position and size
	var original_pos = settings_original_pos if panel == settings_panel else credits_original_pos
	var original_size = settings_original_size if panel == settings_panel else credits_original_size
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate back to original size and position
	tween.tween_property(panel, "position", original_pos, animation_duration)
	tween.tween_property(panel, "size", original_size, animation_duration)
	
	# Reset z-index after animation
	tween.tween_callback(func(): panel.z_index = 0).set_delay(animation_duration)
	
	current_expanded_panel = null

func show_overlay(panel_type: String):
	var overlay = settings_overlay if panel_type == "settings" else credits_overlay
	
	if not overlay:
		return
	
	overlay.visible = true
	overlay.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, animation_duration * 0.5)

func hide_overlay(panel_type: String):
	var overlay = settings_overlay if panel_type == "settings" else credits_overlay
	
	if not overlay or not overlay.visible:
		return
	
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, animation_duration * 0.5)
	tween.tween_callback(func(): overlay.visible = false).set_delay(animation_duration * 0.5)

func _on_settings_back():
	close_current_panel()

func _on_credits_back():
	close_current_panel()

# Handle window resize
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		screen_size = get_viewport().get_visible_rect().size
		
		# If a panel is currently fullscreen, update its size
		if current_expanded_panel:
			current_expanded_panel.size = screen_size

# Optional: ESC key support
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if current_expanded_panel:
			close_current_panel()
