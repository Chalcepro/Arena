class_name WeaponData
extends Resource

@export var weapon_name: String = "Pistol"
@export var damage: int = 25
@export var headshot_multiplier: float = 2.0
@export var bodyshot_multiplier: float = 1.0
@export var limb_multiplier: float = 0.75

@export var fire_rate: float = 0.2  # seconds between shots
@export var reload_time: float = 1.5
@export var magazine_size: int = 12
@export var max_ammo: int = 48

@export var recoil_amount: float = 0.1
@export var aim_speed_modifier: float = 0.8  # slower when aiming

@export var shoot_sound: AudioStream
@export var reload_sound: AudioStream
@export var weapon_mesh: PackedScene  # for visual representation
