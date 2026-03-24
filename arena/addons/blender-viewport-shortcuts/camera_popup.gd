@tool
extends "res://addons/blender-viewport-shortcuts/extra-controls/radial_menu.gd"

# Set this to 0 to disable the animation.
@export var animation_length: float = 0.5;

var anim_time: float = 0.0
func _ready() -> void:
	# Hides only on the plugin's initialization and not on the scene editor
	if get_meta("start_hidden", false):
		visible = false
		
	super._ready()

func _physics_process(delta: float) -> void:
	if animation_length <= 0 or anim_time >= animation_length:
		return
		
	if anim_time <= animation_length:
		anim_time = clampf(anim_time + delta, 0.0, animation_length)
		arrange(ease(anim_time / animation_length, 0.2))

var _menu_button: MenuButton
var _viewport: int = -1
func _shortcut_input(event: InputEvent) -> void:
	
	if !shortcut.matches_event(event) or event.is_echo() or Input.get_mouse_button_mask() != 0:
		return
		
		
	_viewport = BlenderViewportShortcuts.get_visible_viewport_id()
	
	# Pressing and inside any viewport
	if _viewport != -1 and event.is_pressed():
		super._shortcut_input(event)
		global_position = get_global_mouse_position() - (get_rect().size / 2)
		

		# Ensure it's inside the editor window
		var margin: int = 8
		var rect := Rect2(global_position, size).grow(margin)
		var windowRect := Rect2(Vector2.ZERO, EditorInterface.get_editor_main_screen().get_window().size)
		if not windowRect.encloses(rect):
			if rect.position.x < 0:
				global_position.x = margin
			elif rect.position.x + rect.size.x > windowRect.size.x:
				global_position.x = windowRect.size.x - rect.size.x
			if rect.position.y < 0:
				global_position.y = margin
			elif rect.position.y + rect.size.y > windowRect.size.y:
				global_position.y = windowRect.size.y - rect.size.y
			
			
		visible = is_selecting
		_viewport = BlenderViewportShortcuts.get_visible_viewport_id()
		_menu_button = BlenderViewportShortcuts.get_editor_perspective_menu(_viewport)
		
		
		$btnCamera.disabled = not (EditorInterface.get_edited_scene_root() and EditorInterface.get_edited_scene_root().get_viewport().get_camera_3d())
		$btnSelected.disabled = EditorInterface.get_selection().get_selected_nodes().filter(func(n: Node): return n is Node3D).is_empty()
		set_physics_process(true)
		select_loop()
		
		
	# Releasing
	elif is_selecting and visible:
		super._shortcut_input(event)
		hide()
	
	else:
		is_selecting = false
	
	
func _notification(what: int) -> void:
	
	match what: 
		NOTIFICATION_VISIBILITY_CHANGED:
			anim_time = 0 if visible else animation_length
			set_physics_process(visible)
			
		
		NOTIFICATION_SORT_CHILDREN:
			if get_meta("start_hidden", false):
				arrange(0.0)
			

func _editor_arrange_pressed() -> void:
	anim_time = 0
	set_physics_process(true)
	arrange(0.0)
	

func arrange(progress: float = 1.0) -> void:
	super.arrange(progress)
	$MouseAreaMargin.global_position = Vector2.ZERO
	$MouseAreaMargin.size = get_window().size
	

func hide() -> void:
	is_selecting = false
	visible = false
	
#func show() -> void:
	#visible = true


func _on_perspective_button_pressed(item_id: int) -> void:
	#print(item_id)
	hide()
	if !_menu_button:
		#push_error("(%s) EDITOR MENU COULDNT BE FOUND! PLUGIN NEEDS UPDATING" % BlenderViewportShortcuts.PLUGIN_NAME )
		return
	
	#print(item_id)
	var cam_check: Node = _menu_button.get_node("../../").get_child(1)
	if cam_check is CheckBox and cam_check.visible:
		cam_check.button_pressed = false
	_menu_button.get_popup().id_pressed.emit(item_id)
	


func _on_btn_camera_pressed() -> void:
	hide()
	if !_menu_button or !EditorInterface.get_edited_scene_root():
		return
		
	var cam_check: Node = _menu_button.get_node("../../").get_child(1)
	
	
	# If a camera is selected, then preview it.
	if cam_check is CheckBox and cam_check.visible:
		var ch := cam_check as CheckBox
		ch.button_pressed = !ch.button_pressed
		
	else:
		var active_cam = EditorInterface.get_edited_scene_root().get_viewport().get_camera_3d()
		if !active_cam:
			return
			
		# Keeps the selected nodes if you do a quick look at the active camera and go back.
		var old_selected = EditorInterface.get_selection().get_selected_nodes()
		var selection := EditorInterface.get_selection()
		EditorInterface.edit_node(active_cam)
		cam_check.button_pressed = !cam_check.button_pressed
		selection.clear()
		for n in old_selected:
			EditorInterface.get_selection().add_node(n)
