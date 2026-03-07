@tool
extends VBoxContainer
class_name AISettingsSection

signal provider_changed(provider: String)
signal model_changed(model: String)
signal api_key_changed(key: String)
signal context_changed(context: String)
signal settings_cleared  # ADD THIS SIGNAL

var provider_option: OptionButton
var model_field: LineEdit
var api_key_field: LineEdit
var context_field: TextEdit
var status_label: Label

func _ready():
	_setup_ui()

func _setup_ui():
	add_theme_constant_override("separation", 8)
	
	# Provider
	var provider_label = Label.new()
	provider_label.text = "Provider:"
	add_child(provider_label)
	
	provider_option = OptionButton.new()
	provider_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	provider_option.item_selected.connect(_on_provider_selected)
	add_child(provider_option)
	
	# Model
	var model_label = Label.new()
	model_label.text = "Model:"
	add_child(model_label)
	
	model_field = LineEdit.new()
	model_field.placeholder_text = "model name"
	model_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_field.text_changed.connect(func(t): model_changed.emit(t))
	add_child(model_field)
	
	# API Key
	var key_label = Label.new()
	key_label.text = "API Key:"
	add_child(key_label)
	
	api_key_field = LineEdit.new()
	api_key_field.placeholder_text = "optional for local models"
	api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_key_field.text_changed.connect(func(t): api_key_changed.emit(t))
	add_child(api_key_field)
	
	# Context
	var ctx_label = Label.new()
	ctx_label.text = "Global Context:"
	add_child(ctx_label)
	
	context_field = TextEdit.new()
	context_field.placeholder_text = "System prompt / context"
	context_field.custom_minimum_size = Vector2(0, 60)
	context_field.text_changed.connect(func(): context_changed.emit(context_field.text))
	add_child(context_field)
	
	# Settings location button
	var path_btn = Button.new()
	path_btn.text = "Show Settings File"
	path_btn.flat = true
	path_btn.pressed.connect(_show_settings_path)
	add_child(path_btn)
	
	# Clear button
	var clear_btn = Button.new()
	clear_btn.text = "Reset to Defaults"
	clear_btn.pressed.connect(_on_clear_pressed)
	add_child(clear_btn)
	
	# Status label (hidden)
	status_label = Label.new()
	status_label.visible = false
	status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(status_label)

func setup_providers(providers: Array):
	provider_option.clear()
	for p in providers:
		provider_option.add_item(p.capitalize())

func set_model(model: String):
	model_field.text = model

func set_api_key(key: String):
	api_key_field.text = key

func set_global_context(text: String):
	context_field.text = text

func _on_provider_selected(index: int):
	provider_changed.emit(provider_option.get_item_text(index).to_lower())

func _on_clear_pressed():
	settings_cleared.emit()
	status_label.text = "Settings reset"
	status_label.visible = true
	await get_tree().create_timer(2.0).timeout
	status_label.visible = false

func _show_settings_path():
	var path = ProjectSettings.globalize_path("user://ai_assistant_settings.cfg")
	status_label.text = "Settings: " + path
	status_label.visible = true
	DisplayServer.clipboard_set(path)
	await get_tree().create_timer(3.0).timeout
	status_label.visible = false
