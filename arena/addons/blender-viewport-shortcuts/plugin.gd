@tool
extends EditorPlugin
class_name BlenderViewportShortcuts
#const CameraPopupGizmo = preload("uid://b3ydhi041uwsa")
const CAMERA_POPUP = preload("uid://tmpnkcdmbogo")

#var shortcut: Shortcut
var currentPopup: Control
static var _shown_warning: bool = false
static var _perspective_buttons: Dictionary[int, MenuButton] = {}


const  PLUGIN_NAME = "blender-viewport-shortcuts"
func _enable_plugin() -> void:
	# Add autoloads here.
	EditorInterface.set_plugin_enabled(PLUGIN_NAME + "/extra-controls", true)
	main_screen_changed.connect(on_screen_changed)
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	EditorInterface.set_plugin_enabled(PLUGIN_NAME + "/extra-controls", false)
	
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	#print("Camera entered")
	currentPopup = CAMERA_POPUP.instantiate()
	currentPopup.set_meta("start_hidden", true)
	#EditorInterface.get_editor_main_screen().print_tree_pretty()
			#EditorInterface.set_main_screen_editor("3D")
			
	#print(EditorInterface.get_editor_main_screen().get_parent().name)
	
	
	# TODO: How do i know if the 3d tab specifically is selected???
	var mainScreen := EditorInterface.get_editor_main_screen()
	var screenIndex = mainScreen.get_children().find_custom(func(n: Node): return n.is_class("Node3DEditor"))
	mainScreen.get_child(screenIndex).add_child(currentPopup)
	
	
	
	#add_node_3d_gizmo_plugin(gizmo_plugin)
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	#remove_node_3d_gizmo_plugin(gizmo_plugin)
	currentPopup.queue_free()
	_shown_warning = false
	_perspective_buttons.clear()
	#shortcut = null
	#print("Camera exited")
	pass
	

func on_screen_changed(screen_name: String) -> void:
	#if currentPopup.get_parent():
		#currentPopup.get_parent().remove_child(currentPopup)
		#
	if screen_name == "3D":
		currentPopup.hide()
		#var control := EditorInterface.get_editor_main_screen()
		#control.add_child(currentPopup)
		#
	pass

## Gets a viewport if its visible. If viewport is unset, then the visible viewport returned will be the one that has the mouse inside of it.
static func get_visible_viewport_id(viewport: int = -1) -> int:
	var res: SubViewport
	#if viewport is not 0,4 then get the viewport based off the mouse position.
	# If its outside of any, then returns -1.
	if viewport in range(4):
		var v: Control = EditorInterface.get_editor_viewport_3d(viewport).get_parent()
		if !v.visible:
			return -1

		return viewport
		
	var found: bool = false
	for i in range(4):
		var v: Control = EditorInterface.get_editor_viewport_3d(i).get_parent()
		if !v.visible:
			#print("Skipping %d" % i)
			continue
			
		if v.get_rect().has_point(v.get_local_mouse_position()):
			#print("found")
			viewport = i
			found = true
			#print("found: ", v.get_rect(), v.get_local_mouse_position())
			break
	
	if not found:
		#push_error("(%s) Couldn't find suitable viewport!" % BlenderViewportShortcuts.PLUGIN_NAME )
		viewport = -1


	return viewport
	
	
static func get_visible_viewport(viewport: int = -1) -> SubViewport:
	viewport = get_visible_viewport_id(viewport)
	if viewport < 0:
		return null
	
	return EditorInterface.get_editor_viewport_3d(viewport)
	
	
static func get_editor_perspective_menu(viewport: int = -1) -> MenuButton:
	var e := EditorInterface.get_editor_main_screen()
	
	

		
	
	# Dont do anything if its not visible!
	viewport = get_visible_viewport_id(viewport)
	if viewport < 0:
		return null
		
	# Check if the menubutton is cached.
	if _perspective_buttons.has(viewport):
		return _perspective_buttons.get(viewport)
	
	#print("Caching!")
	
	# If everything fails, scan for the menu button that contains the perspectives.
	# This caches all perspective buttons and should only be reached once.
	for i in range(4):
		var subviewport = EditorInterface.get_editor_viewport_3d(i)
		if not subviewport.get_parent().visible:
			continue
			
		
		
		
		var editorViewport = subviewport.get_node_or_null("../../")
		
		var control = editorViewport.get_child(1)
		
		
		var button: MenuButton
		var controlIndex = 0
		var searchedNode: Node = control.get_child(0)
		#control.print_tree_pretty()
		#print("###lopo start###")
		while !button and controlIndex < control.get_child_count():
			#print(searchedNode.name)
			if searchedNode is MenuButton:
				#print("found a menu button")
				if searchedNode.item_count == 39:
					#print("Found!")
					button = searchedNode
					break
				else:
					push_error("The menu button for viewport %d is not 39 items long and the plugin wont do anything on it. Updated required!" % i)
					break
					

			if !searchedNode or searchedNode.get_child_count() < 1:
				#print("reached end!")
				controlIndex += 1
				searchedNode = control.get_child(controlIndex)
				#print(control.get_child_count())
			
			else:
				#print("next child")
				searchedNode = searchedNode.get_child(0)
					
		
		_perspective_buttons.set(i, button)
				
		#print("%s: %s / %s" % [button.name, button.text, button.get("accessibility_name")])
		
		#control.print_tree_pretty()
		
		
	

	var button: MenuButton = _perspective_buttons.get(viewport)
	if !button:
		return null
		
	
	return button



static func findRecursive(root_node: Node, found_node3deditorviewportcontainer: bool = false) -> Node:
	for child in root_node.get_children():
		var s = child.name
		#if child.get("text"):
			#s = "%s → %s" % [child.name, child.text]

		#print(s)
		
		if child is MenuButton:
			var items: Array = []
			#items.append(child.get_item_id(0))
			#for i in child.item_count:
			#print("%s: %s / %s" % [child.name, child.text, child.accessibility_name])
			
		if child.is_class("Node3DEditorViewportContainer"):
			#print(child)
			for v in child.get_children():
				pass
				
			return findRecursive(child, true)
			
		var n := findRecursive(child)
		if n:
			return n

	return null
	# first run:
	# /root/@EditorNode@18057/@Panel@14/@VBoxContainer@15/DockHSplitMain/@VBoxContainer@28/DockVSplitCenter/@VSplitContainer@70/@VBoxContainer@71/@EditorMainScreen@125/MainScreen/@Node3DEditor@9983/@HSplitContainer@9388/@HSplitContainer@9390/@VSplitContainer@9392/@Node3DEditorViewportContainer@9393/@Node3DEditorViewport@9448/@Control@9396/@VBoxContainer@9398/@HBoxContainer@9399/@MenuButton@9408/@PopupMenu@9407
