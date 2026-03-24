@tool
extends Container
#class_name RadialMenu

const CIRCLE_DISPLAY = preload("uid://daakih3wx58yk")
const SELECTION = preload("uid://0ylgmieg23y5")
const SELECTION_OVERLAY = preload("uid://doj6lv8q4vgwn")

@export var shortcut := Shortcut.new()
@onready var _label: Label = Label.new()
@onready var _circle_display: Control = CIRCLE_DISPLAY.instantiate()

@export var text: String = "":
	set(value):
		text = value
		if _label:
			_label.text = value

enum RadialSizing {
	BORDER,
	INNER,
}

@export var expand_mode: RadialSizing = RadialSizing.INNER:
	set(value):
		expand_mode = value
		queue_sort()

@export var min_mouse_movement: float = 64
var _current_progress: float = 1.0

var is_selecting: bool = false
var _focus_button := Button.new()

func _ready() -> void:
	#resized.connect(_on_size_changed)
	#print(_circle_display)
	
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	#_focus_button.visible = false
	_focus_button.modulate = Color.TRANSPARENT
	add_child(_label, false, Node.INTERNAL_MODE_BACK)
	add_child(_focus_button, false, Node.INTERNAL_MODE_BACK)
	add_child(_circle_display, false, Node.INTERNAL_MODE_BACK)
	
	if !_circle_display.get("pivot_offset_ratio"):
		_circle_display.pivot_offset = _circle_display.size/2
		for c in _circle_display.get_children():
			c.pivot_offset = c.size/2
		

	
	#arrange()
	

func _on_size_changed() -> void:
	arrange()
#func _process(delta: float) -> void:
	#if is_selecting:
		#select_loop()
		
		
func select_loop() -> void:
	var mouseOffset := (get_global_mouse_position() - (get_global_rect().get_center()))
	
	var children = get_children().filter(func(n): return n is not ReferenceRect)
	var count: int = children.size()
	var angle: float = mouseOffset.angle()
	#print(children)
	var snappedAngle: int = (roundi((((angle) / PI) + 1) * count/2) + ceil(count/2)) % count
	
	#snappedAngle = (roundi(snappedAngle) + ceil(count/2)) % count
	
	#_label.text = str("%d" % (snappedAngle))
	var circleTexture: Texture2D
	if mouseOffset.length() > min_mouse_movement / 2:
		circleTexture = SELECTION_OVERLAY
		var btnIndex: int = (snappedAngle + ceil(count/4)) % count
		focusedButton = children.get(btnIndex)
		focusedButton.grab_focus.call_deferred(focusedButton.disabled)
		
		
		
	else:
		circleTexture = SELECTION
		if focusedButton:
			#focusedButton.release_focus()
			_focus_button.grab_focus.call_deferred(false)
			focusedButton = null
		
	
	update_circle_color()
	#print(_circle_display)
	#if _circle_display:
	#_circle_display.texture = circleTexture
	_circle_display.get_node("TextureRectSelector").rotation = angle
		

func arrange(progress: float = 1.0) -> void:
	#var parent = get_parent()
	#if parent is Control:
	#position = get_rect().size/2
		

	var i: int = 0
	var popup_box = Rect2(Vector2.ZERO, size)
	var pos := Vector2.UP
	
	var children := get_children().filter(func(n): return n is not ReferenceRect and n is Control)
	var count: int = children.size()
	
	var refChilds: Array[Node] = get_children().filter(func(n): return n is ReferenceRect)
	for ref in refChilds:
		ref.size = size
		ref.position = Vector2.ZERO
		
		
	var center: Vector2 = (popup_box.size/2)
	
	
#	First pass. Get the maximum scalar.


		
		
		
	
	for child: Control in children:
		var angle: float = 2*PI * i/count
		
		var child_box := child.get_rect()
		
		#var boxhalf := box.size / 2k
		
		var furthest_point := child_box.size/2
		
		
		var finalPos: Vector2 = (-furthest_point + (pos.rotated(angle) * center)) + center
		var finalRect: Rect2 = Rect2(finalPos, child_box.size)
		# print(finalRect)
		if expand_mode == RadialSizing.INNER:
			var oldFinal = Rect2(finalRect)
			if !popup_box.encloses(finalRect):
				var childRect: RectHelper = RectHelper.new(finalRect)
				var contRect: RectHelper = RectHelper.new(popup_box)
				# print("-%v | %v-" % [childRect.borders(), popup_box.size])
				if childRect.right() > popup_box.size.x:
					finalRect.position.x -= childRect.right() - popup_box.size.x
					# print("over!")
				elif childRect.left() < 0:
					finalRect.position.x += 0 - childRect.left()

				if childRect.bottom() > popup_box.size.y:
					finalRect.position.y -= childRect.bottom() - popup_box.size.y
				elif childRect.top() < 0:
					finalRect.position.y += 0 - childRect.top()
			# else:
				# print("fits")
		# print(finalRect)
		
		finalRect.position = (center - furthest_point).lerp(finalRect.position, progress)
		fit_child_in_rect(child, finalRect)
		# await get_tree().create_timer(0.2).timeout
			
		#child.position = -furthest_point + pos.rotated(angle) * popup_box.size/2
		
		
		#print("--\nsize: %v\ncalc: %v\nfurthest: %v" % [box.size, Vector2(adj, opu), furthest_point])
		
		
		#child.get_rect().has_point()
		i += 1
		#child.position
		
		pass
	
	if _circle_display:
		var selector: TextureRect = _circle_display.get_node("TextureRectSelector")
		

		fit_child_in_rect(_circle_display, Rect2(popup_box.size/2 - _circle_display.size/2, _circle_display.size))
		fit_child_in_rect(_label, Rect2(
				(_circle_display.position + _circle_display.size/2).x - _label.size.x / 2, 
				_circle_display.position.y - _label.size.y,
				_label.size.x,
				_label.size.y
				)
		)
		
		selector.rotation = (get_global_mouse_position() - (get_global_rect().get_center())).angle()
			

func update_circle_color() -> void:
	var circleTexture: TextureRect = _circle_display.get_node("TextureRect")
	var bg_col: Color
	
	var style = get_theme_stylebox("normal", "Button")
	if style is StyleBoxFlat:
		bg_col = style.bg_color
	circleTexture.modulate = bg_col
		
	
	var selector: TextureRect = _circle_display.get_node("TextureRectSelector")
	var focus_col: Color = Color.TRANSPARENT
	
	if focusedButton:
		var col_string: String = "icon_disabled_color" if (focusedButton.disabled) else "icon_pressed_color"
		focus_col = get_theme_color(col_string, "Button")
	
	selector.modulate = focus_col 
	#print(style, bg_col)

func _editor_arrange_pressed() -> void:
	arrange()
	
@export_tool_button("Arrange") var h = _editor_arrange_pressed


var focusedButton: Button


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		arrange(1.0)
		

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_selecting:
		select_loop()

func _shortcut_input(event: InputEvent) -> void:
	#print(event)
	if shortcut.matches_event(event) and not event.is_echo():
		
		if is_selecting and not event.is_pressed() and focusedButton:
			focusedButton.pressed.emit()
			
			
		is_selecting = event.is_pressed()
		
		if is_selecting:
			focusedButton = null
			#_circle_display.texture = SELECTION
			_focus_button.grab_focus.call_deferred(true)

		
	
	


	
	#elif event is InputEventMouseMotion:
		#queue_redraw()
		
	
	#print("Doing")
	#EditorInterface.get_base_control()
	
