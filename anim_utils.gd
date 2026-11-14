extends RefCounted

const ATTACK_KEYS := ["attack", "slash", "swing", "strike", "punch", "smash"]
const MOVE_KEYS := ["walk", "run", "move"]
const IMPORT_LIBRARY := "imported"


static func find_anim(anim: AnimationPlayer, keys: Array) -> String:
	for n in anim.get_animation_list():
		var lower := String(n).to_lower()
		for k in keys:
			if k in lower:
				return n
	return ""


static func find_attack(anim: AnimationPlayer, sources: Array) -> String:
	var found := find_anim(anim, ATTACK_KEYS)
	if found != "":
		return found
	for path in sources:
		found = _import_attack(anim, path)
		if found != "":
			return found
	return other_anim(anim)


static func other_anim(anim: AnimationPlayer) -> String:
	for n in anim.get_animation_list():
		var lower := String(n).to_lower()
		if lower == "reset" or lower.ends_with("/reset"):
			continue
		var is_move := false
		for k in MOVE_KEYS:
			if k in lower:
				is_move = true
		if not is_move:
			return n
	return ""


static func _import_attack(anim: AnimationPlayer, path: String) -> String:
	if not ResourceLoader.exists(path):
		return ""
	var packed := load(path) as PackedScene
	if packed == null:
		return ""
	var inst := packed.instantiate()
	var result := ""
	for p in inst.find_children("*", "AnimationPlayer", true, false):
		var src := p as AnimationPlayer
		var anim_name := find_anim(src, ATTACK_KEYS)
		if anim_name == "":
			anim_name = other_anim(src)
		if anim_name == "":
			continue
		var lib: AnimationLibrary
		if anim.has_animation_library(IMPORT_LIBRARY):
			lib = anim.get_animation_library(IMPORT_LIBRARY)
		else:
			lib = AnimationLibrary.new()
			anim.add_animation_library(IMPORT_LIBRARY, lib)
		if not lib.has_animation("attack"):
			lib.add_animation("attack", src.get_animation(anim_name).duplicate(true))
		result = IMPORT_LIBRARY + "/attack"
		break
	inst.free()
	return result
