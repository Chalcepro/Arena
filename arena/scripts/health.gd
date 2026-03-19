extends Node

@export var max_health := 100
@export var armor := 0

var current_health := max_health
var is_dead := false

signal health_changed(new_health: int, max_health: int)
signal player_died()
signal player_revived()

func _ready():
	current_health = max_health

func take_damage(amount: int, hit_location: String = "body"):
	if is_dead:
		return
	
	# Apply damage multipliers based on hit location
	var multiplier = 1.0
	match hit_location:
		"head":
			multiplier = 2.0
		"body":
			multiplier = 1.0
		"limb":
			multiplier = 0.75
	
	var final_damage = amount * multiplier
	
	# Apply armor reduction
	if armor > 0:
		var armor_reduction = min(armor, final_damage * 0.5)
		final_damage -= armor_reduction
		armor -= armor_reduction
	
	current_health -= final_damage
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		die()

func die():
	is_dead = true
	emit_signal("player_died")
	# Disable player controls, play death animation, etc.

func revive():
	if is_dead:
		current_health = max_health
		is_dead = false
		emit_signal("player_revived")
		emit_signal("health_changed", current_health, max_health)

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)

func get_health_percent() -> float:
	return float(current_health) / float(max_health)
