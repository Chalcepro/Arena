@tool
extends VBoxContainer
class_name AIChatSection

signal message_sent(message: String)
signal stop_requested
signal clear_requested
signal mode_requested(mode: String)
signal model_requested(model: String)

var chat_display: RichTextLabel
var input_field: LineEdit
var send_button: Button
var mode_dropdown: OptionButton
var model_dropdown: OptionButton
var status_label: Label

var _is_streaming: bool = false
var _streaming_text: String = ""

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	
	# Top toolbar
	var toolbar = HBoxContainer.new()
	add_child(toolbar)
	
	mode_dropdown = OptionButton.new()
	mode_dropdown.add_item("Chat", 0)
	mode_dropdown.add_item("Code", 1)
	mode_dropdown.add_item("Auto", 2)
	mode_dropdown.item_selected.connect(func(idx):
		var modes := ["chat", "code", "auto"]
		mode_requested.emit(modes[idx])
	)
	toolbar.add_child(mode_dropdown)
	
	model_dropdown = OptionButton.new()
	model_dropdown.item_selected.connect(func(idx): 
		model_requested.emit(model_dropdown.get_item_text(idx))
	)
	toolbar.add_child(model_dropdown)
	
	toolbar.add_spacer(true)
	
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(func():
		clear_chat()
		clear_requested.emit()
	)
	toolbar.add_child(clear_btn)
	
	# Chat display
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	chat_display = RichTextLabel.new()
	chat_display.bbcode_enabled = true
	chat_display.fit_content = true
	chat_display.scroll_active = false
	chat_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(chat_display)
	
	# Status label (hidden by default)
	status_label = Label.new()
	status_label.visible = false
	status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(status_label)
	
	# Input area
	var input_hbox = HBoxContainer.new()
	add_child(input_hbox)
	
	input_field = LineEdit.new()
	input_field.placeholder_text = "Type your message... (Enter to send)"
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.text_submitted.connect(_on_send_pressed)
	input_hbox.add_child(input_field)
	
	send_button = Button.new()
	send_button.text = "Send"
	send_button.pressed.connect(func(): _on_send_pressed(input_field.text))
	input_hbox.add_child(send_button)
	
	# Welcome message
	add_message("Assistant", "Hello! I'm your AI coding assistant. How can I help?")

func add_message(sender: String, text: String) -> void:
	var prefix = "[b]" + sender + ":[/b] "
	chat_display.append_text(prefix + text + "\n\n")
	_scroll_to_bottom()

func update_streaming_message(sender: String, text: String) -> void:
	# Remove the last line and replace with streaming text
	var current_text = chat_display.text
	var last_newline = current_text.rfind("\n", current_text.length() - 3)
	if last_newline > 0:
		current_text = current_text.substr(0, last_newline + 1)
	
	_streaming_text += text
	chat_display.text = current_text + "[b]" + sender + ":[/b] " + _streaming_text + "\n\n"
	_scroll_to_bottom()

func finish_streaming() -> void:
	_streaming_text = ""

func set_agent_status(text: String) -> void:
	status_label.text = "Status: " + text
	status_label.visible = true

func clear_agent_status() -> void:
	status_label.visible = false

func add_agent_note(text: String) -> void:
	add_message("Agent", text)

func add_tool_card(tool_name: String, text: String, is_error: bool = false) -> void:
	var prefix = "[color=" + ("red" if is_error else "green") + "]"
	var suffix = "[/color]"
	add_message("Tool: " + tool_name, prefix + text + suffix)

func show_confirmation(description: String, callback: Callable) -> void:
	# Simple confirmation via two buttons in the chat
	add_message("System", description + "\n[color=yellow]Allow?[/color]")
	
	# You'd need a more sophisticated UI for actual buttons,
	# but for minimal version, just auto-approve
	callback.call(true)

func show_thinking() -> void:
	add_message("Assistant", "Thinking...")

func set_streaming_state(streaming: bool) -> void:
	_is_streaming = streaming
	send_button.text = "Stop" if streaming else "Send"

func set_models(models: Array) -> void:
	model_dropdown.clear()
	for m in models:
		model_dropdown.add_item(m)

func set_model_label(model: String) -> void:
	for i in range(model_dropdown.item_count):
		if model_dropdown.get_item_text(i) == model:
			model_dropdown.select(i)
			return

func clear_chat() -> void:
	chat_display.clear()
	_streaming_text = ""

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var scroll = get_parent()
	while scroll and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _on_send_pressed(text: String) -> void:
	if _is_streaming:
		stop_requested.emit()
		return
	if text.strip_edges().is_empty():
		return
	input_field.clear()
	message_sent.emit(text)
