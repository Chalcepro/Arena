extends Node

func _ready():
	apply_updates("res://data_for_ai/scene_export.json")

func apply_updates(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Update file not found: ", file_path)
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error:
		print("JSON parse error: ", error)
		return
	
	var data = json.data
	if not data.has("updates"):
		return
	
	for update in data["updates"]:
		match update["action"]:
			"create":
				create_node(update)
			"update":
				update_node(update)
			"delete":
				delete_node(update)

func create_node(data: Dictionary):
	var node_type = data["type"]
	var path = data["path"]
	var parent_path = path.get_base_dir()
	var node_name = path.get_file()
	
	# Find parent node
	var parent = get_node_or_null(parent_path)
	if not parent:
		print("Parent not found: ", parent_path)
		return
	
	# Instantiate node of given type
	var new_node = ClassDB.instantiate(node_type)
	if not new_node:
		print("Failed to instantiate type: ", node_type)
		return
	
	new_node.name = node_name
	
	# Set transform if it's Node3D
	if new_node is Node3D:
		if data.has("position"):
			new_node.position = Vector3(data["position"][0], data["position"][1], data["position"][2])
		if data.has("rotation"):
			new_node.rotation = Vector3(data["rotation"][0], data["rotation"][1], data["rotation"][2])
		if data.has("scale"):
			new_node.scale = Vector3(data["scale"][0], data["scale"][1], data["scale"][2])
	
	# Set other properties
	if data.has("properties"):
		for key in data["properties"]:
			new_node.set(key, data["properties"][key])
	
	parent.add_child(new_node)
	new_node.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	print("Created node: ", path)

func update_node(data: Dictionary):
	var path = data["path"]
	var node = get_node_or_null(path)
	if not node:
		print("Node not found: ", path)
		return
	
	if node is Node3D:
		if data.has("position"):
			node.position = Vector3(data["position"][0], data["position"][1], data["position"][2])
		if data.has("rotation"):
			node.rotation = Vector3(data["rotation"][0], data["rotation"][1], data["rotation"][2])
		if data.has("scale"):
			node.scale = Vector3(data["scale"][0], data["scale"][1], data["scale"][2])
	
	if data.has("properties"):
		for key in data["properties"]:
			node.set(key, data["properties"][key])
	print("Updated node: ", path)

func delete_node(data: Dictionary):
	var path = data["path"]
	var node = get_node_or_null(path)
	if node:
		node.queue_free()
		print("Deleted node: ", path)
	else:
		print("Node not found for deletion: ", path)
