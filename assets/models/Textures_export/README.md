# Witch textures

The skeletal FBX (`assets/models/player/Witch_skeletal_mesh.fbx`) references:

`Textures_export/M_witch_Base_color.png`

(relative path baked in the FBX from the original Maya export).

`M_witch_Base_color.png` in this folder is a **neutral white multiply** placeholder so Godot import does not error. Witch colors come from **vertex colors** on the mesh (`WitchRunner` keeps `vertex_color_use_as_albedo`).

Replace this PNG with the authored albedo from the art source when available — keep the same filename.
