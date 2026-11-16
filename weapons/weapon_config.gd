extends RefCounted

const SWORD := 0
const BOW := 1
const FIRE_BOW := 2

const ORDER := [SWORD, BOW, FIRE_BOW]

const DEFS := {
	SWORD: {
		"key": &"sword",
		"name": "Sword",
		"short_name": "Sword",
		"icon": "res://ui/icons/broadsword.svg",
		"ammo_max": 0,
	},
	BOW: {
		"key": &"bow",
		"name": "Bow",
		"short_name": "Bow",
		"icon": "res://ui/icons/pocket-bow.svg",
		"ammo_max": 20,
		"ammo_name": "arrows",
		"damage_min": 50,
		"damage_max": 65,
		"explosive": false,
		"blast_radius": 0.0,
		"projectile_speed": 14.0,
		"pickup_label": "Bow",
		"refill_label": "Arrows",
	},
	FIRE_BOW: {
		"key": &"fire_bow",
		"name": "Fire Bow",
		"short_name": "Fire",
		"icon": "res://ui/icons/flaming-arrow.svg",
		"ammo_max": 6,
		"ammo_name": "fire arrows",
		"damage_min": 75,
		"damage_max": 75,
		"explosive": true,
		"blast_radius": 3.0,
		"projectile_speed": 14.0,
		"pickup_label": "Fire Bow",
		"refill_label": "Fire Arrows",
	},
}


static func get_def(weapon: int) -> Dictionary:
	return DEFS.get(weapon, DEFS[SWORD])


static func display_name(weapon: int) -> String:
	return get_def(weapon)["name"]


static func short_name(weapon: int) -> String:
	return get_def(weapon)["short_name"]


static func icon_path(weapon: int) -> String:
	return get_def(weapon)["icon"]


static func ammo_max(weapon: int) -> int:
	return int(get_def(weapon)["ammo_max"])


static func uses_ammo(weapon: int) -> bool:
	return ammo_max(weapon) > 0


static func is_explosive(weapon: int) -> bool:
	return bool(get_def(weapon).get("explosive", false))


static func roll_damage(weapon: int) -> int:
	var d := get_def(weapon)
	return randi_range(int(d.get("damage_min", 0)), int(d.get("damage_max", 0)))
