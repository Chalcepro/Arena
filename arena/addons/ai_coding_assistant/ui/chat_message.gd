@tool
extends PanelContainer
class_name AIChatMessage

var label: RichTextLabel

func _init(sender: String, content: String):
	# Simple border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.text = "[b]" + sender + ":[/b] " + content
	add_child(label)

func set_content(text: String) -> void:
	label.text = text
