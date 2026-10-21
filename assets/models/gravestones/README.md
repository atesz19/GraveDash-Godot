# Gravestone pack (FBX + PBR)

## Layout
- `gravestone_0N.fbx` — meshes (RelPath expects `texture/gravestone_0N_*.png`)
- `texture/` — BaseColor / Normal / Roughness (+ Metallic for 02)
- `textures/` — duplicate copies for convenience

## Materials
`res://resources/materials/gravestones/gravestone_0N.tres`

## Prop scenes
- `DecorGravestone_01.tscn` … `_04.tscn`
- `DecorGravestone.tscn` — random variant wrapper

## Mapping notes
- Celtic ornate UV (circular cross islands) → **03** (matches pack naming; no rematch needed)
- 01/02/04 use numbered textures as authored in FBX RelativeFilename
