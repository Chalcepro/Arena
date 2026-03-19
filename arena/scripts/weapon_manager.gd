extends Node

@export var starting_weapon: WeaponData
@export var weapon_slot_count := 2
@export var gun_node: Node3D

var weapons: Array[WeaponData] = []
var current_weapon_index := 0
var current_weapon_node: Node3D = null

signal weapon_switched(weapon_index: int)
signal weapon_pickup_failed(reason: String)

func _ready():
	current_weapon_node = gun_node
	if current_weapon_node and starting_weapon:
		if current_weapon_node.has_method("set_weapon_data"):
			current_weapon_node.weapon_data = starting_weapon
			current_weapon_node._ready()  # Re-initialize

func pickup_weapon(new_weapon: WeaponData) -> bool:
	# Check if we already have this weapon type
	for i in range(weapons.size()):
		if weapons[i].weapon_name == new_weapon.weapon_name:
			# Add ammo instead
			if current_weapon_node and current_weapon_node.has_method("add_ammo"):
				current_weapon_node.add_ammo(new_weapon.max_ammo)
			return true
	
	# Check if we have space
	if weapons.size() < weapon_slot_count:
		weapons.append(new_weapon)
		switch_to_weapon(weapons.size() - 1)
		return true
	else:
		weapons[current_weapon_index] = new_weapon
		switch_to_weapon(current_weapon_index)
		return true

func switch_to_weapon(index: int):
	if index < 0 or index >= weapons.size():
		return
	
	current_weapon_index = index
	if current_weapon_node and current_weapon_node.has_method("set_weapon_data"):
		current_weapon_node.weapon_data = weapons[index]
		current_weapon_node._ready()  # Re-initialize
	
	emit_signal("weapon_switched", index)

func next_weapon():
	if weapons.size() > 0:
		var new_index = (current_weapon_index + 1) % weapons.size()
		switch_to_weapon(new_index)

func previous_weapon():
	if weapons.size() > 0:
		var new_index = current_weapon_index - 1
		if new_index < 0:
			new_index = weapons.size() - 1
		switch_to_weapon(new_index)
