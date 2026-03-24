extends Node3D

@export var export_on_ready := true          # auto-export when scene loads
@export var export_path := "res://data_for_ai/scene_export.json"
@export var include_non_spatial := false     # include non-3D nodes?

func _ready():
	if export_on_ready and Engine.is_editor_hint():
		export_scene()

func export_scene():
	var data = {}
	var root = get_tree().current_scene
	data["scene_root"] = root.name
	data["nodes"] = _collect_node_data(root)
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(data, "\t")
		file.store_string(json)
		file.close()
		print("Exported scene data to: ", export_path)
	else:
		print("Failed to open file for writing: ", export_path)

func _collect_node_data(node: Node) -> Array:
	var nodes_array = []
	for child in node.get_children():
		var node_data = {}
		node_data["name"] = child.name
		node_data["type"] = child.get_class()
		
		# Collect transform info if it's a Node3D
		if child is Node3D:
			node_data["position"] = [child.position.x, child.position.y, child.position.z]
			node_data["rotation"] = [child.rotation.x, child.rotation.y, child.rotation.z]
			node_data["scale"] = [child.scale.x, child.scale.y, child.scale.z]
		
		# Add custom properties if you like
		# (e.g., export specific variables from scripts)
		# node_data["custom"] = get_custom_properties(child)
		
		# Recursively collect children
		if child.get_child_count() > 0:
			node_data["children"] = _collect_node_data(child)
		nodes_array.append(node_data)
	return nodes_array

# Optional: export variables from a script attached to the node
func get_custom_properties(node: Node) -> Dictionary:
	var props = {}
	if node.get_script():
		var script = node.get_script()
		var script_props = script.get_script_property_list()
		for prop in script_props:
			if prop.name.begins_with("_") or prop.name in ["script"]:
				continue
			props[prop.name] = node.get(prop.name)
	return props
