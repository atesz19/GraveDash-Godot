extends SceneTree
## Regenerates procedural textures + Android launcher icons (deterministic).
##   godot --headless --path . --script res://tools/gen_textures.gd
## Outputs: assets/textures/castle/*.png, assets/textures/fx/glow_radial.png, assets/icons/*.png

const OUT_CASTLE := "res://assets/textures/castle/"
const OUT_FX := "res://assets/textures/fx/"
const OUT_ICONS := "res://assets/icons/"
const ICON_SVG := "res://icon.svg"


func _initialize() -> void:
	for d in [OUT_CASTLE, OUT_FX, OUT_ICONS]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	_gen_bricks()
	_gen_flagstones()
	_gen_glow()
	_gen_icons()
	print("gen_textures done")
	quit(0)


func _noise(seed_v: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 4
	return n


## Tileable value from noise by sampling on a torus-free wrap (blend 4 corners).
func _tile_noise(n: FastNoiseLite, x: float, y: float, size: float) -> float:
	var fx := x / size
	var fy := y / size
	var a := n.get_noise_2d(x, y)
	var b := n.get_noise_2d(x - size, y)
	var c := n.get_noise_2d(x, y - size)
	var d := n.get_noise_2d(x - size, y - size)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _hash01(i: int, j: int, s: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ (s * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10000) / 10000.0


func _save_pair(albedo: Image, height: PackedFloat32Array, size: int, base: String, strength: float) -> void:
	albedo.save_png(base + "_albedo.png")
	var nrm := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var l := height[y * size + (x - 1 + size) % size]
			var r := height[y * size + (x + 1) % size]
			var u := height[((y - 1 + size) % size) * size + x]
			var dn := height[((y + 1) % size) * size + x]
			var v := Vector3((l - r) * strength, (u - dn) * strength, 1.0).normalized()
			nrm.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5))
	nrm.save_png(base + "_normal.png")


func _gen_bricks() -> void:
	var size := 512
	var bw := 128
	var bh := 64
	var mortar := 5
	var n := _noise(11, 0.035)
	var fine := _noise(29, 0.18)
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var height := PackedFloat32Array()
	height.resize(size * size)
	for y in size:
		var row := y / bh
		var off := (bw / 2) if row % 2 == 1 else 0
		for x in size:
			var bx := (x + off) % size
			var col := bx / bw
			var lx := bx % bw
			var ly := y % bh
			var edge := mini(mini(lx, bw - 1 - lx), mini(ly, bh - 1 - ly))
			var grain := _tile_noise(fine, x, y, size) * 0.5 + 0.5
			var cloud := _tile_noise(n, x, y, size) * 0.5 + 0.5
			var h: float
			var c: Color
			if edge < mortar:
				h = 0.0
				c = Color(0.09, 0.08, 0.09).lerp(Color(0.14, 0.13, 0.13), grain)
			else:
				var tone := _hash01(col, row, 3)
				var base := Color(0.25, 0.22, 0.27).lerp(Color(0.36, 0.31, 0.33), tone)
				if _hash01(col, row, 9) > 0.86:
					base = base.lerp(Color(0.2, 0.24, 0.2), 0.45)
				c = base * (0.78 + 0.34 * cloud) * (0.9 + 0.2 * grain)
				var bevel := clampf(float(edge - mortar) / 6.0, 0.0, 1.0)
				h = bevel * (0.75 + 0.25 * grain)
			c.a = 1.0
			img.set_pixel(x, y, c)
			height[y * size + x] = h
	_save_pair(img, height, size, OUT_CASTLE + "castle_wall", 2.4)


func _gen_flagstones() -> void:
	var size := 512
	var cell := 128
	var grout := 4
	var n := _noise(5, 0.03)
	var fine := _noise(41, 0.22)
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var height := PackedFloat32Array()
	height.resize(size * size)
	for y in size:
		var row := y / (cell / 2)
		var off := (cell / 2) if row % 2 == 1 else 0
		for x in size:
			var bx := (x + off) % size
			var col := bx / cell
			var lx := bx % cell
			var ly := y % (cell / 2)
			var edge := mini(mini(lx, cell - 1 - lx), mini(ly, cell / 2 - 1 - ly))
			var grain := _tile_noise(fine, x, y, size) * 0.5 + 0.5
			var cloud := _tile_noise(n, x, y, size) * 0.5 + 0.5
			var h: float
			var c: Color
			if edge < grout:
				h = 0.0
				c = Color(0.06, 0.055, 0.06)
			else:
				var tone := _hash01(col, row, 17)
				c = Color(0.27, 0.25, 0.27).lerp(Color(0.38, 0.35, 0.34), tone)
				c = c * (0.75 + 0.4 * cloud) * (0.88 + 0.24 * grain)
				h = clampf(float(edge - grout) / 5.0, 0.0, 1.0) * (0.8 + 0.2 * grain)
			c.a = 1.0
			img.set_pixel(x, y, c)
			height[y * size + x] = h
	_save_pair(img, height, size, OUT_CASTLE + "castle_floor", 2.0)


func _gen_glow() -> void:
	var size := 128
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := (Vector2(x + 0.5, y + 0.5) - c).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.save_png(OUT_FX + "glow_radial.png")


func _gen_icons() -> void:
	var svg := FileAccess.get_file_as_string(ICON_SVG)
	_raster(svg, 192, OUT_ICONS + "icon_192.png")
	_raster(svg, 512, OUT_ICONS + "icon_512.png")
	## Adaptive icon: foreground art inside the 66% safe zone, background solid.
	var fg := svg.replace("<!--BG-->", "<!--").replace("<!--/BG-->", "-->")
	fg = fg.replace('<g id="art">', '<g id="art" transform="translate(21.33 21.33) scale(0.6667)">')
	_raster(fg, 432, OUT_ICONS + "icon_adaptive_fg_432.png")
	var bg := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color8(0x14, 0x10, 0x24))
	bg.save_png(OUT_ICONS + "icon_adaptive_bg_432.png")


func _raster(svg: String, px: int, path: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(px) / 128.0)
	if err != OK:
		push_error("svg raster failed %s" % path)
		return
	img.save_png(path)
