extends Node
## BiomeManager — stub. Selects chunk themes (Graveyard → Crypt → …) for LevelGenerator.

signal biome_changed(biome_id: String)

## Active biome id. Matches chunk pool naming (e.g. "graveyard").
var current_biome: String = "graveyard"

## Ordered progression used by future distance / score thresholds.
const BIOME_ORDER: PackedStringArray = [
	"graveyard",
	"crypt",
	"fog_woods",
]


func get_chunk_pool_id() -> String:
	## LevelGenerator can ask which pool to pull from.
	return "chunk_%s" % current_biome


func set_biome(biome_id: String) -> void:
	if biome_id == current_biome:
		return
	current_biome = biome_id
	biome_changed.emit(current_biome)
	print("[BiomeManager] biome → %s" % current_biome)


func advance_biome() -> void:
	var idx := BIOME_ORDER.find(current_biome)
	if idx < 0 or idx >= BIOME_ORDER.size() - 1:
		return
	set_biome(BIOME_ORDER[idx + 1])
