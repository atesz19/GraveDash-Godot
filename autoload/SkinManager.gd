extends Node
## SkinManager — owned/equipped character skins (Witch free + purchasable skeletons).

signal skins_changed
signal equipped_changed(skin_id: String)

const SAVE_KEY_OWNED: String = "skins_owned"
const SAVE_KEY_EQUIPPED: String = "skin_equipped"
const DEFAULT_SKIN: String = "witch"

## Catalog order = shop display order.
## Pricing: Minion 10k, Rogue 20k, Warrior 25k, Mage 30k.
var _catalog: Array[Dictionary] = []
var owned_ids: PackedStringArray = PackedStringArray([DEFAULT_SKIN])
var equipped_id: String = DEFAULT_SKIN


func _ready() -> void:
	_build_catalog()
	_load()


func _build_catalog() -> void:
	_catalog = [
		{
			"id": "witch",
			"name": "Witch",
			"description": "Starter runner — free",
			"price": 0,
			"runner_scene": "res://scenes/player/WitchRunner.tscn",
			"preview_color": Color(0.55, 0.35, 0.7, 1),
		},
		{
			"id": "skeleton_minion",
			"name": "Skeleton Minion",
			"description": "Rattling recruit of the graveyard",
			"price": 10000,
			"runner_scene": "res://scenes/player/SkeletonMinionRunner.tscn",
			"preview_color": Color(0.75, 0.78, 0.7, 1),
		},
		{
			"id": "skeleton_rogue",
			"name": "Skeleton Rogue",
			"description": "Hooded bone thief",
			"price": 20000,
			"runner_scene": "res://scenes/player/SkeletonRogueRunner.tscn",
			"preview_color": Color(0.45, 0.55, 0.5, 1),
		},
		{
			"id": "skeleton_warrior",
			"name": "Skeleton Warrior",
			"description": "Armored undead vanguard",
			"price": 25000,
			"runner_scene": "res://scenes/player/SkeletonWarriorRunner.tscn",
			"preview_color": Color(0.65, 0.55, 0.4, 1),
		},
		{
			"id": "skeleton_mage",
			"name": "Skeleton Mage",
			"description": "Bone sorcerer of the crypt",
			"price": 30000,
			"runner_scene": "res://scenes/player/SkeletonMageRunner.tscn",
			"preview_color": Color(0.4, 0.55, 0.75, 1),
		},
	]


func get_catalog() -> Array[Dictionary]:
	return _catalog


func get_skin(skin_id: String) -> Dictionary:
	for s in _catalog:
		if str(s.get("id", "")) == skin_id:
			return s
	return _catalog[0] if not _catalog.is_empty() else {}


func is_owned(skin_id: String) -> bool:
	return owned_ids.has(skin_id)


func is_equipped(skin_id: String) -> bool:
	return equipped_id == skin_id


func can_afford(skin_id: String) -> bool:
	var skin: Dictionary = get_skin(skin_id)
	var price: int = int(skin.get("price", 0))
	if price <= 0:
		return true
	return ScoreManager != null and ScoreManager.total_souls >= price


func buy_skin(skin_id: String) -> String:
	## Returns empty on success, otherwise an error message.
	if is_owned(skin_id):
		return "Already owned."
	var skin: Dictionary = get_skin(skin_id)
	if skin.is_empty() or str(skin.get("id", "")) != skin_id:
		return "Unknown skin."
	var price: int = int(skin.get("price", 0))
	if price > 0:
		if ScoreManager == null or not ScoreManager.spend_souls(price):
			return "Not enough souls."
	if not owned_ids.has(skin_id):
		owned_ids.append(skin_id)
	_save()
	skins_changed.emit()
	return ""


func equip_skin(skin_id: String) -> String:
	if not is_owned(skin_id):
		return "Not owned."
	if equipped_id == skin_id:
		return ""
	equipped_id = skin_id
	_save()
	equipped_changed.emit(equipped_id)
	skins_changed.emit()
	return ""


func create_runner() -> Node3D:
	var skin: Dictionary = get_skin(equipped_id)
	var path: String = str(skin.get("runner_scene", "res://scenes/player/WitchRunner.tscn"))
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		packed = load("res://scenes/player/WitchRunner.tscn") as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _load() -> void:
	if SaveSystem == null:
		return
	var owned_var: Variant = SaveSystem.get_value(SAVE_KEY_OWNED, null)
	owned_ids = PackedStringArray([DEFAULT_SKIN])
	if owned_var is PackedStringArray:
		owned_ids = owned_var as PackedStringArray
	elif owned_var is Array:
		owned_ids = PackedStringArray()
		for v in owned_var as Array:
			owned_ids.append(str(v))
	elif owned_var is String and str(owned_var) != "":
		## Legacy comma-separated.
		for part in str(owned_var).split(",", false):
			owned_ids.append(part.strip_edges())
	if not owned_ids.has(DEFAULT_SKIN):
		owned_ids.insert(0, DEFAULT_SKIN)
	equipped_id = str(SaveSystem.get_value(SAVE_KEY_EQUIPPED, DEFAULT_SKIN))
	if not is_owned(equipped_id):
		equipped_id = DEFAULT_SKIN


func _save() -> void:
	if SaveSystem == null:
		return
	## Store as Array for ConfigFile friendliness.
	var owned_arr: Array = []
	for id in owned_ids:
		owned_arr.append(id)
	SaveSystem.set_value(SAVE_KEY_OWNED, owned_arr)
	SaveSystem.set_value(SAVE_KEY_EQUIPPED, equipped_id)
	SaveSystem.save()
