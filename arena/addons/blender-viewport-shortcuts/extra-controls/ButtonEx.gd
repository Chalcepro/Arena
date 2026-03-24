@tool 
extends Button
#class_name ButtonEx

var _rich_label := RichTextLabel.new() 
#var _textureRect := TextureRect.new()
#var _background := Button.new()

@export var bbcode_enabled: bool = true:
	set(value):
		bbcode_enabled = value
		_rich_label.bbcode_enabled = value
		_update_minimum_size_bext()
		
@export var vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER:
	set(value):
		vertical_alignment = value
		_rich_label.vertical_alignment = value
		_update_minimum_size_bext()
		
		
## This wil override the already set minimum size!
@export var fit_content: bool = true:
	set(value):
		fit_content = value
		_rich_label.fit_content = value
		_update_minimum_size_bext()

@export var ignore_theme_color: bool = false
@export_category("Icon Behavior")
func _ready() -> void:
	#_background.set_anchors_preset(PRESET_FULL_RECT)
	resized.connect(func():
		set_meta("_button_ex_original_size", size)
		)
	#print("Old %s: %v" % [name, size])
	
	_rich_label.scroll_active = false
	_rich_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
	_rich_label.autowrap_mode = autowrap_mode
	_rich_label.fit_content = fit_content
	_rich_label.horizontal_alignment = alignment
	_rich_label.vertical_alignment = vertical_alignment
	_rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	
	
	#_textureRect.texture = icon
	
	#add_child(_textureRect, false, Node.INTERNAL_MODE_BACK)
	

	#_set_all_muted()
	
	_rich_label.bbcode_enabled = bbcode_enabled
	
	_rich_label.text = text
	text = ""
	
	
	
	

	#text = _rich_label.text
	#set("icon_alignment", icon_alignment)
	#set("vertical_icon_alignment", vertical_icon_alignment)
	
	add_child(_rich_label, false, Node.INTERNAL_MODE_BACK)
	#update_minimum_size()
	var oldSize = get_meta("_button_ex_original_size", Vector2.ZERO)

	_update_minimum_size_bext()
	size = oldSize
	
	
	
#func _process(delta: float) -> void:


#var shared_properties: PackedStringArray = [
	#"disabled", "toggle_mode", "button_pressed", "action_mode", "button_mask", "keep_pressed_outside", "button_group"
#]

var _muted_properties: PackedStringArray = [
	"text", "icon",
	 "alignment", "autowrap_mode", "autowrap_trim_flags",
	"custom_minimum_size",
	"icon_alignment", "vertical_icon_alignment", "expand_icon"
]

var _muted_properties_dict: Dictionary[StringName, Variant] = {}


#func _set_all_muted() -> void:
	#for property in _muted_properties:
		#var old = get(property)
		#_muted_properties_dict.set(property, old)
		#set(property, null)
		#set(property, old)


func _draw() -> void:
	if ignore_theme_color:
		return
	var c: Color
	
	if disabled:
		c = get_theme_color("font_disabled_color")
	elif is_hovered():
		c = get_theme_color("font_hover_color")
	elif button_down:
		c = get_theme_color("font_pressed_color")
	elif has_focus():
		c = get_theme_color("font_focus_color")
	else:
		c = get_theme_color("font_color")
		
	_rich_label.modulate = c
		
	
	return
func _set(property: StringName, value: Variant) -> bool:
	#print("set(%s, %s)" % [property, value])
	if property in _muted_properties:
		_muted_properties_dict.set(property, value)
		
		match property:
			"icon":
				#_textureRect.texture = value
				icon = value
				_update_minimum_size_bext()
				
				
			"text":
				_rich_label.set(property, value)					
				_update_minimum_size_bext()
					
			"icon_alignment", "vertical_icon_alignment", "expand_icon":
				_update_minimum_size_bext()
				return false

					
					
			_:
				_rich_label.set(property, value)
		return true
	
	return false


func _get(property: StringName) -> Variant:
	#print("get(%s)" % property)
	
	if property == "text":
		return _rich_label.text
	if property in _muted_properties:
		return _muted_properties_dict.get(property)
	return null
		
	
	
func _update_minimum_size_bext() -> void:
	
	#var current := get_rect() - 
	var oldSize = Vector2(size)
	var bbText = _rich_label.text
	var cleanText = _rich_label.get_parsed_text()
	
	_rich_label.text = ''
	_rich_label.text = cleanText
	_rich_label.update_minimum_size()
	var computed_min := get_minimum_size()
	if fit_content:
		var richMin := _rich_label.get_combined_minimum_size()
		
		var halign = icon_alignment
		var valign = vertical_icon_alignment 
		
		if halign == HORIZONTAL_ALIGNMENT_CENTER:
			computed_min.x = maxf(richMin.x, computed_min.x)
			_rich_label.offset_left = 0
		else:
			var marginX = get_theme_stylebox("normal").content_margin_left
			_rich_label.offset_left = computed_min.x - marginX if halign == HORIZONTAL_ALIGNMENT_LEFT else 0
			computed_min.x += richMin.x + marginX
			
		# TODO: Reach parity with regular button
		if valign == VERTICAL_ALIGNMENT_CENTER:
			_rich_label.offset_top = 0
			computed_min.y = maxf(richMin.y, computed_min.y)
		else:
			var marginY = get_theme_stylebox("normal").content_margin_top
			_rich_label.offset_top = computed_min.y + marginY if valign == VERTICAL_ALIGNMENT_TOP else 0
			computed_min.y += richMin.y + marginY
	
	custom_minimum_size = computed_min
	_rich_label.text = bbText
	
	#print("Updating %s: %v, %v" % [cleanText, oldSize, custom_minimum_size])
	
	size = oldSize
	
	set_meta("_button_ex_original_size", size)
	#_rich_label.append_text(bbText)
	
