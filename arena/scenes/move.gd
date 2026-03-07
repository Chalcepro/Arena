extends TextureRect
#
#var joystick_base : TextureRect
#var initial_handle_pos : Vector2
#var touch_index : int = -1
#var output_vector : Vector2 = Vector2.ZERO
#
#signal joystick_moved(vector : Vector2)
#signal joystick_released()
#
#func _ready():
	#joystick_base = get_parent()  # assuming base is the parent
	#initial_handle_pos = position
#
#func _input(event):
	#if event is InputEventScreenTouch and event.pressed:
		## Check if touch is inside the base area (you can also use a larger area)
		#if Rect2(joystick_base.position, joystick_base.size).has_point(event.position):
			#touch_index = event.index
			#_update_handle(event.position)
	#elif event is InputEventScreenTouch and not event.pressed and event.index == touch_index:
		## Finger lifted
		#touch_index = -1
		#position = initial_handle_pos
		#output_vector = Vector2.ZERO
		#emit_signal("joystick_released")
	#elif event is InputEventScreenDrag and event.index == touch_index:
		#_update_handle(event.position)
#
#func _update_handle(touch_pos : Vector2):
	## Convert touch position to local coordinates inside the base
	#var local_pos = joystick_base.get_local_mouse_position()  # careful: this uses mouse, not touch
	## Better: use event.position relative to base's global position
	#var base_center = joystick_base.global_position + joystick_base.size * 0.5
	#var offset = (touch_pos - base_center).limit_length(joystick_base.size.x * 0.5)
	#position = offset + joystick_base.size * 0.5 - size * 0.5  # keep handle centered on offset
	#output_vector = offset / (joystick_base.size.x * 0.5)  # normalize to -1..1
	#emit_signal("joystick_moved", output_vector)
