extends Control   # or TouchScreenButton, etc.
#
#@export var player_path : NodePath = $"../../../.." # adjust to your scene tree
#var player : CharacterBody3D
#var touch_look_sensitivity = 0.005
#var drag_touch_index = -1
#
#func _ready():
	#player = get_node(player_path)
	#if not player:
		#printerr("Look script: player not found!")
#
#func _input(event):
	#if not player:
		#return
#
	#if event is InputEventScreenTouch and event.pressed:
		## Check if touch is inside this control's area (the look area)
		#if get_global_rect().has_point(event.position):
			#drag_touch_index = event.index
	#elif event is InputEventScreenTouch and not event.pressed and event.index == drag_touch_index:
		#drag_touch_index = -1
	#elif event is InputEventScreenDrag and event.index == drag_touch_index:
		#player.head.rotate_y(-event.relative.x * touch_look_sensitivity)
		#player.camera.rotate_x(-event.relative.y * touch_look_sensitivity)
		#player.camera.rotation.x = clamp(player.camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
